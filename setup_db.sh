#!/bin/bash

# Prereq: 
# oc, openshift cluster, ssh keys setup for github, operator-sdk, go1.19

# Usage : 
# chmod 771 setup_db.sh
# ./setup_db.sh

# Outcome: 
# CRO will create three redis and one postgres and secrets pointing to these db will be created in the 3scale-test ns


# Function to check if redis CR is available
check_redis_available() {
    local message=$(oc get redis "$1" -o jsonpath="{.status.message}")
    if [[ "$message" == *"successful"* ]]; then
        return 0  # Redis CR is available
    else
        return 1  # Redis CR is not available
    fi
}

# Function to check if redis CR phase is complete
check_redis_complete() {
    local phase=$(oc get redis "$1" -o jsonpath="{.status.phase}")
    if [[ "$phase" == "complete" ]]; then
        return 0  # Redis CR phase is complete
    else
        return 1  # Redis CR phase is not complete
    fi
}

# Function to check if postgres CR is available
check_postgres_available() {
    local message=$(oc get postgres example-postgres -o jsonpath="{.status.message}")
    if [[ "$message" == *"successful"* ]]; then
        return 0  # Postgres CR is available
    else
        return 1  # Postgres CR is not available
    fi
}

# Function to check if postgres CR phase is complete
check_postgres_complete() {
    local phase=$(oc get postgres example-postgres -o jsonpath="{.status.phase}")
    if [[ "$phase" == "complete" ]]; then
        return 0  # Postgres CR phase is complete
    else
        return 1  # Postgres CR phase is not complete
    fi
}

git clone git@github.com:integr8ly/cloud-resource-operator.git
cd cloud-resource-operator
make cluster/prepare

# install the cro index
oc apply -f - <<EOF
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: cro-operators
  namespace: openshift-marketplace
spec:
  sourceType: grpc
  image: quay.io/integreatly/cloud-resource-operator:index-v1.1.3
EOF

# Check the catalog source is ready
check_catalogsource_available() {
    local STATE=$(oc get catalogsource cri-operators -n openshift-marketplace -o jsonpath="{.status.connectionState.lastObservedState}")
    if [[ "$STATE" == *"READY"* ]]; then
        return 0  # CatalogSource is available
    else
        return 1  # CatalogSource is not available
    fi
}

# Create operator group
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: cloud-resource-og
  namespace: cloud-resource-operator
spec:
  targetNamespaces:
    - cloud-resource-operator
  upgradeStrategy: Default
EOF

# Subscription for CRO
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhmi-cloud-resources
  namespace: cloud-resource-operator
spec:
  channel: rhmi
  installPlanApproval: Automatic
  name: rhmi-cloud-resources
  source: cro-operators
  sourceNamespace: openshift-marketplace
  startingCSV: cloud-resources.v1.1.3
EOF

# wait for CRD to be deployed
sleep 30

REDIS_NAME=redis-storage make cluster/seed/redis
REDIS_NAME=redis-queue  make cluster/seed/redis
REDIS_NAME=redis-system  make cluster/seed/redis
make cluster/seed/postgres

# Check postgres is completed
while true; do
    if check_postgres_available && check_postgres_complete; then
        echo "Both postgres conditions are satisfied for example-postgres. Proceeding with the script."
        break  # Exit the loop when both conditions are satisfied
    else
        echo "One or both postgres conditions are not satisfied for example-postgres. Retrying in 10 seconds."
        sleep 10  # Wait for 10 seconds before retrying
    fi
done
# Check all redis are completed
redis_variables=("redis-storage" "redis-queue" "redis-system")

for var in "${redis_variables[@]}"; do
    while true; do
        if check_redis_available "$var" && check_redis_complete "$var"; then
            echo "Both redis conditions are satisfied for $var. Proceeding with the script."
            break  # Exit the loop when both conditions are satisfied
        else
            echo "One or both conditions are not satisfied for $var. Retrying in 10 seconds."
            sleep 10  # Wait for 10 seconds before retrying
        fi
    done
done

                                                      
# Kill the operator process
pkill -f "main.go"
# delete the cloud-resource-operator dir
cd ..
rm -rf cloud-resource-operator


# create the 3scale namespace
oc new-project 3scale-test

# Creating secrets in the 3scale-test namespace
echo Creating secrets in the 3scale-test namespace
REDIS_QUEUES_URL=$(oc get secret redis-queue-sec -n cloud-resource-operator -o jsonpath="{.data.uri}" | base64 -d)
REDIS_QUEUES_PORT=$(oc get secret redis-queue-sec -n cloud-resource-operator -o jsonpath="{.data.port}" | base64 -d)
REDIS_STORAGE_URL=$(oc get secret redis-storage-sec -n cloud-resource-operator -o jsonpath="{.data.uri}" | base64 -d)
REDIS_STORAGE_PORT=$(oc get secret redis-storage-sec -n cloud-resource-operator -o jsonpath="{.data.port}" | base64 -d)
REDIS_SYSTEM_URL=$(oc get secret redis-system-sec -n cloud-resource-operator -o jsonpath="{.data.uri}" | base64 -d)
REDIS_SYSTEM_PORT=$(oc get secret redis-system-sec -n cloud-resource-operator -o jsonpath="{.data.port}" | base64 -d)

oc create secret generic system-redis \
    --from-literal=URL=redis://"$REDIS_SYSTEM_URL":"$REDIS_SYSTEM_PORT" \
    --namespace=3scale-test
oc create secret generic backend-redis \
    --from-literal=REDIS_QUEUES_URL=redis://"$REDIS_QUEUES_URL":"$REDIS_QUEUES_PORT" \
    --from-literal=REDIS_STORAGE_URL=redis://"$REDIS_STORAGE_URL":"$REDIS_STORAGE_PORT" \
    --namespace=3scale-test

PASSWORD=$(oc get secret example-postgres-sec -n cloud-resource-operator -o jsonpath="{.data.password}" | base64 -d)
HOST=$(oc get secret example-postgres-sec -n cloud-resource-operator -o jsonpath="{.data.host}" | base64 -d)
DATABASE=$(oc get secret example-postgres-sec -n cloud-resource-operator -o jsonpath="{.data.database}" | base64 -d)
USERNAME=$(oc get secret example-postgres-sec -n cloud-resource-operator -o jsonpath="{.data.username}" | base64 -d)
PORT=$(oc get secret example-postgres-sec -n cloud-resource-operator -o jsonpath="{.data.port}" | base64 -d)

oc create secret generic system-database \
    --from-literal=DB_PASSWORD="$PASSWORD" \
    --from-literal=DB_USER="$USERNAME" \
    --from-literal=URL=postgresql://"$USERNAME":"$PASSWORD"@"$HOST":"$PORT"/"$DATABASE" \
    --namespace=3scale-test
