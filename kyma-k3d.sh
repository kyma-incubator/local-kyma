SECONDS=0  
REGISTRY_CONFIG=${1:-registries.yaml}

# Wait until number of background jobs is less than $1, try every $2 second(s)
function waitForJobs() {
    while (( (( JOBS_COUNT=$(jobs -p | wc -l) )) > $1 )); do echo "Waiting for $JOBS_COUNT command(s) executed in the background, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; jobs >/dev/null ; sleep $2; done
}

# Create docker network
docker network create k3d-kyma

# Start docker Registry
docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry.localhost \
  --network k3d-kyma \
  -v $PWD/registry:/var/lib/registry \
  registry:2

# Create Kyma cluster
k3d cluster create kyma \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --k3s-server-arg --no-deploy \
    --k3s-server-arg traefik \
    --network k3d-kyma \
    --volume $PWD/${REGISTRY_CONFIG}:/etc/rancher/k3s/registries.yaml \
    --wait \
    --switch-context \
    --timeout 60s 

# Delete cluster with keep-registry-volume to cache docker images
# k3d cluster delete kyma
echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"

# This file will be created by cert-manager (not needed anymore):
rm resources/core/charts/gateway/templates/kyma-gateway-certs.yaml

# apiserver-proxy dependencies are not required (cannot be disabled by values yet):
rm resources/apiserver-proxy/requirements.yaml
rm -R resources/apiserver-proxy/charts

# Create namespaces
kubectl create ns kyma-system
kubectl create ns istio-system
kubectl create ns kyma-integration
kubectl create ns knative-serving
kubectl create ns knative-eventing
kubectl create ns natss

kubectl label ns istio-system istio-injection=disabled --overwrite

# Wait for nodes to be ready before scheduling any workload
while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 2; done

kubectl apply -f resources/cluster-essentials/files -n kyma-system 
helm upgrade -i pod-preset resources/cluster-essentials/charts/pod-preset -n kyma-system
helm upgrade -i testing resources/testing -n kyma-system 

# Patch CoreDNS with entries for registry.localhost and *.local.kyma.dev
export REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' /registry.localhost)
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)" &

helm upgrade -i istio resources/istio --set global.isLocalEnv=true -n istio-system 

# Set environment variables with chart values (overrides)
export DOMAIN=local.kyma.dev
export OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=false,global.domainName=$DOMAIN,global.tlsCrt=ZHVtbXkK
export ORY=global.ory.hydra.persistence.enabled=false,global.ory.hydra.persistence.postgresql.enabled=false,hydra.hydra.autoMigrate=false
export LOCALREGISTRY="dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=registry.localhost:5000,dockerRegistry.registryAddress=registry.localhost:5000,global.ingress.domainName=$DOMAIN"

helm upgrade -i ingress-dns-cert ingress-dns-cert --set $OVERRIDES -n istio-system & 
helm upgrade -i istio-kyma-patch resources/istio-kyma-patch -n istio-system &

helm upgrade -i dex resources/dex --set $OVERRIDES -n kyma-system &
helm upgrade -i ory resources/ory --set $OVERRIDES --set $ORY -n kyma-system &
helm upgrade -i api-gateway resources/api-gateway --set $OVERRIDES -n kyma-system & 

helm upgrade -i rafter resources/rafter --set $OVERRIDES -n kyma-system &
helm upgrade -i service-catalog resources/service-catalog --set $OVERRIDES -n kyma-system &
helm upgrade -i service-catalog-addons resources/service-catalog-addons --set $OVERRIDES -n kyma-system &
helm upgrade -i helm-broker resources/helm-broker --set $OVERRIDES -n kyma-system &

helm upgrade -i core resources/core --set $OVERRIDES -n kyma-system &
helm upgrade -i console resources/console --set $OVERRIDES -n kyma-system &
helm upgrade -i cluster-users resources/cluster-users --set $OVERRIDES -n kyma-system &
helm upgrade -i apiserver-proxy resources/apiserver-proxy --set $OVERRIDES -n kyma-system &
helm upgrade -i serverless resources/serverless --set $LOCALREGISTRY -n kyma-system &
helm upgrade -i logging resources/logging --set $OVERRIDES -n kyma-system &
helm upgrade -i tracing resources/tracing --set $OVERRIDES -n kyma-system &

helm upgrade -i knative-eventing resources/knative-eventing -n knative-eventing &

helm upgrade -i application-connector resources/application-connector --set $OVERRIDES -n kyma-integration &
helm upgrade -i knative-provisioner-natss resources/knative-provisioner-natss -n knative-eventing &
helm upgrade -i nats-streaming resources/nats-streaming -n natss &
helm upgrade -i event-sources resources/event-sources -n kyma-system &

# Create installer deployment scaled to 0 to get console running:
kubectl apply -f installer-local.yaml &

# Wait for jobs - helm commands executed in the background
waitForJobs 0 5

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
 
