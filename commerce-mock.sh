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
#      - image: eu.gcr.io/kyma-project/xf-application-mocks/commerce-mock:latest
      - image: pbochynski/commerce-mock-lite:0.2
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
            cpu: "10m"
          limits:
            memory: "350Mi"
            cpu: "300m"
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

MOCK_HOST=""
while [[ -z $MOCK_HOST ]]; do echo "waiting for mock host"; MOCK_HOST=$(kubectl get virtualservice -n mocks -ojsonpath='{.items[0].spec.hosts[0]}'); sleep 3; done

MOCK_PROVIDER=""
while [[ -z $MOCK_PROVIDER ]]; do echo "waiting for commerce mock to be ready"; MOCK_PROVIDER=$(curl -sk https://$MOCK_HOST/local/apis |jq -r '.[0].provider') ; sleep 5; done
