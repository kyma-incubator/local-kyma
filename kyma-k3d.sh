#!/bin/sh
set -o errexit

./create-cluster-k3d.sh
./install-istio.sh -f config-istio.yaml
./install-kyma.sh
