#!/bin/bash
set -o errexit

./create-cluster-k3d.sh
./install-serverless.sh
