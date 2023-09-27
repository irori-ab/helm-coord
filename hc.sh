#!/bin/bash

set -e
COORD_DIR="${1:-.}"
COORD_PATH="${COORD_DIR}/helm.coord.json"

q () {
  jq ".$1" -r "${COORD_PATH}" 
}

STRUCT_DIR=$(q "structDir")
STRUCT_PATH="${COORD_DIR}/${STRUCT_DIR}/helm.struct.json"

FILTERED=$(cat "$COORD_PATH" \
  | jq -f "$STRUCT_PATH")

# TODO jq merge with one part stdin?
echo "$FILTERED" > $COORD_PATH.filtered.struct

h_arg () {
  jq -s '.[0] * .[1]' $COORD_PATH.filtered.struct ${COORD_PATH} \
    | jq -r ".helm.$1"
}

h_flag () {
    FLAG="$1"
    VAL="$(h_arg "$FLAG")"
    if [[ -n "$VAL" ]]; then
      echo "--$FLAG $VAL"
    fi 
}

VALUES_ARGS=$(echo "$FILTERED" \
  | jq '.valuesPaths[] | join("")' \
  | xargs -n 1 echo -n " -f")

helm_command="$2";

case "$helm_command" in
    "install" | "template" | "upgrade" ) 
     CMD=$(echo helm $helm_command $(h_arg "NAME") $(h_arg "CHART") $(h_flag "kubeconfig") $(h_flag "version") $VALUES_ARGS) ;;
    *) echo >&2 "Unsupported hc.sh helm command: $helm_command"; exit 1;;
esac



echo cd "${COORD_DIR}/${STRUCT_DIR}"
echo $CMD
