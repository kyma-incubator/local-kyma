# Prerequisites
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [helm 3](https://helm.sh/docs/intro/quickstart/#install-helm)
- [k3d](https://github.com/rancher/k3d) - you can install it with the command: `curl -s https://raw.githubusercontent.com/rancher/k3d/master/install.sh | bash`

# Quick start

Checkout this repository and 

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
Use credentials to log into [Kyma Console](https://console.local.kyma.pro)

Your cluster is ready!

[![asciicast](https://asciinema.org/a/346654.svg)](https://asciinema.org/a/346654?autoplay=1)

# Clean up

```
k3d delete -n kyma
```

# Notes
The script works only on Mac OS. You need docker configured with 4 CPU and 8GB RAM to run it smoothly.

