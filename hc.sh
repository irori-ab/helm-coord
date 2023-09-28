#!/bin/bash

set -e
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"

COORD_DIR="${1:-.}"
shift 

COORD_PATH="${COORD_DIR}/helm.coord.json"

q () {
  jq ".$1" -r "${COORD_PATH}" 
}

STRUCT_DIR=$(q "structDir")
STRUCT_PATH="${COORD_DIR}/${STRUCT_DIR}/helm.struct.jq"

# use struct file as a basic templating engine with data from coord file
# flatten arrays for "helm" object values, and "valuesPaths" array items
FILTERED="$(jq -f "$STRUCT_PATH" "$COORD_PATH" \
  | jq '.helm |= with_entries({ "key": .key, "value": [.value] | flatten | join("") })' \
  | jq '.valuesPaths = [.valuesPaths[] | [.] | flatten | join("")]')"

# merge two files via slurp, stdin (filtered helm struct) and coord file, latter overriding former
MERGED="$(echo "$FILTERED" | jq -s '.[0] * .[1]' - ${COORD_PATH} )"

## get helm positional argument (or for lookup)
h_arg () {
  echo "$MERGED" \
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
      echo cd "${COORD_DIR}/${STRUCT_DIR}"
      hc_helm_command $@ ;;
    "helm-exec" )
      CMD="$(hc_helm_command $@)"
      # change directory to resolve relative chart folders
      (cd "${COORD_DIR}/${STRUCT_DIR}" && exec $CMD ) ;;
    "diff-coord" )
      COORD_DIR_2="$1"
      ${SCRIPT_PATH}/hc.sh "${COORD_DIR}" helm-exec template > /tmp/hc-diff-a.out
      ${SCRIPT_PATH}/hc.sh "${COORD_DIR_2}" helm-exec template > /tmp/hc-diff-b.out
      diff /tmp/hc-diff-a.out /tmp/hc-diff-b.out
      ;;
    *) echo >&2 "Unsupported hc.sh command: $hc_command"; exit 1;;
esac






