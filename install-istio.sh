# Instal istio
if [[ ! -f istio-1.5.10/bin/istioctl ]]; then
  curl -sL https://istio.io/downloadIstio | ISTIO_VERSION=1.5.10 sh -
fi
istio-1.5.10/bin/istioctl manifest apply --set profile=demo $@