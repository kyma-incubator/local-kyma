#!/bin/bash
set -o errexit

### Create kind cluster

./kind-with-docker-registry.sh

while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready"; sleep 2; done

### Download istioctl

./download-istioctl.sh

### Install istio 1.5.10-distroless

./istioctl manifest apply -f kind-istio-install.yaml

### Install kyma

./install-kyma-kind.sh