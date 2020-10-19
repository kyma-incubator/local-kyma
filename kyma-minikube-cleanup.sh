#!/bin/sh
set -o errexit

minikube delete 
docker rm -f registry.localhost