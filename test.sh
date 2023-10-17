#!/bin/bash

set -e
SCRIPT_PATH="$(dirname -- "${BASH_SOURCE[0]}")"
${SCRIPT_PATH}/util/dump-helm-cmd-docs.sh

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
EOF)

echo "$VARS"

echo '["a.", "b.", "#c", "$d", "e.", "#f"]'  | jq --argjson vars "$VARS" 'include "./join_vars"; . | join_vars($vars)'
echo '"dude"'  | jq --argjson vars "$VARS" 'include "./join_vars"; . | join_vars($vars)'

./hc.sh 2 examples/coord-files/environments/prod helm template
./hc.sh 2 examples/coord-files/environments/test helm template

./hc.sh 2 examples/coord-files/environments/prod helm-exec template
./hc.sh 2 examples/coord-files/environments/test helm-exec template


./hc.sh 2 examples/path-params/environments/prod helm template
./hc.sh 2 examples/path-params/environments/test helm template

./hc.sh 2 examples/path-params/environments/prod helm-exec template
./hc.sh 2 examples/path-params/environments/test helm-exec template

#  diff returns non-zero exit code on normal operation
# => check for something we know should be in output
./hc.sh 2 examples/coord-files/environments/test diff-coord examples/coord-files/environments/prod | \
  grep "replicas: 2"