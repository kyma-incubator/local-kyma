#!/bin/bash
set -o errexit

SECONDS=0  
GARDENER=${GARDENER:-false}
export DOMAIN=${KYMA_DOMAIN:-local.kyma.dev}
export OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=$GARDENER,global.domainName=$DOMAIN,global.tlsCrt=ZHVtbXkK
export ORY=global.ory.hydra.persistence.enabled=false,global.ory.hydra.persistence.postgresql.enabled=false,hydra.hydra.autoMigrate=false,hydra.deployment.resources.requests.cpu=10m,oathkeeper.deployment.resources.requests.cpu=10m
# export REGISTRY_VALUES="dockerRegistry.username=$REGISTRY_USER,dockerRegistry.password=$REGISTRY_PASS,dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=ghcr.io,dockerRegistry.registryAddress=ghcr.io/$REGISTRY_USER"       
if [[ -z $REGISTRY_VALUES ]]; then
  export REGISTRY_VALUES="dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=registry.localhost:5000,dockerRegistry.registryAddress=registry.localhost:5000"
fi

# Wait until number of background jobs is less than $1, try every $2 second(s)
function waitForJobs() {
    while (( (( JOBS_COUNT=$(jobs -p | wc -l) )) > $1 )); do echo "Waiting for $JOBS_COUNT command(s) executed in the background, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; jobs >/dev/null ; sleep $2; done
}

function helm_install() {
  local release=$1
  local chart=$2
  local namespace=$3
  local retries=3
  if [[ $SKIP_MODULES =~ $release ]]; 
  then
    echo "$release skipped"
    return 0
  fi
  while [ $retries -ge 0 ]
  do
    ((retries--))
    echo "Checking status of release $1 in the namespace $namespace"
    local status=$(helm ls -n $namespace -ojson | jq -r ".[]|select(.name==\"$release\")|.status")
    if [[ "$status" == "deployed" ]];
    then
      echo "$release deployed" 
      break
    fi
    echo "Installing $1 in the namespace $namespace"    
    set +e
    helm upgrade --atomic -i $release $chart -n $namespace "${@:4}" 
    set -e
  done
}

set +e
# This file will be created by cert-manager (not needed anymore):
rm resources/core/charts/gateway/templates/kyma-gateway-certs.yaml

set -e 

# Create namespaces
cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: kyma-system
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: kyma-integration
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: knative-eventing
---
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: natss
EOF

# Wait for nodes to be ready before scheduling any workload
while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 2; done

if [[ -z $REGISTRY_IP ]]; then 
  export REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' /registry.localhost)
fi
echo "Patching CoreDns with REGISTRY_IP=$REGISTRY_IP"
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)"

kubectl apply -f resources/cluster-essentials/files -n kyma-system 
helm_install pod-preset resources/cluster-essentials/charts/pod-preset kyma-system & 
helm_install ingress-dns-cert ingress-dns-cert istio-system --set global.ingress.domainName=$DOMAIN,global.environment.gardener=$GARDENER &

helm_install dex resources/dex kyma-system --set $OVERRIDES --set resources.requests.cpu=10m &
helm_install ory resources/ory kyma-system --set $OVERRIDES --set $ORY &
helm_install api-gateway resources/api-gateway kyma-system --set $OVERRIDES --set deployment.resources.requests.cpu=10m & 

helm_install rafter resources/rafter kyma-system --set $OVERRIDES &

helm_install service-catalog resources/service-catalog kyma-system --set $OVERRIDES --set catalog.webhook.resources.requests.cpu=10m,catalog.controllerManager.resources.requests.cpu=10m &
helm_install service-catalog-addons resources/service-catalog-addons kyma-system --set $OVERRIDES &
# helm_install helm-broker resources/helm-broker kyma-system --set $OVERRIDES &

helm_install core resources/core kyma-system --set $OVERRIDES &
helm_install console resources/console kyma-system --set $OVERRIDES &
helm_install cluster-users resources/cluster-users kyma-system --set $OVERRIDES &
helm_install serverless resources/serverless kyma-system --set $REGISTRY_VALUES,global.ingress.domainName=$DOMAIN &
helm_install logging resources/logging kyma-system --set $OVERRIDES &
helm_install tracing resources/tracing kyma-system --set $OVERRIDES &

helm_install knative-eventing resources/knative-eventing knative-eventing &

helm_install application-connector resources/application-connector kyma-integration --set $OVERRIDES &
helm_install knative-provisioner-natss resources/knative-provisioner-natss knative-eventing &
helm_install nats-streaming resources/nats-streaming natss &
helm_install event-sources resources/event-sources kyma-system &

# helm_install kiali resources/kiali kyma-system --set global.ingress.domainName=$DOMAIN &
# helm_install monitoring resources/monitoring kyma-system --set global.ingress.domainName=$DOMAIN &

# Create installer deployment scaled to 0 to get console running:
kubectl apply -f installer-local.yaml &

# Wait for jobs - helm commands executed in the background
waitForJobs 0 5

echo "##############################################################################"
echo "# Kyma installed in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"
echo "##############################################################################"
echo
# Download the certificate: 
kubectl get secret kyma-gateway-certs -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 --decode > kyma.crt
# Import the certificate: 
echo "Generated self signed TLS certificate should be trusted in your system. On Mac Os X execute this command:"
echo ""
echo "  sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain kyma.crt"
echo ""
echo "This is one time operation (you can skip this step if you did it before)."

if [[ ! $SKIP_MODULES =~ "console" ]]; 
then
  echo ""
  echo 'Kyma Console Url:'
  echo `kubectl get virtualservice console-web -n kyma-system -o jsonpath='{ .spec.hosts[0] }'`
  echo 'User admin@kyma.cx, password:'
  echo `kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode`
fi
