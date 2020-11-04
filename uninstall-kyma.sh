#!/bin/bash

SECONDS=0  

# Wait until number of background jobs is less than $1, try every $2 second(s)
function waitForJobs() {
    while (( (( JOBS_COUNT=$(jobs -p | wc -l) )) > $1 )); do echo "Waiting for $JOBS_COUNT command(s) executed in the background, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; jobs >/dev/null ; sleep $2; done
}
kubectl delete ValidatingWebhookConfiguration config.webhook.eventing.knative.dev
kubectl delete ValidatingWebhookConfiguration validation.webhook.eventing.knative.dev
kubectl delete MutatingWebhookConfiguration webhook.eventing.knative.dev
kubectl delete MutatingWebhookConfiguration legacysinkbindings.webhook.sources.knative.dev
kubectl delete MutatingWebhookConfiguration sinkbindings.webhook.sources.knative.dev

kubectl delete apirules --all -A
kubectl delete rules.oathkeeper.ory.sh --all -A
kubectl delete secret -n istio-system kyma-gateway-certs-cacert

helm ls -A -ojson | jq -r '.[] | "helm delete \(.name) -n \(.namespace)"' | while read -r line; do bash -c "$line &" ; done

# Wait for jobs - helm commands executed in the background
waitForJobs 0 5

kubectl delete -f resources/cluster-essentials/files -n kyma-system 

# Delete namespaces
kubectl delete ns kyma-system
kubectl delete ns kyma-integration
kubectl delete ns knative-eventing
kubectl delete ns natss
kubectl delete ns mocks


echo "Kyma uninstalled in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"