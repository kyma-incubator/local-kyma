SECONDS=0  

# create registry container unless it already exists
docker run -d \
-p 5000:5000 \
--restart=always \
--network=kind \
--name registry.localhost \
-v $PWD/registry:/var/lib/registry \
registry:2

sudo microk8s enable dns

sudo microk8s status --wait-ready

sudo microk8s config > ~/.kube/config

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"