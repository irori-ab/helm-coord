# helm-coordinates

## Goal
* All information needed to do a Helm deployment in a specific environment should be uniquely determined from a specification folder -- the **helm coordinate file**
* The structure of helm deployments should be documented in a single file -- the **helm structure file**

## Pre-requisites

* CLI tools
  * Bash
  * JQ
  * helm (duh)
* Files
  * `helm.struct.jq`
    * at some common location, maybe repo root
  * `my/helm/coordinate/helm.coord.json`
    * at each deployment specification folder

## Usage 

`./hc.sh PATH/TO/COORD/DIR helm HELM_COMMAND`

This will output a Helm command per the Helm coordinate file, and its referenced Helm structure file.

Example: 
  * `./hc.sh environment/prod helm install`
  * Output (note `cd` commands needed to resolve relative chart paths): 
   ```
   cd ...
   helm install ...
   ```

To actually execute the helm command as well:

* `./hc.sh PATH/TO/COORD/DIR helm-exec HELM_COMMAND`

Example:

* `./hc.sh environment/prod helm-exec install`

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
# - notice how we use placeholders both for helm arguments and values file paths
# - notice how we bring in a separate profile values file based on a placeholder
cat examples/helm.struct.jq

# inspect how the two helm coordinate files set the params for the placeholders
# - notice that each file needs to specify a correct relative path to the struct file
# - notice how the 'params' define data available for struct placeholders
# - notice how the 'helm' values can override the ones specified in the struct file
cat examples/environments/prod/helm.coord.json
cat examples/environments/test/helm.coord.json

# inspect the prod template command
./hc.sh examples/environments/prod helm template
# inspect the test template command
./hc.sh examples/environments/prod helm template
# the names of the 'helm' struct section arguments should correspond well to the helm help output
# 'helm template -h'

# actually inspect the output from template execution
./hc.sh examples/environments/prod helm-exec template
./hc.sh examples/environments/test helm-exec template

# if you are satisfied, and dare to ;) then lets install these
./hc.sh examples/environments/prod helm-exec install
./hc.sh examples/environments/test helm-exec install

# inspect the result
helm list -n hc-testing-prod
kubectl get pods -n hc-testing-prod
helm list -n hc-testing-test
kubectl get pods -n hc-testing-test

# diff the template output from two coordinates
./hc.sh examples/environments/test diff-coord examples/environments/prod

# install Helm diff to try diffing a installed release
# see installation instructions: https://github.com/databus23/helm-diff

# modify some values (here replicas)
sed -I.tmp 's/3/5/g' examples/environments/prod/values.yaml
sed -I.tmp 's/2/3/g' examples/environments/test/values.yaml
# inspect the would be diffs
./hc.sh examples/environments/prod helm-exec diff upgrade
./hc.sh examples/environments/test helm-exec diff upgrade
# cleanup
rm examples/environments/prod/values.yaml.tmp
rm examples/environments/test/values.yaml.tmp
```

Congratulations! You are now a fully fledged Helm coordinate navigator!

Go forth and see how complex Helm structures you can create that break this script,
or at the very least challenge your co-workers understanding of your spider web of deployments!

## Example
See chart and folder setup under `examples/`.

Example output:
```
> ./hc.sh examples/environments/prod helm template
cd examples/environments/prod/../..
helm template my-prod-release my-chart --kubeconfig ~/.kube/config_prod --version 1.0.0 -f profiles/medium/values.yaml -f environments/prod/values.yaml
> ./hc.sh examples/environments/test helm template
cd examples/environments/test/../..
helm template my-test-release my-chart --kubeconfig ~/.kube/config_test --version 2.0.0-alpha -f profiles/small/values.yaml -f environments/test/values.yaml
```

## Future work

* [x] Actually testing it
* [x] Solve reasonably safe exec of commands
* [ ] Implement more flags and helm commands
* [x] Allow templating helm args also
* [x] Diffing between coordinate and cluster (via helm diff plugin)
* [x] Write tutorial
* [ ] Fix reasonable shellcheck warnings
* [x] Diffing between coordinates
* [ ] Diffing between coordinates in other git references