#!/bin/bash

set -e

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

./hc.sh 2 examples/coord-files/environments/test diff-coord examples/coord-files/environments/prod