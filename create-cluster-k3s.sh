#!/bin/bash
set -o errexit

echo "starting docker registry"
sudo mkdir -p /etc/rancher/k3s
sudo cp registries.yaml /etc/rancher/k3s
docker run -d \
-p 5000:5000 \
--restart=always \
--name registry.localhost \
-v $PWD/registry:/var/lib/registry \
registry:2

echo "starting cluster"
curl -sfL https://get.k3s.io | INSTALL_K3S_CHANNEL_URL="https://update.k3s.io/v1-release/channels/v1.18" K3S_KUBECONFIG_MODE=777 INSTALL_K3S_EXEC="server --disable traefik" sh -
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chmod 600 ~/.kube/config
