SECONDS=0  

microk8s install

microk8s status --wait-ready

microk8s enable dns storage registry

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"