#!/bin/bash
set -o errexit

export DOMAIN=${KYMA_DOMAIN:-local.kyma.dev}
export OVERRIDES=global.isLocalEnv=false,global.ingress.domainName=$DOMAIN,global.environment.gardener=$GARDENER,global.domainName=$DOMAIN
if [[ -z $REGISTRY_VALUES ]]; then
  export REGISTRY_VALUES="dockerRegistry.enableInternal=false,dockerRegistry.serverAddress=registry.localhost:5000,dockerRegistry.registryAddress=registry.localhost:5000"
fi

# Wait for nodes to be ready before scheduling any workload
while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 2; done

if [[ -z $REGISTRY_IP ]]; then 
  export REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' /registry.localhost)
fi
echo "Patching CoreDns with REGISTRY_IP=$REGISTRY_IP"
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)"

kubectl apply -f resources/cluster-essentials/files -n kyma-system 

set +e
# not needed , as we do not install istio
# delete this section after https://github.com/kyma-project/kyma/pull/9948 is merged
rm resources/serverless/templates/destination-rule.yaml 
set -e

helm upgrade --atomic --create-namespace -i serverless resources/serverless -n kyma-system --set $REGISTRY_VALUES,global.ingress.domainName=$DOMAIN --wait

kubectl apply -f https://www.getambassador.io/yaml/ambassador/ambassador-crds.yaml
kubectl apply -f https://www.getambassador.io/yaml/ambassador/ambassador-rbac.yaml
kubectl apply -f https://www.getambassador.io/yaml/ambassador/ambassador-service.yaml
kubectl scale deployment --replicas 1 ambassador

cat <<EOF | kubectl apply -f - 
apiVersion: serverless.kyma-project.io/v1alpha1
kind: Function
metadata:
  name: demo
spec:
  source: |
    module.exports = {
        main: function(event, context) {
          return 'Hello World!'
        }
      }

---
apiVersion: getambassador.io/v2
kind: Mapping
metadata:
  name: demo
spec:
  prefix: /demo/
  service: demo
EOF

echo "After the function demo and ambassador are ready just call:"
echo ""
echo "curl localhost/demo/"
echo ""
echo "To delete the cluster use kyma-k3d-delete.sh"
