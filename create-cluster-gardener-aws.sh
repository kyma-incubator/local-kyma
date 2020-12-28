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
    type: aws
    infrastructureConfig:
      apiVersion: aws.provider.extensions.gardener.cloud/v1alpha1
      kind: InfrastructureConfig
      networks:
        vpc:
          cidr: 10.250.0.0/16
        zones:
          - name: eu-central-1b
            workers: 10.250.0.0/19
            public: 10.250.32.0/20
            internal: 10.250.48.0/20
    controlPlaneConfig:
      apiVersion: aws.provider.extensions.gardener.cloud/v1alpha1
      kind: ControlPlaneConfig
    workers:
      - name: worker-mk12q
        minimum: 1
        maximum: 1
        maxSurge: 1
        machine:
          type: m5.xlarge
          image:
            name: gardenlinux
            version: 184.0.0
        zones:
          - eu-central-1b
        volume:
          type: gp2
          size: 50Gi
  networking:
    type: calico
    nodes: 10.250.0.0/16
  cloudProfileName: aws
  secretBindingName: trial-secretbinding-aws
  region: eu-central-1
  purpose: evaluation
  kubernetes:
    version: 1.18.12
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