KID=""
while [[ -z $KID ]]; do echo "waiting for DEX to be ready"; KID=$(curl -sk https://dex.local.kyma.dev/keys |jq -r '.keys[0].kid'); sleep 5; done

cat <<EOF |kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  labels:
    istio-injection: enabled
  name: mocks
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: commerce-mock
  namespace: mocks
  labels:
    app: commerce-mock
spec:
  selector:
    matchLabels:
      app: commerce-mock
  strategy:
    rollingUpdate:
      maxUnavailable: 1
  replicas: 1
  template:
    metadata:
      labels:
        app: commerce-mock
    spec:
      containers:
      - image: eu.gcr.io/kyma-project/xf-application-mocks/commerce-mock:latest
        imagePullPolicy: Always
        name: commerce-mock
        ports:
        - name: http
          containerPort: 10000
        env:
        - name: DEBUG
          value: "true"
        - name: RENEWCERT_JOB_CRON
          value: "00 00 */12 * * *"
        # volumeMounts:
        # - mountPath: "/app/keys"
        #   name: commerce-mock-volume
        resources:
          requests:
            memory: "150Mi"
            cpu: "50m"
          limits:
            memory: "250Mi"
            cpu: "100m"
      # volumes:
      # - name: commerce-mock-volume
      #   persistentVolumeClaim:
      #     claimName: commerce-mock 
---
apiVersion: v1
kind: Service
metadata:
  name: commerce-mock
  namespace: mocks
  labels:
    app: commerce-mock
spec:
  ports:
  - name: http
    port: 10000
  selector:
    app: commerce-mock
---
apiVersion: gateway.kyma-project.io/v1alpha1
kind: APIRule
metadata:
  name: commerce-mock
  namespace: mocks
spec:
  gateway: kyma-gateway.kyma-system.svc.cluster.local
  rules:
  - accessStrategies:
    - config: {}
      handler: allow
    methods: ["*"]
    path: /.*
  service:
    host: commerce
    name: commerce-mock
    port: 10000
EOF

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
EOF

GATEWAY=""
while [[ -z $GATEWAY ]]; do echo "waiting for commerce gateway"; GATEWAY=$(kubectl -n kyma-integration get deployment commerce-application-gateway -ojsonpath='{.metadata.name}'); sleep 2; done

kubectl -n kyma-integration \
  patch deployment commerce-application-gateway --type=json \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/args/6", "value": "--skipVerify=true"}]'

MOCK_PROVIDER=""
while [[ -z $MOCK_PROVIDER ]]; do echo "waiting for commerce mock to be ready"; MOCK_PROVIDER=$(curl -sk https://commerce.local.kyma.dev/local/apis |jq -r '.[0].provider'); sleep 5; done

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

COMMERCE_WEBSERVICES_ID=$(curl -sk 'https://commerce.local.kyma.dev/local/apis/Commerce%20Webservices/register' -H 'content-type: application/json' -d '{}' --compressed | jq -r '.id')

COMMERCE_EVENTS_ID=$(curl -sk 'https://commerce.local.kyma.dev/local/apis/Events/register' -H 'content-type: application/json' -d '{}' --compressed | jq -r '.id')

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
EOF

cat <<EOF | kubectl apply -f -
apiVersion: servicecatalog.k8s.io/v1beta1
kind: ServiceInstance
metadata:
  name: commerce-events
spec:
  serviceClassExternalName: $EVENTS_EXT_NAME
EOF


cat <<EOF | kubectl apply -f -
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

cat <<EOF | kubectl apply -f -
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
EOF

cat <<EOF | kubectl apply -f -
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

PRICE=""

while [[ -z $PRICE ]] 
do
  curl -sk 'https://commerce.local.kyma.dev/events' \
  -H 'content-type: application/json' \
  -d '{"event-type": "order.created", "event-type-version": "v1", "event-time": "2020-09-28T14:47:16.491Z", "data": {    "orderCode": "123" }, "event-tracing": true}' >/dev/null
  sleep 1;
  PRICE=$(curl -sk https://lastorder.local.kyma.dev | jq -r 'select(.orderId=="123")| .totalPriceWithTax.value')
  echo "waiting for last order price: $PRICE"
done