#!/bin/bash

# Prereq: 
# oc, openshift cluster, ssh keys setup for github, operator-sdk, go1.19

# Usage : 
# chmod 771 setup_db.sh
# ./setup_db.sh

# Outcome: 
# CRO will create three redis and one posgres and secrets pointing to these db will be created in the 3scale-test ns


# Function to check if redis CR is available
check_redis_available() {
    local message=$(oc get redis "$1" -o jsonpath="{.status.message}")
    if [[ "$message" == *"redis deployment available"* ]]; then
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
    if [[ "$message" == *"creation successful"* ]]; then
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
REDIS_NAME=redis-storage make cluster/seed/redis
REDIS_NAME=redis-queue make cluster/seed/redis
REDIS_NAME=redis-system make cluster/seed/redis
make cluster/seed/postgres

RECTIME=30 WATCH_NAMESPACE=cloud-resource-operator go run ./main.go &>/dev/null &

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
# delete the cloud-resources-operator dir
cd ..
rm -rf cloud-resources-operator


# create the 3scale namespace
oc new-project 3scale-test

# Creating secrets in the 3scale-test namespace
echo Creating secrets in the 3scale-test namespace
oc create secret generic system-redis \
    --from-literal=URL=redis://redis-system.cloud-resource-operator.svc.cluster.local:6379 \
    --namespace=3scale-test
oc create secret generic backend-redis \
    --from-literal=REDIS_QUEUES_URL=redis://redis-queue.cloud-resource-operator.svc.cluster.local:6379 \
    --from-literal=REDIS_STORAGE_URL=redis://redis-queue.cloud-resource-operator.svc.cluster.local:6379 \
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



