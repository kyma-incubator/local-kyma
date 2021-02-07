#!/bin/bash
set -o errexit

SECONDS=0  
REGISTRY_CONFIG=${1:-registries.yaml}

# Check memory
MEMORY=8192
REQUIRED_MEMORY=$(expr $MEMORY \* 1024 \* 1024)
DOCKER_MEMEORY=$(docker info --format '{{json .MemTotal}}')

if (( $REQUIRED_MEMORY > $DOCKER_MEMEORY )); then
    echo "Container memory in not sufficient. Please configure Docker to support containers with at least ${MEMORY} MB."
    exit 1
fi

# Create docker network
docker network create k3d-kyma || echo "k3d-kyma network already exists"

# Start docker Registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry.localhost \
  --network k3d-kyma \
  -v $PWD/registry:/var/lib/registry \
  eu.gcr.io/kyma-project/test-infra/docker-registry-2:20200202

# Create Kyma cluster
k3d cluster create kyma \
    --image "docker.io/rancher/k3s:v1.19.7-k3s1" \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --k3s-server-arg --no-deploy \
    --k3s-server-arg traefik \
    --network k3d-kyma \
    --volume $PWD/${REGISTRY_CONFIG}:/etc/rancher/k3s/registries.yaml \
    --wait \
    --kubeconfig-switch-context \
    --timeout 60s 

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"
