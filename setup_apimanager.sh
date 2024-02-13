#!/bin/bash
# Prereq:
# jq, oc, openshift cluster, ssh keys setup for github, operator-sdk, go1.19

# Usage: 
# chmod 771 setup_monitoring.sh
# ./setup_apimanager.sh
# you can pass a new index image in
# ./setup_apimanager.sh "quay.io/<YOUR_ORG>/3scale-index:<YOUR_TAG>"

oc project 3scale-test
# Install 3scale-operator via olm
INDEX_IMG=quay.io/austincunningham/3scale-index:2.15

# Check if an argument is passed
if [ $# -eq 1 ]; then
    # Override INDEX_IMG if argument is passed
    INDEX_IMG=$1
fi

# Use the value of INDEX_IMG in your script
echo "Using INDEX_IMG: $INDEX_IMG"

oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: threescale-operators
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: $INDEX_IMG
EOF

check_catalogsource_available() {
    local STATE=$(oc get catalogsource threescale-operators -n openshift-marketplace -o jsonpath="{.status.connectionState.lastObservedState}")
    if [[ "$STATE" == *"READY"* ]]; then
        return 0  # CatalogSource is available
    else
        return 1  # CatalogSource is not available
    fi
}
# Check olm is completed
while true; do
    if check_catalogsource_available; then
        echo "catalogsource is available. Proceeding with the script."
        break  # Exit the loop when condition is satisfied
    else
        echo "catalogsource is not available. Retrying in 10 seconds."
        sleep 10  # Wait for 10 seconds before retrying
    fi
done
# Create namespaced scoped OperatorGroup
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  generateName: 3scale-test-
  annotations:
    olm.providedAPIs: 'APIManager.v1alpha1.apps.3scale.net,APIManagerBackup.v1alpha1.apps.3scale.net,APIManagerRestore.v1alpha1.apps.3scale.net,ActiveDoc.v1beta1.capabilities.3scale.net,Application.v1beta1.capabilities.3scale.net,Backend.v1beta1.capabilities.3scale.net,CustomPolicyDefinition.v1beta1.capabilities.3scale.net,DeveloperAccount.v1beta1.capabilities.3scale.net,DeveloperUser.v1beta1.capabilities.3scale.net,OpenAPI.v1beta1.capabilities.3scale.net,Product.v1beta1.capabilities.3scale.net,ProxyConfigPromote.v1beta1.capabilities.3scale.net,Tenant.v1alpha1.capabilities.3scale.net'
  name: 3scale-test-1
  namespace: 3scale-test
spec:
  targetNamespaces:
    - 3scale-test
  upgradeStrategy: Default
EOF
# Subscription for 2.15 dev image to olm install 3scale operator
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: dev-image-3scale-operator
  namespace: 3scale-test
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: dev-image-3scale-operator
  source: threescale-operators
  sourceNamespace: openshift-marketplace
  startingCSV: dev-image-3scale-operator.0.0.1
EOF
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
    database:
        postgresql: {}
    fileStorage:
      simpleStorageService:
        configurationSecretRef:
          name: s3-credentials
  wildcardDomain: $DOMAIN
EOF
# Check the install has completed for five minuits
echo Check the install has completed for five minuits
oc wait --for=condition=available apimanager/apimanager-sample --timeout=300s