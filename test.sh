#!/bin/bash

set -e
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
cd "$SCRIPT_PATH"

# run to populate cmd args cache files
./util/dump-helm-cmd-docs.sh

CMD_POS_ARGS="$(cat ~/.helm-coord/cmd-pos-args.json)"

STRUCT=$(cat << EOF
{
    "helm" : {
        "REPO_NAME" : "myRepo",
        "URL" : "myUrl"
    }
}
EOF
)
jq -r "-L${SCRIPT_PATH}/" -f "${SCRIPT_PATH}/helm-args.jq" --arg cmd "repo add" --argjson cmdPosArgs "$CMD_POS_ARGS" --argjson struct "$STRUCT" \
    < ~/.helm-coord/cmd-args.json | \
  grep "myRepo myUrl"

# wipe to test rest with default argument definitions
rm -rf ~/.helm-coord

jq -n 'include "./resolve_path_params";  "environment/prod" | resolve_path_params("environment/#ENV")'


VARS=$(cat << EOF
{
    "pathVars" : {
        "c" : "pathVar-c.",
        "f" : "pathVar-f."
    },
    "paramVars" : {
        "d" : "param-d."
    }
}
EOF
)

echo "$VARS"

# shellcheck disable=SC2016
echo '["a.", "b.", "#c", "$d", "e.", "#f", "~"]'  | jq --arg HOME "home" --argjson vars "$VARS" 'include "./join_vars"; . | join_vars($vars;$HOME)'
echo '"dude"'  | jq --arg HOME "home" --argjson vars "$VARS" 'include "./join_vars"; . | join_vars($vars;$HOME)'

./hc.sh -d 2 examples/coord-files/environments/prod template
./hc.sh -d 2 examples/coord-files/environments/test template

./hc.sh -d 2 examples/coord-files/environments/prod  -e template
./hc.sh -d 2 examples/coord-files/environments/test  -e template


./hc.sh -d 2 examples/path-params/environments/prod template
./hc.sh -d 2 examples/path-params/environments/test template

./hc.sh -d 2 examples/path-params/environments/prod  -e template
./hc.sh -d 2 examples/path-params/environments/test  -e template

./hc.sh -d 2 examples/fluentd/environments/prod template
./hc.sh -d 2 examples/fluentd/environments/stage template

./hc.sh -d 2 examples/fluentd/environments/prod  -e template
./hc.sh -d 2 examples/fluentd/environments/stage  -e template

pushd examples/fluentd/
../../hc.sh environments/stage template
popd


#  diff returns non-zero exit code on normal operation
# => check for something we know should be in output
./hc.sh -d 2 --diff examples/coord-files/environments/test examples/coord-files/environments/prod | \
  grep "replicas: 2"

