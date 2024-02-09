#!/bin/bash
# Prereq:
# jq, oc, openshift cluster, ssh keys setup for github, operator-sdk, go1.19

# Usage: 
# chmod 771 setup_monitoring.sh
# ./setup_apimanager.sh

oc project 3scale-test
# Install 3scale-operator via olm
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  labels:
    operators.coreos.com/3scale-operator.3scale-test: ''
  name: 3scale-operator
  namespace: 3scale-test
spec:
  channel: threescale-2.14
  installPlanApproval: Automatic
  name: 3scale-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: 3scale-operator.v0.11.10
EOF

# set the operator group to namespaces scope
sleep 30
OPERATORGROUP=$(oc get operatorGroup | grep 3scale | awk '{print $1}')
oc patch operatorgroup "${OPERATORGROUP}" --type='json' -p='[{"op": "replace", "path": "/spec/targetNamespaces", "value": ["3scale-test"]}]'

# create dummy S3 secret
oc apply -f - <<EOF
---
kind: Secret
apiVersion: v1
metadata:
  name: s3-credentials
data:
  AWS_ACCESS_KEY_ID: UkVQTEFDRV9NRQ==
  AWS_BUCKET: UkVQTEFDRV9NRQ==
  AWS_REGION: UkVQTEFDRV9NRQ==
  AWS_SECRET_ACCESS_KEY: UkVQTEFDRV9NRQ==
type: Opaque
EOF
# Create Apimanager CR with monitoring enabled and system-database set to postgresql
DOMAIN=$(oc get routes console -n openshift-console -o json | jq -r '.status.ingress[0].routerCanonicalHostname' | sed 's/router-default.//')
oc apply -f - <<EOF
---
apiVersion: apps.3scale.net/v1alpha1
kind: APIManager
metadata:
  name: apimanager-sample
spec:
  system:
    monitoring:
        enabled : true
    database:
        postgresql: {}
    fileStorage:
      simpleStorageService:
        configurationSecretRef:
          name: s3-credentials
  wildcardDomain: $DOMAIN
EOF
# Check the install has completed for five minuits
oc wait --for=condition=available apimanager/apimanager-sample --timeout=300s