#!/bin/bash

SECONDS=0  

kubectl delete ValidatingWebhookConfiguration config.webhook.eventing.knative.dev --force=true --wait=false
kubectl delete ValidatingWebhookConfiguration validation.webhook.eventing.knative.dev --force=true --wait=false
kubectl delete MutatingWebhookConfiguration webhook.eventing.knative.dev --force=true --wait=false
kubectl delete MutatingWebhookConfiguration legacysinkbindings.webhook.sources.knative.dev --force=true --wait=false
kubectl delete MutatingWebhookConfiguration sinkbindings.webhook.sources.knative.dev --force=true --wait=false

kubectl delete apirules --all -A --force=true --wait=false
kubectl delete rules.oathkeeper.ory.sh --all -A --force=true --wait=false
kubectl delete secret -n istio-system kyma-gateway-certs-cacert --force=true --wait=false
kubectl delete ServiceBindingUsage --all -A --force=true --wait=false
kubectl delete ServiceBinding --all -A --force=true --wait=false
kubectl delete ServiceInstance --all -A --force=true --wait=false
kubectl delete function --all -A --force=true --wait=false
kubectl delete ApplicationMapping --all -A --force=true --wait=false
kubectl delete Application --all -A --force=true --wait=false
kubectl delete deployment --all --force=true --wait=false
kubectl delete service --all --force=true --wait=false
kubectl delete clusterassets.rafter.kyma-project.io --all --force=true --wait=false
kubectl delete clusterbuckets.rafter.kyma-project.io --all --force=true --wait=false

helm ls -A -ojson | jq -r '.[] | "helm delete \(.name) -n \(.namespace)"' | while read -r line; do bash -c "$line" ; done

kubectl delete -f resources/cluster-essentials/files -n kyma-system --force=true --wait=false
kubectl delete crd clusterassets.rafter.kyma-project.io --force=true --wait=false
kubectl delete crd clusterbuckets.rafter.kyma-project.io --force=true --wait=false

# Delete namespaces
kubectl delete ns kyma-system --force=true --wait=false
kubectl delete ns kyma-integration --force=true --wait=false
kubectl delete ns kyma-installer --force=true --wait=false
kubectl delete ns istio-system --force=true --wait=false
kubectl delete ns knative-eventing --force=true --wait=false
kubectl delete ns natss --force=true --wait=false
kubectl delete ns mocks --force=true --wait=false

./remove-crd.sh

echo "Kyma uninstalled in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"