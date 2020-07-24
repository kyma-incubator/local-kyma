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
k3d cluster delete kyma
docker rm -f  k3d-registry
```

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
