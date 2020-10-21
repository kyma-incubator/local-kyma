SECONDS=0  

microk8s enable dns

microk8s status --wait-ready

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"