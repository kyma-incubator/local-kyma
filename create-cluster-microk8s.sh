SECONDS=0  

microk8s enable dns

microk8s status --wait-ready

mkdir -p ~/.kube

microk8s config > ~/.kube/config

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"