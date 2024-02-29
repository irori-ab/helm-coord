# helm-coordinates

A Helm wrapper script that simplifies working with multiple deployments of the same Helm chart according to an implicit structure.

![helm coordinates overview](/docs/overview.png)


## Goals
1. All information needed to do a Helm deployment in a specific environment should be uniquely determined from a specification folder -- the coordinate.
2. Operate as close as possible to Helm abstractions, command names and argument terminology.

## Concepts

* **coordinate path**: a filesystem path to a directory that will uniquely allow us to infer parameters needed to construct a Helm command invocation. 
  * Example: `some/path/to/my/coordinate` 
* **coordinate**: The actual coordinate is the relative path between the *Helm structure file* and the supplied *coordinate path*. 
  * Example: `my/coordinate`
* **Helm structure file**: A file that defines how to use inferred parameters  to construct Helm command invocations.
  * Example location: `some/path/to/helm.struct.json` 
* **path structure**: A pattern to match to a *coordinate*
  to infer path parameters.
  * Example: `"my/#coordinate_name"`
    * gives the parameter `coordinate_name="coordinate"` with the above example
* **Helm coordinate file**: An optional file that can specify parameters that cannot be inferred from the *coordinate* 
  * Example location: `some/path/to/my/coordinate/helm.coord.json` 
* **coordinate depth**: the path depth of the coordinate. This is useful when invoking the tool from an arbitrary working directory.
  * Example: 2 (for the above coordinate)
  
## Pre-requisites

* CLI tools
  * Bash
  * JQ
  * helm (duh)
* Files
  * `helm.struct.json`
    * at some common location, maybe repo root
  * `my/helm/coordinate/helm.coord.json`
    * at each deployment specification folder
    * **note**: optional if only using `pathStructure` inferred parameters

## Usage 

`./hc.sh COORD_DEPTH COORD_PATH helm HELM_COMMAND`

This will output a Helm command per the Helm coordinate file, and its referenced Helm structure file.

Example: 
  * `./hc.sh -d 2 my/folder/environment/prod helm install`
  * Output (note `cd` commands needed to resolve relative chart paths): 
    ```
    cd ...
    helm install ...
    ```

To actually execute the helm command as well:

* `./hc.sh COORD_DEPTH COORD_PATH helm-exec HELM_COMMAND`

Example:

* `./hc.sh -d 2 my/folder/environment/prod -e install`

## Supported Helm commands

* `template`
* `install`
* `upgrade`
* `diff upgrade` (with Helm diff plugin)
* `status`
* `list` (list in same namespace as coord)

Note: not all arguments are passed on for each command. Should be easy to modify the script if you need more though.

## Tutorial
Assumes you have a working default kubeconfig. Will install the example 
chart into two namespaces.


```
# inspect the helm structure file in the example
# - we use placeholders both for helm arguments and values file paths
# - path inferred parameters start with '#'
# - Helm coordinate file parameters start with '$'
cat examples/coord-files/helm.struct.json
# inspect how we specify the Helm coordinate file parameters 
cat examples/coord-files/environments/prod/helm.coord.json
cat examples/coord-files/environments/test/helm.coord.json

# infer the prod template command (2 is the coordinate depth)
./hc.sh -d 2 examples/coord-files/environments/prod template
# infer the test template command
./hc.sh -d 2 examples/coord-files/environments/prod template
# the names of the 'helm' struct section arguments should correspond well to the Helm command help output
# 'helm template -h'

# you can append any Helm arguments at the end
./hc.sh -d 2 examples/coord-files/environments/prod template --set replicaCount=10

# actually inspect the output from template execution
./hc.sh -d 2 examples/coord-files/environments/prod -e template
./hc.sh -d 2 examples/coord-files/environments/test -e template



# if you are satisfied, and dare to ;) then lets install these (will use your default kubeconfig)
./hc.sh -d 2 examples/coord-files/environments/prod -e install
./hc.sh -d 2 examples/coord-files/environments/test -e install

# inspect the result
helm list -n hc-testing-prod
kubectl get pods -n hc-testing-prod
helm list -n hc-testing-test
kubectl get pods -n hc-testing-test

# diff the template output from two coordinates
./hc.sh -d 2 examples/coord-files/environments/test diff-coord examples/coord-files/environments/prod

# install Helm diff to try diffing a installed release
# see installation instructions: https://github.com/databus23/helm-diff

# modify some values (here replicas)
sed -I.tmp 's/3/5/g' examples/coord-files/environments/prod/values.yaml
sed -I.tmp 's/2/3/g' examples/coord-files/environments/test/values.yaml
# inspect the would be diffs
./hc.sh -d 2 examples/coord-files/environments/prod helm-exec diff upgrade
./hc.sh -d 2 examples/coord-files/environments/test helm-exec diff upgrade
```

Congratulations! You are now a fully fledged Helm coordinate navigator!

Go forth and see how complex Helm structures you can create that break this script,
or at the very least challenge your co-workers understanding of your spider web of deployments!

## Examples
See chart and folder setup under `examples/`.

Example output:
```
> ./hc.sh -d 2 examples/environments/prod template
cd examples/environments/prod/../..
helm template my-prod-release my-chart --kubeconfig ~/.kube/config_prod --version 1.0.0 -f profiles/medium/values.yaml -f environments/prod/values.yaml
> ./hc.sh examples/environments/test template
cd examples/environments/test/../..
helm template my-test-release my-chart --kubeconfig ~/.kube/config_test --version 2.0.0-alpha -f profiles/small/values.yaml -f environments/test/values.yaml
```

## Future work

* [x] Actually testing it
* [x] Solve reasonably safe exec of commands
* [x] Implement more flags and helm commands
* [x] Simple testing mechanism, with github actions
* [x] Allow templating helm args also
* [x] Diffing between coordinate and cluster (via helm diff plugin)
* [x] Write tutorial
* [x] default path params
* [ ] all commands, globbing
* [ ] CI usage
* [ ] CODEOWNER flows
* [x] Fix reasonable shellcheck warnings
* [x] Diffing between coordinates
* [ ] Diffing between coordinates in other git references
* [ ] Generate ArgoCD Application files