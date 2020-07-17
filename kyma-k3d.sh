SECONDS=0

function waitForJobs() {
    while (( (( JOBS_COUNT=$(jobs -p | wc -l) )) > 0 )); do echo "Waiting for $JOBS_COUNT command(s) executed in the background, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; jobs >/dev/null ; sleep $1; done
}

# Create Kyma cluster
k3d create --publish 80:80 --publish 443:443 --enable-registry --registry-volume local_registry --registry-name registry.localhost --server-arg --no-deploy --server-arg traefik -n kyma -t 60 



# Delete cluster with keep-registry-volume to cache docker images
# k3d delete --keep-registry-volume -n kyma
echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"
KUBECONFIG="$(k3d get-kubeconfig -n='kyma')"

# This file will be created by cert-manager (not needed anymore):
rm resources/core/charts/gateway/templates/kyma-gateway-certs.yaml

# apiserver-proxy dependencies are not required (cannot be disabled by values yet):
rm resources/apiserver-proxy/requirements.yaml
rm -R resources/apiserver-proxy/charts

# Create namespaces
kubectl create ns kyma-system
kubectl create ns istio-system
kubectl create ns kyma-integration
kubectl create ns cert-manager
kubectl create ns knative-serving
kubectl create ns knative-eventing
kubectl create ns natss

kubectl label ns istio-system istio-injection=disabled --overwrite
kubectl label ns cert-manager istio-injection=disabled --overwrite

helm upgrade -i cluster-essentials resources/cluster-essentials -n kyma-system &
helm upgrade -i testing resources/testing -n kyma-system &
kubectl apply -f cert-manager.yaml &

# Patch CoreDNS with entries for registry.localhost and *.local.kyma.dev
REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' /k3d-registry)
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)" &
helm upgrade -i istio resources/istio --set global.isLocalEnv=true -n istio-system &

while [[ $(kubectl get pods -n istio-system -l istio=sidecar-injector -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for Istio sidecar-injector, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 10; done
echo "Istio installed in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"

DOMAIN=local.kyma.dev
OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=false,global.domainName=$DOMAIN,global.tlsCrt=ZHVtbXkK
ORY=global.ory.hydra.persistence.enabled=false,global.ory.hydra.persistence.postgresql.enabled=false,hydra.hydra.autoMigrate=false
LOCALREGISTRY="dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=registry.localhost:5000,dockerRegistry.registryAddress=registry.localhost:5000,global.ingress.domainName=$DOMAIN"

helm upgrade -i ingress-dns-cert ingress-dns-cert --set $OVERRIDES -n istio-system & 
helm upgrade -i istio-kyma-patch resources/istio-kyma-patch -n istio-system &

helm upgrade -i dex resources/dex --set $OVERRIDES -n kyma-system &
helm upgrade -i ory resources/ory --set $OVERRIDES --set $ORY -n kyma-system &
helm upgrade -i api-gateway resources/api-gateway --set $OVERRIDES -n kyma-system & 

helm upgrade -i rafter resources/rafter --set $OVERRIDES -n kyma-system &
helm upgrade -i service-catalog resources/service-catalog --set $OVERRIDES -n kyma-system &
helm upgrade -i service-catalog-addons resources/service-catalog-addons --set $OVERRIDES -n kyma-system &
# helm upgrade -i helm-broker resources/helm-broker --set $OVERRIDES -n kyma-system &

helm upgrade -i core resources/core --set $OVERRIDES -n kyma-system &
helm upgrade -i console resources/console --set $OVERRIDES -n kyma-system &
helm upgrade -i cluster-users resources/cluster-users --set $OVERRIDES -n kyma-system &
helm upgrade -i apiserver-proxy resources/apiserver-proxy --set $OVERRIDES -n kyma-system &
helm upgrade -i serverless resources/serverless --set $LOCALREGISTRY -n kyma-system &
helm upgrade -i logging resources/logging --set $OVERRIDES -n kyma-system &

helm upgrade -i application-connector resources/application-connector --set $OVERRIDES -n kyma-integration &

# Install knative-eventing and knative-serving
helm upgrade -i knative-serving resources/knative-serving --set $OVERRIDES -n knative-serving &
helm upgrade -i knative-eventing resources/knative-eventing -n knative-eventing &
helm upgrade -i knative-provisioner-natss resources/knative-provisioner-natss -n knative-eventing &
helm upgrade -i nats-streaming resources/nats-streaming -n natss &
helm upgrade -i event-sources resources/event-sources -n kyma-system &

# Create installer deployment scaled to 0 to get console running:
kubectl apply -f installer-local.yaml &

# Wait for jobs - helm commands executed in the background
waitForJobs 10

echo "##############################################################################"
echo "# Kyma cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"
echo "##############################################################################"
echo
echo "Genereated self signed TLS certificate is about to be added to your keychain (admin pass is required)"
# Download the certificate: 
kubectl get secret kyma-gateway-certs -n istio-system -o jsonpath='{.data.tls\.crt}' | base64 --decode > kyma.crt
# Import the certificate: 
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain kyma.crt

echo 'Kyma Console Url:'
echo `kubectl get virtualservice console-web -n kyma-system -o jsonpath='{ .spec.hosts[0] }'`
echo 'User admin@kyma.cx, password:'
echo `kubectl get secret admin-user -n kyma-system -o jsonpath="{.data.password}" | base64 --decode`
