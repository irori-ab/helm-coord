#!/bin/bash 

HELM_VERSION="$(helm version | cut -d '"' -f 2)"

function dump_args() {
    cmd="$1"
    
    egrep -e "^\s+(-[a-z], )?--.*" -o \
    | sed -E 's/--/;--/g' \
    | cut -d ";" -f 2 \
    | sed 's/^/"/g' | sed 's/$/"/g' | xargs -n1 -I {} echo "{\"cmd\" : \"$cmd\", \"arg\": \"{}\"}"
}

function dump_pos_args() {
    cmd="$1"
    POS_ARGS="$(grep -A 1 "Usage:" | egrep -o '\[[A-Z]+\]' | xargs echo)"
    if [[ "$POS_ARGS" != "" ]]; then
        echo "\"$cmd;$POS_ARGS\""
    fi 
}

# reduce per arg to list of commands
# cat helm-v3.12.3-install-args.txt | jq -s '. | [.[] | .[2:] | split(" ") | { "cmd": "install", "arg": .[0]}] | reduce .[] as $x ({};  .[$x.arg] |= (. // []) + [$x.cmd])'

rm -f /tmp/helm-$HELM_VERSION-cmd-args.jsonl
rm -f /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
rm -f ~/.helm-coord/cmd-args.json
rm -f ~/.helm-coord/cmd-pos-args.json

#CMDS="install upgrade template"
CMDS="$(helm -h | egrep -o "^  [a-z]+" | grep -v helm | xargs echo)"

for cmd in $CMDS
do
  helm $cmd -h | dump_args $cmd >> /tmp/helm-$HELM_VERSION-cmd-args.jsonl
  helm $cmd -h | dump_pos_args $cmd  >> /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
done

MAIN_CMD="diff"
# optional, ignore error code
CMDS="$( (helm $MAIN_CMD -h || true) | awk '/Available Commands/,NR<0' | egrep -o "^  [a-z]+" | grep -v helm | xargs echo)"
for cmd in $CMDS
do
  helm $MAIN_CMD $cmd -h | dump_args "$MAIN_CMD $cmd" >> /tmp/helm-$HELM_VERSION-cmd-args.jsonl
  helm $MAIN_CMD $cmd -h | dump_pos_args "$MAIN_CMD $cmd"  >> /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
done

MAIN_CMD="dependency"
CMDS="$(helm $MAIN_CMD -h | awk '/Available Commands/,NR<0' | egrep -o "^  [a-z]+" | grep -v helm | xargs echo)"
for cmd in $CMDS
do
  helm $MAIN_CMD $cmd -h | dump_args "$MAIN_CMD $cmd" >> /tmp/helm-$HELM_VERSION-cmd-args.jsonl
  helm $MAIN_CMD $cmd -h | dump_pos_args "$MAIN_CMD $cmd"  >> /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl
done


# TODO: subcommand parse

mkdir -p ~/.helm-coord
cat /tmp/helm-$HELM_VERSION-cmd-args.jsonl | jq -s '. | map(.arg |= (. | split(" ") | .[0][2:])) | reduce .[] as $x ({};  .[$x.arg] |= (. // []) + [$x.cmd])' > ~/.helm-coord/cmd-args.json
cat /tmp/helm-$HELM_VERSION-cmd-pos-args.jsonl | jq -s '[.[] | split(";")] | [ .[] | { "key" : .[0], "value" : .[1] | split(" ") | map(.[1:length-1])}] | from_entries' > ~/.helm-coord/cmd-pos-args.json
