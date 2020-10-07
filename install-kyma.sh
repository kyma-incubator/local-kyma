SECONDS=0  
export DOMAIN=local.kyma.dev
export OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=false,global.domainName=$DOMAIN,global.tlsCrt=ZHVtbXkK
export ORY=global.ory.hydra.persistence.enabled=false,global.ory.hydra.persistence.postgresql.enabled=false,hydra.hydra.autoMigrate=false
       
# Wait until number of background jobs is less than $1, try every $2 second(s)
function waitForJobs() {
    while (( (( JOBS_COUNT=$(jobs -p | wc -l) )) > $1 )); do echo "Waiting for $JOBS_COUNT command(s) executed in the background, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; jobs >/dev/null ; sleep $2; done
}

function helm_install() {
  local release=$1
  local chart=$2
  local namespace=$3
  while true
  do
    local status=$(helm ls -n $namespace -ojson | jq -r ".[]|select(.name==\"$release\")|.status")
    if [[ "$status" == "deployed" ]];
    then
      echo "$release deployed" 
      break
    fi
    helm upgrade -i $release $chart -n $namespace "${@:4}" 
  done
}
# This file will be created by cert-manager (not needed anymore):
rm resources/core/charts/gateway/templates/kyma-gateway-certs.yaml

# apiserver-proxy dependencies are not required (cannot be disabled by values yet):
rm resources/apiserver-proxy/requirements.yaml
rm -R resources/apiserver-proxy/charts

# Create namespaces
kubectl create ns kyma-system
kubectl create ns istio-system
kubectl create ns kyma-integration
kubectl create ns knative-eventing
kubectl create ns natss

kubectl label ns kyma-system istio-injection=enabled --overwrite
kubectl label ns kyma-integration istio-injection=enabled --overwrite
kubectl label ns knative-eventing istio-injection=enabled --overwrite
kubectl label ns default istio-injection=enabled --overwrite

# Wait for nodes to be ready before scheduling any workload
while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 2; done

kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.tpl)"
kubectl apply -f resources/cluster-essentials/files -n kyma-system 
helm_install pod-preset resources/cluster-essentials/charts/pod-preset kyma-system 
helm_install testing resources/testing kyma-system 
curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.5.8 sh -
istio-1.5.8/bin/istioctl manifest apply --set profile=demo 
helm_install ingress-dns-cert ingress-dns-cert istio-system --set $OVERRIDES &

#helm_install istio-kyma-patch resources/istio-kyma-patch istio-system &

helm_install dex resources/dex kyma-system --set $OVERRIDES &
helm_install ory resources/ory kyma-system --set $OVERRIDES --set $ORY &
helm_install api-gateway resources/api-gateway kyma-system --set $OVERRIDES & 

helm_install rafter resources/rafter kyma-system --set $OVERRIDES &
helm_install service-catalog resources/service-catalog kyma-system --set $OVERRIDES &
helm_install service-catalog-addons resources/service-catalog-addons kyma-system --set $OVERRIDES &
# helm_install helm-broker resources/helm-broker kyma-system --set $OVERRIDES &

helm_install core resources/core kyma-system --set $OVERRIDES&
# helm_install console resources/console kyma-system --set $OVERRIDES &
# helm_install cluster-users resources/cluster-users kyma-system --set $OVERRIDES &
# helm_install apiserver-proxy resources/apiserver-proxy kyma-system --set $OVERRIDES &
# helm_install logging resources/logging kyma-system --set $OVERRIDES &
# helm_install tracing resources/tracing kyma-system --set $OVERRIDES &

helm_install knative-eventing resources/knative-eventing knative-eventing &

helm_install application-connector resources/application-connector kyma-integration --set $OVERRIDES &
helm_install knative-provisioner-natss resources/knative-provisioner-natss knative-eventing &
helm_install nats-streaming resources/nats-streaming natss &
helm_install event-sources resources/event-sources kyma-system &

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
