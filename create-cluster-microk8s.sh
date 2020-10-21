SECONDS=0  

sudo microk8s enable dns

sudo microk8s status --wait-ready

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"