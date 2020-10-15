minikube tunnel -c >/dev/null 2>&1 &
LB_IP=""
while [[ -z $LB_IP ]]; do LB_IP=$(kubectl get svc istio-ingressgateway -n istio-system -ojsonpath='{.status.loadBalancer.ingress[0].ip}'); echo "Waiting for LoadBalancer IP: $LB_IP"; sleep 5; done
sudo sh -c "echo \"$LB_IP commerce.local.kyma.dev dex.local.kyma.dev lastorder.local.kyma.dev\">>/etc/hosts"
