# helm-coordinates

## Goal
* All information needed to do a Helm deployment in a specific environment should be uniquely determined from a specification folder -- the **helm coordinate file**
* The structure of helm deployments should be documented in a single file -- the **helm structure file**

## Pre-requisites

* CLI tools
  * Bash
  * JQ
* Files
  * `helm.struct.json`
    * at some common location, maybe repo root
  * `my/helm/coordinate/helm.coord.json`
    * At each deployment specification folder

## Usage 

`./hc.sh PATH/TO/COORD/DIR HELM_COMMAND`

This will output a Helm command per the Helm coordinate file, and its referenced Helm structure file.

Example: `./hc.sh environment/prod install`.

Output: `helm install ...`


## Tutorial

TODO

## Example
See chart and folder setup under `examples/`.

Example output:
```
> ./hc.sh examples/environments/prod template
cd examples/environments/prod/../..
helm template my-prod-release my-chart --kubeconfig ~/.kube/config_prod --version 1.0.0 -f profiles/medium/values.yaml -f environments/prod/values.yaml
> ./hc.sh examples/environments/test template
cd examples/environments/test/../..
helm template my-test-release my-chart --kubeconfig ~/.kube/config_test --version 2.0.0-alpha -f profiles/small/values.yaml -f environments/test/values.yaml
```

## Future work

* Actually testing it
* Solve reasonably safe exec of commands
* Implement more flags and helm commands
* Diffing between coordinate and cluster (via helm diff plugin?)
* Diffing between coordinates
* Diffing between coordinates in other git references