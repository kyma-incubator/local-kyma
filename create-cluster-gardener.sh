#!/bin/bash

echo $GARDEN_KUBECONFIG | base64 -D  > ./garden-kubeconfig.yaml
export SHOOT_NAME=${SHOOT_NAME:-c$(date +"%d%H%M%S")}

cat <<EOF | kubectl --kubeconfig ./garden-kubeconfig.yaml apply -f - 
kind: Shoot
apiVersion: core.gardener.cloud/v1beta1
metadata:
  name: $SHOOT_NAME
spec:
  provider:
    type: gcp
    infrastructureConfig:
      apiVersion: gcp.provider.extensions.gardener.cloud/v1alpha1
      kind: InfrastructureConfig
      networks:
        workers: 10.250.0.0/16
    controlPlaneConfig:
      apiVersion: gcp.provider.extensions.gardener.cloud/v1alpha1
      kind: ControlPlaneConfig
      zone: europe-west1-c
    workers:
      - name: worker-np1s8
        minimum: 1
        maximum: 1
        maxSurge: 1
        machine:
          type: n1-standard-4
          image:
            name: gardenlinux
            version: 184.0.0
        zones:
          - europe-west1-c
        volume:
          type: pd-standard
          size: 50Gi
  networking:
    type: calico
    nodes: 10.250.0.0/16
  cloudProfileName: gcp
  region: europe-west1
  secretBindingName: trial-secretbinding-gcp
  kubernetes:
    version: 1.18.9
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