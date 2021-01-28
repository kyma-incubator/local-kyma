#!/bin/bash
set -e

# Instal istio
if [[ ! -f istio-1.8.2/bin/istioctl ]]; then
  curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=1.8.2 sh -
fi
istio-1.8.2/bin/istioctl install --set profile=demo $@