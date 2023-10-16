#!/bin/bash

set -e
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"

COORD_DEPTH="${1}"
shift
COORD_DIR="${1:-.}"
shift 

COORD_PATH="${COORD_DIR}/helm.coord.json"
if [[ -f "$COORD_PATH" ]]; then
    COORD_JSON=$(cat "$COORD_PATH")
else
    COORD_JSON="{}"
fi
ABS_COORD_DIR=$(cd "${COORD_DIR}" && pwd)

# resolve struct dir with coord path and depth
ABS_STRUCT_DIR="$(cd "${COORD_DIR}"; for i in $(seq $COORD_DEPTH); do cd ..; done; pwd)"

ABS_STRUCT_PATH="${ABS_STRUCT_DIR}/helm.struct.json"
STRUCT_JSON=""
if [[ -f "$ABS_STRUCT_PATH" ]]; then
    STRUCT_JSON="$(cat "$ABS_STRUCT_PATH")"
else
    echo "No struct file found at depth -$COORD_DEPTH: $ABS_STRUCT_PATH"
    exit 1
fi

COORD=$(jq -n --arg absCoordDir "${ABS_COORD_DIR}" --arg absStructDir "${ABS_STRUCT_DIR}" \
  '$ARGS.named.absCoordDir[($ARGS.named.absStructDir | length):]' -r | sed 's#^/##g')

PATH_VARS="$(echo "$STRUCT_JSON" | jq --arg coord "${COORD}" 'include "./resolve_path_params";  .pathStructure as $pathStructure | $coord | resolve_path_params($pathStructure)')"

FILTERED="$(jq -n \
  --argjson structFile "$STRUCT_JSON" \
  --argjson coordFile "${COORD_JSON}" \
  --argjson pathVars "${PATH_VARS}" \
  -f merge_filter_placeholders.jq  )"

## get helm positional argument (or for lookup)
h_arg () {
  echo "$FILTERED" \
    | jq -r ".helm[\"$1\"]"
}

## get helm named argument, e.g. --my-arg my-val
h_flag () {
    FLAG="$1"
    VAL="$(h_arg "$FLAG")"
    if [[ "$VAL" != "null" ]]; then
      echo "--$FLAG $VAL"
    fi 
}

## get helm named argument with no value
h_flag_1 () {
    FLAG="$1"
    COMMAND="${2:-}"
    COMMAND_ONLY_WHEN_REGEX="${3:-.*}"

    echo "$COMMAND" | egrep -q "$COMMAND_ONLY_WHEN_REGEX" || return

    VAL="$(h_arg "$FLAG")"
    if [[ -n "$VAL" ]]; then # or compare to 'true'?
      echo "--$FLAG"
    fi 
}

## merge all values file "templated arrays" into string paths, output as helm -f arguments
VALUES_ARGS=$(echo "$FILTERED" \
  | jq '.valuesPaths[]' \
  | xargs -n 1 echo -n " -f")

# 

hc_command="$1";
shift 

hc_helm_command() {
    helm_command="$1";
    shift

    if [[ "$helm_command" == "diff" ]] ; then
        helm_command="diff $1" # e.g. helm diff upgrade
        shift
    fi 
    if [[ "$helm_command" == "dependency" ]] ; then
        helm_command="dependency $1" # e.g. helm diff upgrade
        shift
    fi 
    case "$helm_command" in
        "install" | "template" | "upgrade" | "diff upgrade" ) 
        echo helm $helm_command \
            $(h_arg "NAME") \
            $(h_arg "CHART") \
            $(h_flag "kubeconfig") \
            $(h_flag "namespace") \
            $(h_flag "version") \
            $(h_flag_1 "create-namespace" "$helm_command" "^upgrade$|^install$") \
            $(h_flag_1 "install" "$helm_command" "upgrade") \
            $VALUES_ARGS $@ ;;
        "dependency build" )
         echo helm $helm_command $(h_arg "CHART") $@ ;;
        "list" )
         echo helm $helm_command $(h_flag "kubeconfig") $(h_flag "namespace") $@ ;;
        "status" )
         echo helm $helm_command $(h_flag "kubeconfig") $(h_flag "namespace") $(h_arg "NAME") $@ ;;
        *) echo >&2 "Unsupported hc.sh helm command: $helm_command"; exit 1;;
    esac
} 

case "$hc_command" in
    "helm" ) 
      # change directory to resolve relative chart folders
      echo cd "${ABS_STRUCT_DIR}"
      hc_helm_command $@ ;;
    "helm-exec" )
      CMD="$(hc_helm_command $@)"
      # change directory to resolve relative chart folders
      (cd "${ABS_STRUCT_DIR}" && exec $CMD ) ;;
    "diff-coord" )
      COORD_DIR_2="$1"
      ${SCRIPT_PATH}/hc.sh $COORD_DEPTH "${COORD_DIR}" helm-exec template > /tmp/hc-diff-a.out
      ${SCRIPT_PATH}/hc.sh $COORD_DEPTH "${COORD_DIR_2}" helm-exec template > /tmp/hc-diff-b.out
      diff /tmp/hc-diff-a.out /tmp/hc-diff-b.out
      ;;
    *) echo >&2 "Unsupported hc.sh command: $hc_command"; exit 1;;
esac






