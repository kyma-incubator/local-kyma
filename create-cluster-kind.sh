#!/bin/sh
set -o errexit

# create registry container unless it already exists
docker run -d \
-p 5000:5000 \
--restart=always \
--name registry.localhost \
-v $PWD/registry:/var/lib/registry \
registry:2

# create a cluster with the local registry enabled in containerd
cat <<EOF | kind create cluster --name kyma --config=-
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
containerdConfigPatches:
- |-
  [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:5000"]
    endpoint = ["http://registry.localhost:5000"]
nodes:
- role: control-plane
  kubeadmConfigPatches:
  - |
    kind: InitConfiguration
    nodeRegistration:
      kubeletExtraArgs:
        node-labels: "ingress-ready=true"
  image: kindest/node:v1.18.8@sha256:f4bcc97a0ad6e7abaf3f643d890add7efe6ee4ab90baeb374b4f41a4c95567eb
  extraPortMappings:
  - containerPort: 30000
    hostPort: 80
    protocol: tcp
    listenAddress: "127.0.0.1"
  - containerPort: 30001
    hostPort: 443
    protocol: tcp
    listenAddress: "127.0.0.1"
  - containerPort: 30002
    hostPort: 15021
    protocol: tcp
    listenAddress: "127.0.0.1"
EOF

# connect the registry to the cluster network
docker network connect "kind" "registry.localhost"

# tell https://tilt.dev to use the registry
# https://docs.tilt.dev/choosing_clusters.html#discovering-the-registry
for node in $(kind get nodes --name kyma); do
  kubectl annotate node "${node}" "kind.x-k8s.io/registry=localhost:${reg_port}";
done