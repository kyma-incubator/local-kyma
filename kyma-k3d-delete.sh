# This will delete the cluster and the docker registry
k3d cluster delete kyma
docker rm -f  k3d-registry