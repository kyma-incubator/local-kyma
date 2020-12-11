#!/bin/bash

echo $GARDEN_KUBECONFIG | base64 --decode  > ./garden-kubeconfig.yaml
export SHOOT_NAME=${SHOOT_NAME:-c$(date +"%d%H%M%S")}

cat <<EOF | kubectl --kubeconfig ./garden-kubeconfig.yaml apply -f - 
kind: Shoot
apiVersion: core.gardener.cloud/v1beta1
metadata:
  name: $SHOOT_NAME
spec:
  provider:
    type: azure
    controlPlaneConfig:
      apiVersion: azure.provider.extensions.gardener.cloud/v1alpha1
      kind: ControlPlaneConfig
    infrastructureConfig:
      apiVersion: azure.provider.extensions.gardener.cloud/v1alpha1
      kind: InfrastructureConfig
      networks:
        vnet:
          cidr: 10.250.0.0/16
        workers: 10.250.0.0/16
      zoned: true
    workers:
      - name: worker-azure
        machine:
          type: Standard_D4_v3
          image:
            name: gardenlinux
            version: 184.0.0
        maximum: 1
        minimum: 1
        maxSurge: 1
        maxUnavailable: 0
        volume:
          type: Standard_LRS
          size: 50Gi
        systemComponents:
          allow: true
  networking:
    type: calico
    pods: 100.96.0.0/11
    nodes: 10.250.0.0/16
    services: 100.64.0.0/13
  cloudProfileName: az
  region: northeurope
  secretBindingName: azure-pb
  kubernetes:
    version: 1.18.12
  purpose: evaluation
  addons:
    kubernetesDashboard:
      enabled: false
    nginxIngress:
      enabled: false
  maintenance:
    timeWindow:
      begin: 220000+0000
      end: 230000+0000
    autoUpdate:
      kubernetesVersion: true
      machineImageVersion: true
  hibernation:
    schedules: []
EOF

STATUS="False"
while [[ $STATUS != "True" ]]; do
    STATUS=$(kubectl --kubeconfig ./garden-kubeconfig.yaml get shoot $SHOOT_NAME -ojson | jq -r '.status.conditions[] | select(.type=="EveryNodeReady") | .status')
    echo "Waiting for shoot $SHOOT_NAME nodes to be ready: $(kubectl --kubeconfig ./garden-kubeconfig.yaml get shoot $SHOOT_NAME -ojsonpath='{.status.lastOperation.description}')"
    sleep 5
done

kubectl --kubeconfig ./garden-kubeconfig.yaml get secret $SHOOT_NAME.kubeconfig -ojsonpath='{.data.kubeconfig}' | base64 --decode > ~/.kube/config
chmod 600 ~/.kube/config