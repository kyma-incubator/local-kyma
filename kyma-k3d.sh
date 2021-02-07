#!/bin/bash
set -o errexit

./create-cluster-k3d.sh $1
./install-istio.sh -f config-istio.yaml
./install-kyma.sh
