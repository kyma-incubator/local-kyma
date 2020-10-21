SECONDS=0  

sudo microk8s enable dns

sudo microk8s status --wait-ready

sudo microk8s config > ~/.kube/config

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"