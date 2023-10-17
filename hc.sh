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

helm_args() {
  cmd="$1"
  CMD_POS_ARGS="$(cat ~/.helm-coord/cmd-pos-args.json)"
  cat ~/.helm-coord/cmd-args.json | jq -r -f helm-args.jq --arg cmd "$cmd" --argjson cmdPosArgs "$CMD_POS_ARGS" --argjson struct "$FILTERED"
}

## merge all values file "templated arrays" into string paths, output as helm -f arguments
VALUES_ARGS=$(echo "$FILTERED" \
  | jq '.valuesPaths[]' \
  | xargs -n 1 echo -n " -f")

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
    # only $VALUES_ARGS if cmd has  --values flag (-f)
    HAS_VALUES="$(cat ~/.helm-coord/cmd-args.json | jq --arg cmd "$helm_command" 'any(.values[]; . == $cmd)')"
    if [[ "$HAS_VALUES" == "false" ]]; then
      VALUES_ARGS=""
    fi
    echo helm $helm_command $(helm_args $helm_command) $VALUES_ARGS $@
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






