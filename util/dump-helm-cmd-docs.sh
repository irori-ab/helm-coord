#!/bin/bash 

HELM_VERSION="$(helm version | cut -d '"' -f 2)"

function dump_args() {
    cmd="$1"
    
    awk '/^Flags:/,/^$/; /^Global Flags:/,/^$/' \
    | awk '/ -.,/ { print $2} /  --/ { print $1 }' \
    | jq -R --arg cmd "$cmd" 'select(. != "") | { (.[2:]): ($cmd) }'
}

function dump_pos_args() {
    cmd="$1"
    POS_ARGS="$(grep -A 1 "Usage:" | grep -o -E '\[[A-Z]+\]' | xargs echo)"
    if [[ "$POS_ARGS" != "" ]]; then
        echo "\"$cmd;$POS_ARGS\""
    fi 
}

# reduce per arg to list of commands
# cat helm-v3.12.3-install-args.txt | jq -s '. | [.[] | .[2:] | split(" ") | { "cmd": "install", "arg": .[0]}] | reduce .[] as $x ({};  .[$x.arg] |= (. // []) + [$x.cmd])'

rm -f /tmp/helm-"$HELM_VERSION"-cmd-args.jsonl
rm -f /tmp/helm-"$HELM_VERSION"-cmd-pos-args.jsonl
rm -f ~/.helm-coord/cmd-args.json
rm -f ~/.helm-coord/cmd-pos-args.json

CMDS="$(helm -h | grep -o -E "^  [a-z]+" | grep -v helm | xargs echo)"
#CMDS=repo

for cmd in $CMDS
do
  echo "Processing $cmd"
  HELP="$(helm "$cmd" -h)"
  if [[ "${HELP}" =~ "Available Commands:" ]]; then 
    SUB_CMDS="$(echo "${HELP}" | awk '/Available Commands:/,/^$/' | grep -o -E "^  [a-z]+" | xargs echo)"
    for subCmd in $SUB_CMDS
    do
       echo "Processing $cmd $subCmd"
       SUB_HELP="$(helm "$cmd" "$subCmd" -h)"
       echo "$SUB_HELP" | dump_args "$cmd $subCmd" >> /tmp/helm-"$HELM_VERSION"-cmd-args.jsonl
       echo "$SUB_HELP" | dump_pos_args "$cmd $subCmd"  >> /tmp/helm-"$HELM_VERSION"-cmd-pos-args.jsonl
    done
  else 
    echo "$HELP" | dump_args "$cmd" >> /tmp/helm-"$HELM_VERSION"-cmd-args.jsonl
    echo "$HELP" | dump_pos_args "$cmd"  >> /tmp/helm-"$HELM_VERSION"-cmd-pos-args.jsonl
  fi
done



#MAIN_CMD="diff"
# optional, ignore error code
#CMDS="$( (helm $MAIN_CMD -h || true) | awk '/Available Commands/,NR<0' | egrep -o "^  [a-z]+" | grep -v helm | xargs echo)"
#for cmd in $CMDS
#do
#  helm $MAIN_CMD $cmd -h | dump_args "$MAIN_CMD $cmd" >> /tmp/helm-$HELM_VERSION-cmd-args.jsonl
#  helm $MAIN_CMD $cmd -h | dump_pos_args "$MAIN_CMD $cmd"  >> /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
#done

#MAIN_CMD="dependency"
#CMDS="$(helm $MAIN_CMD -h | awk '/Available Commands/,NR<0' | egrep -o "^  [a-z]+" | grep -v helm | xargs echo)"
#for cmd in $CMDS
#do
#  helm $MAIN_CMD $cmd -h | dump_args "$MAIN_CMD $cmd" >> /tmp/helm-$HELM_VERSION-cmd-args.jsonl
#  helm $MAIN_CMD $cmd -h | dump_pos_args "$MAIN_CMD $cmd"  >> /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
#done


# TODO: subcommand parse

mkdir -p ~/.helm-coord
 jq -s '[.[] | to_entries] | flatten | reduce .[] as $x ({}; .[$x.key] |= (. // []) + [$x.value])' \
   < /tmp/helm-"$HELM_VERSION"-cmd-args.jsonl \
   > ~/.helm-coord/cmd-args.json
 jq -s '[.[] | split(";")] | [ .[] | { "key" : .[0], "value" : .[1] | split(" ") | map(.[1:length-1])}] | from_entries' \
   < /tmp/helm-"$HELM_VERSION"-cmd-pos-args.jsonl \
   > ~/.helm-coord/cmd-pos-args.json
