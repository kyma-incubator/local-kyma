#!/bin/bash

SECONDS=0  

kubectl delete ValidatingWebhookConfiguration config.webhook.eventing.knative.dev
kubectl delete ValidatingWebhookConfiguration validation.webhook.eventing.knative.dev
kubectl delete MutatingWebhookConfiguration webhook.eventing.knative.dev
kubectl delete MutatingWebhookConfiguration legacysinkbindings.webhook.sources.knative.dev
kubectl delete MutatingWebhookConfiguration sinkbindings.webhook.sources.knative.dev

kubectl delete apirules --all -A
kubectl delete rules.oathkeeper.ory.sh --all -A
kubectl delete secret -n istio-system kyma-gateway-certs-cacert
kubectl delete ServiceBindingUsage --all -A
kubectl delete ServiceBinding --all -A
kubectl delete ServiceInstance --all -A
kubectl delete function --all -A
kubectl delete ApplicationMapping --all -A
kubectl delete Application --all -A
kubectl delete deployment --all
kubectl delete service --all

helm ls -A -ojson | jq -r '.[] | "helm delete \(.name) -n \(.namespace)"' | while read -r line; do bash -c "$line" ; done

kubectl delete -f resources/cluster-essentials/files -n kyma-system 

# Delete namespaces
kubectl delete ns kyma-system
kubectl delete ns kyma-integration
kubectl delete ns knative-eventing
kubectl delete ns natss
kubectl delete ns mocks

echo "Kyma uninstalled in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"