#!/bin/sh
set -o errexit

kind delete cluster --name kyma
docker rm -f kind-registry