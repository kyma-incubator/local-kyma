SECONDS=0  

sudo usermod -a -G microk8s runner
sudo chown -f -R runner ~/.kube

microk8s install --channel=1.18

microk8s enable dns

microk8s status --wait-ready

mkdir -p ~/.kube

microk8s config > ~/.kube/config

echo "Cluster created in $(( $SECONDS/60 )) min $(( $SECONDS % 60 )) sec"