k3d cluster start kyma --wait
export KUBECONFIG="$(k3d kubeconfig merge kyma --kubeconfig-switch-context)"
# Wait for nodes to be ready before scheduling any workload
while [[ $(kubectl get nodes -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "Waiting for cluster nodes to be ready, elapsed time: $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"; sleep 2; done
export REGISTRY_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' /registry.localhost)
sed "s/REGISTRY_IP/$REGISTRY_IP/" coredns-patch.tpl >coredns-patch.yaml
kubectl -n kube-system patch cm coredns --patch "$(cat coredns-patch.yaml)"
kubectl delete pod -n kyma-system -l app=dex
kubectl delete pod -n istio-system -l app=istio-ingressgateway
kubectl delete pod -n kyma-system -l app=backend
