cat <<EOF | kubectl apply -f -
apiVersion: applicationconnector.kyma-project.io/v1alpha1
kind: Application
metadata:
  name: commerce
spec:
  description: Commerce mock
---
apiVersion: applicationconnector.kyma-project.io/v1alpha1
kind: ApplicationMapping
metadata:
  name: commerce
EOF

cat <<EOF | kubectl apply -f -
apiVersion: serverless.kyma-project.io/v1alpha1
kind: Function
metadata:
  name: lastorder
spec:
  deps: "{ \n  \"name\": \"orders\",\n  \"version\": \"1.0.0\",\n  \"dependencies\":
    {\"axios\": \"^0.19.2\"}\n}"
  maxReplicas: 1
  minReplicas: 1
  resources:
    limits:
      cpu: 100m
      memory: 128Mi
    requests:
      cpu: 50m
      memory: 64Mi
  source: "let lastOrder = {};\n\nconst axios = require('axios');\n\nasync function
    getOrder(code) {\n    let url = process.env.GATEWAY_URL+\"/site/orders/\"+code;\n
    \   console.log(\"URL: %s\", url);\n    let response = await axios.get(url,{headers:{\"X-B3-Sampled\":1}})\n
    \   console.log(response.data);\n    return response.data;\n}\n\n\nmodule.exports
    = { \n  main: function (event, context) {\n\n    if (event.data && event.data.orderCode)
    {\n      lastOrder = getOrder(event.data.orderCode)\n    }\n    \n    return lastOrder;\n
    \ }\n}"
---
apiVersion: gateway.kyma-project.io/v1alpha1
kind: APIRule
metadata:
  name: lastorder
spec:
  gateway: kyma-gateway.kyma-system.svc.cluster.local
  rules:
  - accessStrategies:
    - config: {}
      handler: allow
    methods: ["*"]
    path: /.*
  service:
    host: lastorder
    name: lastorder
    port: 80
---
apiVersion: eventing.knative.dev/v1alpha1
kind: Trigger
metadata:
  labels:
    function: lastorder
  name: function-lastorder
spec:
  broker: default
  filter:
    attributes:
      eventtypeversion: v1
      source: commerce
      type: order.created
  subscriber:
    ref:
      apiVersion: v1
      kind: Service
      name: lastorder
EOF

GATEWAY=""
while [[ -z $GATEWAY ]]; do echo "waiting for commerce gateway"; GATEWAY=$(kubectl -n kyma-integration get deployment commerce-application-gateway -ojsonpath='{.metadata.name}'); sleep 2; done

kubectl -n kyma-integration \
  patch deployment commerce-application-gateway --type=json \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/6", "value": "--skipVerify=true"}]'


cat <<EOF | kubectl apply -f -
apiVersion: applicationconnector.kyma-project.io/v1alpha1
kind: TokenRequest
metadata:
  name: commerce
EOF

TOKEN=$(kubectl get tokenrequest.applicationconnector.kyma-project.io commerce -ojsonpath='{.status.token}')

curl -k 'https://commerce.local.kyma.dev/connection' \
  -H 'content-type: application/json' \
  --data-binary '{"token":"https://connector-service.local.kyma.dev/v1/applications/signingRequests/info?token='$TOKEN'","baseUrl":"https://commerce.local.kyma.dev","insecure":true}' \
  --compressed

COMMERCE_WEBSERVICES_ID=""
while [[ -z COMMERCE_WEBSERVICES_ID ]]; do echo "registering commerce webservices"; COMMERCE_WEBSERVICES_ID=$(curl -sk 'https://commerce.local.kyma.dev/local/apis/Commerce%20Webservices/register' -H 'content-type: application/json' -H 'origin: https://commerce.local.kyma.dev' -d '{}' --compressed | jq -r '.id'); sleep 2; done

COMMERCE_EVENTS_ID=""
while [[ -z COMMERCE_EVENTS_ID ]]; do echo "registering commerce events"; COMMERCE_EVENTS_ID=$(curl -sk 'https://commerce.local.kyma.dev/local/apis/Events/register' -H 'content-type: application/json' -H 'origin: https://commerce.local.kyma.dev' -d '{}' --compressed | jq -r '.id'); sleep 2; done

WS_EXT_NAME=""
while [[ -z $WS_EXT_NAME ]]; do echo "waiting for commerce webservices"; WS_EXT_NAME=$(kubectl get serviceclass $COMMERCE_WEBSERVICES_ID -o jsonpath='{.spec.externalName}'); sleep 2; done

EVENTS_EXT_NAME=""
while [[ -z $EVENTS_EXT_NAME ]]; do echo "waiting for commerce events"; EVENTS_EXT_NAME=$(kubectl get serviceclass $COMMERCE_EVENTS_ID -o jsonpath='{.spec.externalName}'); sleep 2; done

cat <<EOF | kubectl apply -f -
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: commerce-webservices
spec:
  serviceClassExternalName: $WS_EXT_NAME
---
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: commerce-events
spec:
  serviceClassExternalName: $EVENTS_EXT_NAME
---
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceBinding
metadata:
  labels:
    function: lastorder
  name: commerce-lastorder-binding
spec:
  instanceRef:
    name: commerce-webservices
---
apiVersion: servicecatalog.kyma-project.io/v1alpha1
kind: ServiceBindingUsage
metadata:
  labels:
    function: lastorder
    serviceBinding: commerce-lastorder-binding
  name: commerce-lastorder-sbu
spec:
  serviceBindingRef:
    name: commerce-lastorder-binding
  usedBy:
    kind: serverless-function
    name: lastorder
EOF

PRICE=""
while [[ -z $PRICE ]] 
do
  curl -sk 'https://commerce.local.kyma.dev/events' \
  -H 'content-type: application/json' \
  -d '{"event-type": "order.created", "event-type-version": "v1", "event-time": "2020-09-28T14:47:16.491Z", "data": {    "orderCode": "123" }, "event-tracing": true}' >/dev/null
  sleep 1;
  RESPONSE=$(curl -sk https://lastorder.local.kyma.dev)
  PRICE=$(echo "$RESPONSE" | jq -r 'select(.orderId=="123")| .totalPriceWithTax.value')
  echo "waiting for last order price, response: $RESPONSE"
done