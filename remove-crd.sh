function patch_obj() {
    CRD=$1
    NAME=$2
    echo "CRD=$CRD"
    echo "NAME=$NAME"
    kubectl patch $CRD $NAME -p '{"metadata":{"finalizers":[]}}' --type=merge
}
function patch_all_crd() {
  CRD=$1
  echo "CRD to remove $CRD"
  kubectl get $CRD -ojson | jq -r ".items[].metadata.name" | while read -r name; do patch_obj $CRD $name; done

}

kubectl get crd -ojson | jq -r '.items[].metadata.name' |grep kyma |while read -r line; do patch_all_crd $line ; done
