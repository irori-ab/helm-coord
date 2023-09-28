#!/bin/bash 

HELM_VERSION="$(helm version | cut -d '"' -f 2)"

helm install -h | awk '{ print $1, $2}' > helm-$HELM_VERSION-install-args.txt

helm upgrade -h | awk '{ print $1, $2}' > helm-$HELM_VERSION-upgrade-args.txt

helm template -h | awk '{ print $1, $2}' > helm-$HELM_VERSION-template-args.txt