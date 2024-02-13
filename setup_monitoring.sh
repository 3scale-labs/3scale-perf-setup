#!/bin/bash
# Prereq:
# jq, oc, openshift cluster, ssh keys setup for github, operator-sdk, go1.19

# Usage: 
# chmod 771 setup_monitoring.sh
# ./setup_monitoring.sh

git clone git@github.com:3scale/3scale-operator.git
cd 3scale-operator/doc/monitoring-stack-deployment
oc project 3scale-test
# Create a subscription for prometheus operator
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: rhods-prometheus-operator
  namespace: 3scale-test
spec:
  channel: beta
  installPlanApproval: Automatic
  name: rhods-prometheus-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
  startingCSV: rhods-prometheus-operator.4.10.0
EOF
# Create a subscription for prometheus-exporter operator
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: prometheus-exporter-operator
  namespace: 3scale-test
spec:
  channel: alpha
  installPlanApproval: Automatic
  name: prometheus-exporter-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: prometheus-exporter-operator.v0.7.0
EOF
# Create Grafana Subscription
oc apply -f - <<EOF
---
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: grafana-operator
  namespace: 3scale-test
spec:
  channel: v4
  installPlanApproval: Automatic
  name: grafana-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
  startingCSV: grafana-operator.v4.10.1
EOF
# patch apimanager CR monitoring enabled true
sleep 30
oc patch apimanager apimanager-sample --type='json' -p='[{"op": "add", "path": "/spec/monitoring", "value": {"enabled": true}}]'
# Get the SECRET name that contains the THANOS_QUERIER_BEARER_TOKEN
SECRET=`oc get secret -n openshift-user-workload-monitoring | grep  prometheus-user-workload-token | head -n 1 | awk '{print $1 }'`
# Get the THANOS_QUERIER_BEARER_TOKEN using the SECRET name
THANOS_QUERIER_BEARER_TOKEN=$(oc get secret $SECRET -n openshift-user-workload-monitoring -o jsonpath="{.data.token}" | base64 -d)
# patch the THANOS_QUERIER_BEARER_TOKEN in the 3scale-scrape-configs.yaml
sed -i "s|<THANOS_QUERIER_BEARER_TOKEN>|$THANOS_QUERIER_BEARER_TOKEN|g" 3scale-scrape-configs.yaml
# create secret addition-scrape-configs from 3scale-scrape-configs.yaml file
oc create secret generic additional-scrape-configs --from-file=3scale-scrape-configs.yaml=./3scale-scrape-configs.yaml

# prometheus exporter 
BKEND_REDIS_URL=$(oc get secret backend-redis -n 3scale-test -o jsonpath={.data.REDIS_QUEUES_URL} | base64 -d)
BACKEND_REDIS_URL=$(echo "$BKEND_REDIS_URL" | sed 's|^redis://||; s|:6379$||')

oc apply -n 3scale-test -f - <<EOF   
---
apiVersion: monitoring.3scale.net/v1alpha1
kind: PrometheusExporter
metadata:
  name: backend-redis
spec:
  type: redis
  grafanaDashboard:
    label:
      key: monitoring-key
      value: middleware
  extraLabel:
    key: threescale_component
    value: backend
  dbHost: $BACKEND_REDIS_URL
  dbPort: 6379
  dbCheckKeys: "db1=resque:queue:stats,db1=resque:queue:priority,db1=resque:queue:main,db1=resque:failed,db1=resque:workers,db1=resque:queues"
EOF
# Prometheus CR
DOMAIN=$(oc get routes console -n openshift-console -o json | jq -r '.status.ingress[0].routerCanonicalHostname' | sed 's/router-default.//')
EXTERNALURL=https://prometheus.3scale-test.$DOMAIN
sed -i "s|externalUrl:.*|externalUrl: $EXTERNALURL|" prometheus.yaml
oc apply -f prometheus.yaml
oc expose service prometheus-operated --hostname prometheus.3scale-test.$DOMAIN
# Grafana CR's
oc apply -f datasource.yaml
oc apply -f grafana.yaml
# remove 3scale-operator dir
cd ../../../
rm -rf 3scale-operator