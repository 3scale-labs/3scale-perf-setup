#!/bin/bash

# Get the ADMIN_URL and ADMIN_ACCESS_TOKEN from apimanger and system-seed secret
DOMAIN=$(oc get routes console -n openshift-console -o json | jq -r '.status.ingress[0].routerCanonicalHostname' | sed 's/router-default.//')
ADMIN_ACCESS_TOKEN=$(oc get secret system-seed -n 3scale-test -o jsonpath="{.data.ADMIN_ACCESS_TOKEN}"| base64 --decode)
oc project 3scale-test
# Create the required secrets for Accounts, products and backends. 
oc apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: mytenant
type: Opaque
stringData:
  adminURL: 3scale-admin.$DOMAIN
  token: $ADMIN_ACCESS_TOKEN
EOF
# user secret
oc apply -f - <<EOF
---
apiVersion: v1
kind: Secret
metadata:
  name: myusername01
stringData:
  password: "123456"
EOF
# Developer User
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: DeveloperUser
metadata:
  name: developeruser01
  namespace: 3scale-test
spec:
  developerAccountRef:
    name: developeraccount01
  email: myusername01@example.com
  passwordCredentialsRef:
    name: myusername01
  providerAccountRef:
    name: mytenant
  role: admin
  username: myusername01
EOF
sleep 30
# TODO check for developer user completed
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: DeveloperAccount
metadata:
  name: developeraccount01
  namespace: 3scale-test
spec:
  orgName: pstefans3
  providerAccountRef:
    name: mytenant
EOF
# deploy httpbin and use it as the backend
oc new-project httpbin
oc new-app quay.io/trepel/httpbin
oc get svc
oc scale deployment/httpbin --namespace httpbin --replicas=8 
oc project 3scale-test

# create backend
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: Backend
metadata:
  name: backend1-cr
  namespace: 3scale-test
spec:
  mappingRules:
    - httpMethod: GET
      increment: 1
      last: true
      metricMethodRef: hits
      pattern: /
  name: backend1
  privateBaseURL: 'http://httpbin.httpbin.svc:8080'
  systemName: backend1
EOF
# Product
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: Product
metadata:
  name: product1-cr
  namespace: 3scale-test
spec:
  applicationPlans:
    plan01:
      name: "My Plan 01"
      limits:
        - period: month
          value: 300
          metricMethodRef:
            systemName: hits
            backend: backend1
    plan02:
      name: "My Plan 02"
      limits:
        - period: month
          value: 300
          metricMethodRef:
            systemName: hits
            backend: backend1
  name: product1
  backendUsages:
    backend1:
      path: /
  mappingRules:
    - httpMethod: GET
      pattern : "/"
      metricMethodRef:
        systemName: hits
        backend: backend1
      increment: 1
    - httpMethod: POST
      pattern : "/"
      metricMethodRef:
        systemName: hits
        backend: backend1
      increment: 1    
EOF
# application
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: Application
metadata:
  name: example
  namespace: 3scale-test
spec:
  accountCR: 
    name: developeraccount01
  applicationPlanName: plan01
  productCR: 
    name: product1-cr
  name: testApp
  description: further testing
EOF

# TODO proxy promote
oc apply -f - <<EOF
---
apiVersion: capabilities.3scale.net/v1beta1
kind: ProxyConfigPromote
metadata:
  name: product1-v1-production
  namespace: 3scale-test
spec:
  productCRName: product1-cr
  production: true
  deleteCR: true
EOF
