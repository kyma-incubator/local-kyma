#!/bin/sh
set -o errexit

./create-cluster-minikube.sh
./install-istio.sh -f config-istio.yaml
IP=$(minikube ssh "grep host.minikube.internal /etc/hosts | cut -f1") 
export REGISTRY_IP=${IP//[$'\t\r\n ']}
./install-kyma.sh
