#!/bin/bash

set -e -o pipefail

SCRIPT_PATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

mode="printcmd"

print_usage () {
  echo "Usage:
  echo "$0 TODO USAGE"
}

while [[ $# > 0 ]]
do
  case "$1" in
  ## non-short-circuiting commands
  -h|--help)
    print_usage
    exit 0
    ;;
  -e|--exec)
    mode="exec"
    shift # flag 
    ;;
  -d|--depth)
    COORD_DEPTH="$2"
    shift # flag
    shift # value
    ;;
  --add-to-path)
    echo "echo \"export PATH=\$PATH:$SCRIPT_PATH >> ~/.bashrc\""
    shift # flag
    ;;
  ## short-circuiting commands
  --diff)
    mode="diff"
    COORD_DIR="$2"
    COORD_DIR_2="$3"
    shift # flag
    shift # value 1
    shift # value 2
    break
    ;;

  -p|--coord-path)
    # allows to specify COORD_DIR starting with "-"
    COORD_DIR="$2"
    shift # flag
    shift # value
    ;;
  --)
    # stops helm coord arg parsing
    break
    ;;
  -*|--*)
    >&2 echo "Error: unknown helm coord option: $1"
    >&2 echo "Make sure you specify helm coordinate options before the coordinate directory"
    >&2 echo
    print_usage 
    shift
    exit 1
    ;;

  *)
    if [[ "$COORD_DIR" == "" ]]; then
      COORD_DIR="$1"
      shift # value
    else
      # assume this and remaining are helm command/arguments
      break 
    fi 
    ;;
  esac 
done

if [[ "$COORD_DEPTH" == "" ]] ; then
  # assume struct dir is current
  # assume depth is depth of coord argument

  if [ ! -f "helm.struct.json" ]; then
    >&2 echo "ERROR: No 'helm.struct.json' found in current directory."
    >&2 echo "To run hc.sh against an arbitrary path, you need to supply a numerical '-d DEPTH' argument, example:"
    >&2 echo "hc.sh -d 2 my/long/path/environment/prod template"
    >&2 echo 
    >&2 echo "This is equivalent to:"
    >&2 echo "cd my/long/path"
    >&2 echo "hc.sh environment/prod helm template"
    
    exit 1
  else
    COORD_DEPTH="$(($(echo "$COORD_DIR" | grep -o -E "./." | wc -l)+1))"
  fi
fi

CMD_POS_ARGS_FILE="$HOME/.helm-coord/cmd-pos-args.json"
if [[ ! -f "$CMD_POS_ARGS_FILE" ]]; then 
  # using default positional argument definitions
  CMD_POS_ARGS_FILE="$SCRIPT_PATH/cmd-pos-args.json"
fi 

CMD_ARGS_FILE="$HOME/.helm-coord/cmd-args.json"
if [[ ! -f "$CMD_ARGS_FILE" ]]; then 
  # using default argument definitions
  CMD_ARGS_FILE="$SCRIPT_PATH/cmd-args.json"
fi 

COORD_PATH="${COORD_DIR}/helm.coord.json"
if [[ -f "$COORD_PATH" ]]; then
    COORD_JSON=$(cat "$COORD_PATH")
else
    COORD_JSON="{}"
fi
ABS_COORD_DIR=$(cd "${COORD_DIR}" && pwd)

# resolve struct dir with coord path and depth
ABS_STRUCT_DIR="$(cd "${COORD_DIR}"; for _ in $(seq "$COORD_DEPTH"); do cd ..; done; pwd)"

ABS_STRUCT_PATH="${ABS_STRUCT_DIR}/helm.struct.json"
STRUCT_JSON=""
if [[ -f "$ABS_STRUCT_PATH" ]]; then
    STRUCT_JSON="$(cat "$ABS_STRUCT_PATH")"
else
    echo "No struct file found at depth -$COORD_DEPTH: $ABS_STRUCT_PATH"
    exit 1
fi

PATH_STRUCT="$(echo "$STRUCT_JSON" | jq '.pathStructure' )"
PATH_STRUCT_DEPTH="$(( $(echo "$PATH_STRUCT" |  grep -o -E "./." | wc -l) + 1 ))"
if [[ "$COORD_DEPTH" != "$PATH_STRUCT_DEPTH" ]]; then
  echo "Error: path structure in helm.struct.json expected depth: $PATH_STRUCT_DEPTH (found $COORD_DEPTH)"
  exit 1
fi

COORD=$(jq -n --arg absCoordDir "${ABS_COORD_DIR}" --arg absStructDir "${ABS_STRUCT_DIR}" \
  '$ARGS.named.absCoordDir[($ARGS.named.absStructDir | length):]' -r | sed 's#^/##g')

PATH_VARS="$(echo "$STRUCT_JSON" | jq --arg coord "${COORD}" "-L${SCRIPT_PATH}/" 'include "./resolve_path_params";  .pathStructure as $pathStructure | $coord | resolve_path_params($pathStructure)')"

FILTERED="$(jq -n "-L${SCRIPT_PATH}/" \
  --argjson structFile "$STRUCT_JSON" \
  --argjson coordFile "${COORD_JSON}" \
  --argjson pathVars "${PATH_VARS}" \
  --arg HOME "${HOME}" \
  -f "${SCRIPT_PATH}/merge_filter_placeholders.jq"  )"

helm_args() {
  cmd="$1"
  CMD_POS_ARGS="$(cat "$CMD_POS_ARGS_FILE")"
  jq -r "-L${SCRIPT_PATH}/" -f "${SCRIPT_PATH}/helm-args.jq" --arg cmd "$cmd" --argjson cmdPosArgs "$CMD_POS_ARGS" --argjson struct "$FILTERED" \
    < "$CMD_ARGS_FILE"
}

## merge all values file "templated arrays" into string paths, output as helm -f arguments
VALUES_ARGS=$(echo "$FILTERED" \
  | jq '.["--values"][]' \
  | xargs -n 1 echo -n " -f")

hc_helm_command() {
    helm_command="$1";
    shift

    IS_SUBCOMMAND="$(jq --arg cmd "$helm_command $1" 'has($cmd)' "$CMD_POS_ARGS_FILE")"
    if [[ "$IS_SUBCOMMAND" == "true" ]] ; then
        helm_command="$helm_command $1" # e.g. helm diff upgrade
        shift
    fi 

    # only $VALUES_ARGS if cmd has  --values flag (-f)
    HAS_VALUES="$( jq --arg cmd "$helm_command" 'any(.values[]; . == $cmd)' $CMD_ARGS_FILE)"
    if [[ "$HAS_VALUES" == "false" ]]; then
      VALUES_ARGS=""
    fi
    echo "helm $helm_command $(helm_args "${helm_command}") $VALUES_ARGS $*"
} 

echo "helm-coord mode: $mode"
case "$mode" in
    printcmd) 
      # change directory to resolve relative chart folders
      echo cd "${ABS_STRUCT_DIR}"

      # I think we want glob expansion here
      # shellcheck disable=SC2068
      hc_helm_command $@
      ;;
    exec)
      # I think we want glob expansion here
      # shellcheck disable=SC2068
      CMD="$(hc_helm_command $@)"
      # change directory to resolve relative chart folders
      (cd "${ABS_STRUCT_DIR}" && exec $CMD )
      ;;
    diff)
      "${SCRIPT_PATH}/hc.sh" -d "${COORD_DEPTH}" "${COORD_DIR}" -e template > /tmp/hc-diff-a.out
      "${SCRIPT_PATH}/hc.sh" -d "${COORD_DEPTH}" "${COORD_DIR_2}" -e template > /tmp/hc-diff-b.out
      diff /tmp/hc-diff-a.out /tmp/hc-diff-b.out
      ;;
    *) echo >&2 "Unsupported hc.sh mode: $mode"; exit 1;;
esac






