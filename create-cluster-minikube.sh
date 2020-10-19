#!/bin/bash
set -o errexit

# Start docker Registry
docker run -d \
-p 5000:5000 \
--restart=always \
--name registry.localhost \
-v $PWD/registry:/var/lib/registry \
registry:2

echo "Starting cluster"
minikube start --memory=6800m --kubernetes-version=1.18.9 --insecure-registry="registry.localhost:5000"
minikube ssh "sudo sh -c \"grep host.minikube.internal /etc/hosts | sed s/host.minikube.internal/registry.localhost/ >>/etc/hosts\""