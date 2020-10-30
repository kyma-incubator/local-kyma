export KYMA_DOMAIN=$(kubectl get cm shoot-info -n kube-system -ojsonpath='{.data.domain}')
export REGISTRY_VALUES="dockerRegistry.enableInternal=true"
export REGISTRY_IP=127.0.0.1
export GARDENER=true

./install-kyma.sh