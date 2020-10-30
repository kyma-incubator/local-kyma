#!/bin/bash
set -e

# Instal istio
if [[ ! -f istio-1.7.4/bin/istioctl ]]; then
  curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=1.7.4 sh -
fi
istio-1.7.4/bin/istioctl install --set profile=demo $@