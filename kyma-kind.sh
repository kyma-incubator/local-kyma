#!/bin/bash
set -o errexit

### Create kind cluster

sh kind-with-docker-registry.sh

while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready"; sleep 2; done

### Install istio 1.5.10-distroless

./istioctl manifest apply -f kind-istio-install.yaml

### Install kyma

kubectl create ns kyma-system                                                                                  
kubectl create ns kyma-integration
kubectl create ns knative-serving
kubectl create ns knative-eventing
kubectl create ns natss

kubectl apply -f resources/cluster-essentials/files -n kyma-system
helm upgrade -i pod-preset resources/cluster-essentials/charts/pod-preset -n kyma-system
helm upgrade -i testing resources/testing -n kyma-system

# Patch CoreDNS with entries for registry.localhost and *.local.kyma.dev
export REGISTRY_IP=$(docker inspect -f '{{.NetworkSettings.Networks.kind.IPAddress}}' kind-registry)
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)" 

export DOMAIN=local.kyma.dev
export OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=false,global.domainName=$DOMAIN,global.tlsCrt=ZHVtbXkK
export ORY=global.ory.hydra.persistence.enabled=false,global.ory.hydra.persistence.postgresql.enabled=false,hydra.hydra.autoMigrate=false
export LOCALREGISTRY="dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=localhost:5000,dockerRegistry.registryAddress=localhost:5000,global.ingress.domainName=$DOMAIN"

helm upgrade -i ingress-dns-cert ingress-dns-cert --set $OVERRIDES -n istio-system
helm upgrade -i istio-kyma-patch resources/istio-kyma-patch -n istio-system

helm upgrade -i dex resources/dex --set $OVERRIDES -n kyma-system
helm upgrade -i ory resources/ory --set $OVERRIDES --set $ORY -n kyma-system
helm upgrade -i api-gateway resources/api-gateway --set $OVERRIDES -n kyma-system

helm upgrade -i rafter resources/rafter --set $OVERRIDES -n kyma-system
helm upgrade -i service-catalog resources/service-catalog --set $OVERRIDES -n kyma-system
helm upgrade -i service-catalog-addons resources/service-catalog-addons --set $OVERRIDES -n kyma-system

helm upgrade -i core resources/core --set $OVERRIDES -n kyma-system
helm upgrade -i console resources/console --set $OVERRIDES -n kyma-system
helm upgrade -i cluster-users resources/cluster-users --set $OVERRIDES -n kyma-system
helm upgrade -i apiserver-proxy resources/apiserver-proxy --set $OVERRIDES -n kyma-system
helm upgrade -i serverless resources/serverless --set $LOCALREGISTRY -n kyma-system
helm upgrade -i logging resources/logging --set $OVERRIDES -n kyma-system

helm upgrade -i knative-eventing resources/knative-eventing -n knative-eventing

helm upgrade -i application-connector resources/application-connector --set $OVERRIDES -n kyma-integration
helm upgrade -i knative-provisioner-natss resources/knative-provisioner-natss -n knative-eventing
helm upgrade -i nats-streaming resources/nats-streaming -n natss
helm upgrade -i event-sources resources/event-sources -n kyma-system

kubectl apply -f installer-local.yaml

echo "##############################################################################"
echo "# Kyma cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"
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
echo ""
echo 'Kyma Console Url:'
echo `kubectl get virtualservice console-web -n kyma-system -o jsonpath='{ .spec.hosts[0] }'`
echo 'User admin@kyma.cx, password:'
echo `kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode`