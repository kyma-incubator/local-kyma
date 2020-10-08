k3d cluster create kyma \
    --port 80:80@loadbalancer \
    --port 443:443@loadbalancer \
    --k3s-server-arg --no-deploy \
    --k3s-server-arg traefik \
    --wait \
    --switch-context \
    --timeout 60s