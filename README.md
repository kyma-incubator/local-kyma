![Tests on k3s](https://github.com/kyma-incubator/local-kyma-k3d/workflows/Tests%20on%20k3s/badge.svg) ![Tests on minikube](https://github.com/kyma-incubator/local-kyma-k3d/workflows/Tests%20on%20minikube/badge.svg) ![Tests on kind](https://github.com/kyma-incubator/local-kyma-k3d/workflows/Tests%20on%20kind/badge.svg)

# Overview
This repository contains scripts to start Kyma on local kubernetes cluster (k3s) in about 5 minutes! 

> Tested on Mac Book Pro 2017 (2,9 GHz Quad-Core Intel Core i7, 16 GB RAM, SSD disk)

# Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm 3](https://helm.sh/docs/intro/quickstart/#install-helm)
- [k3d](https://github.com/rancher/k3d) - you can install it with the command: `brew install k3d` or `curl -s https://raw.githubusercontent.com/rancher/k3d/main/install.sh | bash`

# Quick start

Checkout this repository and go to the main folder:
```
git clone git@github.com:kyma-incubator/local-kyma.git
cd local-kyma
```

Download kyma charts to resources subfolder:
```
./download-kyma-charts.sh
```

Start k3s cluster and Kyma:
```
./kyma-k3d.sh
```

At the end script asks you to add TLS certificate to your key chain (the command for Mac OS X is provided). You need to do it only once.

Use credentials to log into [Kyma Console](https://console.local.kyma.dev)

If you wan to use `kubectl` to connect to the cluster, you have to first execute command `k3d kubeconfig merge kyma --switch-context`
You can get the password for `admin@kyma.cx` in the future by running `kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode`

Your cluster is ready!

![asciicast](local-kyma-k3d.gif)

When you are done you can clean up with this command:

```
./kyma-k3d-delete.sh
```

# Application Connector Example

Empty Kyma cluster in 5 minutes is good enough. What about investing another 3 minutes to have:
- SAP Commerce mock deployed and connected
- simple serverless function named `lastorder` in the default namespace triggered by `order.created` event
- Commerce Webservices API bound to the function

Deploy the example with these commands:
```
./commerce-mock.sh
./app-connector-example.sh
```

Then you can open [https://commerce.local.kyma.dev](https://commerce.local.kyma.dev) navigate to Remote API / SAP Commerce Cloud - Events and try to send order.created event with any code.
When event is delivered you can check if your event was processed by calling the `lastorder` function exposed through API Gateway: [https://lastorder.local.kyma.dev](https://lastorder.local.kyma.dev)

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

The script was tested only on Mac OS and Linux (ubuntu). Please be aware that for Linux you should use k3s (not k3d) version of create cluster script. It should also work with Windows Linux Subsystem (WSL 2), but I didn't test it yet. 

---
## I see k3s, k3d, kind and minikube - what should I use?

Short answer: k3d (Mac Os) or k3s (Linux, WSL).

Long answer:

K3d is a docker wrapper around k3s (which runs on linux only) - it is more or less the same. Here is a small comparison with kind and minikube:

|   | k3s/k3d | minikube | kind |
----|:-------:|:--------:|:----:|
K8s installation + startup time | ~ 25 sec  | ~ 90 sec | ~ 100 sec 
Cluster startup time (second run) | ~ 15 sec  | ~ 30 sec | ~ 30 sec 
Allocated memory (e2e scenario) | 4.2 GB | 6.6 GB | 6.8 GB 
Kyma installation time | ~ 3 min | ~ 5-6 min | ~ 4-5 min 
LoadBalancer support | yes | yes/no (requires another process for minikube tunnel command) | no 
Expose LB ports on host machine (use localhost) | yes | yes(mac) / no(linux)  | yes/no (extraPortMappings to service exposed with NodePort) 

Summary: if you pick minikube or kind you need 50% more resources, 50% more time for cluster startup or Kyma installation and you need a special configuration or process to access ingress gateway from your localhost.

**A winner is: k3s/k3d!**

---
## What are the hardware requirements to run Kyma locally?

It was tested on MacBook Pro (i7, 4 core CPU, 16GB RAM). Docker was configured with 8GB RAM and 4 CPU. With such configuration, the installation takes about 5 minutes to complete.

---
## Can I stop and start k3s cluster?

Currently, it doesn't work - not all pods can recover. See the [issue](https://github.com/kyma-incubator/local-kyma-k3d/issues/3). 

---
## What to do if I get an error?

Installation may fail, as the script is simple and doesn't have any retries implemented. Before you start over from scratch you can try to fix the failed component. First, find a failed helm release: `helm ls --all-namespaces`, then find the line in the kyma-k3d.sh script that is installing that component and execute it again. Remember to switch kubeconfig context and set the environment variables used in the command before you run the `helm upgrade` (usually DOMAIN, OVERRIDES). If it doesn't work or the number of broken components is bigger you can start from scratch deleting the k3s cluster with `kyma-k3d-delete.sh` first.

---
## Can I pick modules to install?

Yes, just edit kyma-k3d.sh script and remove modules you don't need. 

---
## Why kyma-installer is scaled down to 0 replicas?

Kyma-installer doesn't support parallel installation and local charts (from your local disk) yet. As the short time of installation and possibility to customize charts are main requirements for local development, the decision to use helm client directly was made. The deployment with 0 replicas is created only for Kyma console - it takes Kyma version from kyma-installer deployment version.

---
## How *.local.kyma.dev URLs are recognized on my machine?

There is an A type DNS record pointing *.local.kyma.dev to 127.0.0.1. The k3s load balancer is exposed on port 443 of your local host. So all the https requests going to *.local.kyma.dev are routed to loadbalancer and then to istio-ingressgateway.

---
## How local.kyma.dev URL work inside the cluster (from pod)?

In the cluster network `*.local.kyma.dev` points directly to `istio-ingressgateway.istio-system.svc.cluster.local`. It is done by patching CoreDNS [config map](coredns-patch.tpl).
