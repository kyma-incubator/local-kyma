# Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm 3](https://helm.sh/docs/intro/quickstart/#install-helm)
- [k3d](https://github.com/rancher/k3d) - you can install it with the command: `brew install k3d` or `curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash`

# Quick start

Checkout this repository and go to the main folder:
```
git clone git@github.com:kyma-incubator/local-kyma-k3d.git
cd local-kyma-k3d
```

Download kyma charts to resources subfolder:
```
./download-kyma-charts.sh
```

Start k3s cluster and Kyma:
```
./kyma-k3d.sh
```

At the end script asks for your password to add TLS certificate to your key chain. 
Use credentials to log into [Kyma Console](https://console.local.kyma.dev)

If you wan to use `kubectl` to connect to the cluster, you have to first execute command `k3d kubeconfig merge kyma --switch-context`
You can get the password for `admin@kyma.cx` in the future by running `kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode`

Your cluster is ready!

![asciicast](local-kyma-k3d.gif)

# Clean up

```
./kyma-k3d-delete.sh
```

# Cache docker registry

Install [crane](https://github.com/google/go-containerregistry/tree/master/cmd/crane) tool with:
```
GO111MODULE=on go get -u github.com/google/go-containerregistry/cmd/crane
```

Start Kyma cluster (`kyma-k3d.sh`) and when it is up and running execute this command:
```
./cache-images.sh
```

Delete the cluster:
```
./kyma-k3d-delete.sh
```

Start it again with using [cached-registries](cached-registries.yaml):
```
./kyma-k3d.sh cached-registries.yaml
```

This time all the images from docker.io, eu.gcr.io, gcr.io, and quay.io will be fetched from your local registry.

Be aware that if you download newer Kyma charts some new images can be used that are not stored in the cache. In this case, installation can fail and you will see some pods in status `ImagePullBackOff`. To fix the problem can just copy the missing image using crane:
```
crane cp some.docker.registry/path/image:tag registry.localhost:5000/path/image:tag
```
If there are more such images you can just start the caching procedure again.

# Stop and start cluster

You can stop Kyma cluster with:
```
k3d cluster stop kyma
```
To start it again execute:
```
./kyma-k3d-start.sh
```
Please bear in mind that after restart Kubernetes will probably restart most of the pods and it takes some time (few minutes).

# FAQ


## Can I use the script on Linux or Windows

The script was tested only on Mac OS. It should not be a big problem to adapt it to Linux, but it wasn't tested there. There is a plan to move the script to Kyma CLI - once it is done all platforms will be supported.

---
## Why not minikube?

K3S starts in about 10 seconds - you can use kubeconfig and access API server. It also takes fewer resources than minikube. For the local development, speed and low resource consumption are critical requirements.

---
## What are the hardware requirements to run Kyma locally?

It was tested on MacBook Pro (i7, 4 core CPU, 16GB RAM). Docker was configured with 8GB RAM and 4 CPU. With such configuration, the installation takes about 5 minutes to complete.

---
## Can I stop and start k3s cluster?

Currently, it doesn't work - not all pods can recover. See the [issue](https://github.com/kyma-incubator/local-kyma-k3d/issues/3). 

---
## What to do if I get an error?

Installation may fail, as the script is simple and doesn't have any retries implemented. Before you start over from scratch you can try to fix the failed component. First, find a failed helm release: `helm ls --all-namespaces`, then find the line in the kyma-k3d.sh script that is installing that component and execute it again. Remember to switch kubeconfig context and set the environment variables used in the command before you run the `helm upgrade` (usually DOMAIN, OVERRIDES). If it doesn't work or the number of broken components is bigger you can start from scratch deleting the k3s cluster with `kyma-k3d-delete.sh` first.
