#!/bin/bash
# USAGE
# ./alerts-check.sh <optional sleep in seconds>
# ^C to break
# Generates two files one for firing and one for pending alerts
#
# PREREQUISITES
# - jq
# - oc (logged in at the cmd line in order to get the bearer token)
# VARIABLES

SLEEP_TIME="${1-5}"
REPORT_TIME=$(date +"%Y-%m-%d-%H-%M")
ROUTE="http://localhost:9090/api/v1/alerts"
TOKEN=$(oc whoami --show-token)
# wait for monitoring route to appear and have host populated
until oc exec -n "3scale-test" "prometheus-example-0" -- curl -sS -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" -k "$ROUTE" &> /dev/null
do
    echo "Waiting for 3scale-test pods to be available. Next check in 1 minute."
    sleep 60
done

# Define an array of monitoring data sources
declare -A monitoring_sources=(
  ["threescale"]="{}"
)


# Define an array of alert states to report on
declare -a alert_states=("pending" "firing")

# remove tmp files on ctrl-c
trap 'find . -name "tmp-*" -delete; for source_name in "${!monitoring_sources[@]}"; do for alert_state in "${alert_states[@]}"; do if [[ -f "tmp-${source_name}-alert-${alert_state}-${REPORT_TIME}-report.csv" ]]; then rm "tmp-${source_name}-alert-${alert_state}-${REPORT_TIME}-report.csv"; fi; done; done' EXIT

# function to check if there are no alerts firing bar deadmansnitch
function CHECK_NO_ALERTS() {

  THREESCALE_MONITORING=$(oc exec -n "3scale-test" "prometheus-example-0" -- curl -sS -H "Accept: application/json" -H "Authorization: Bearer $TOKEN" -k "$ROUTE")
  monitoring_sources["threescale"]=$THREESCALE_MONITORING

  # Extract firing alerts from THREESCALE monitoring
  threescale_alerts=$(echo "$THREESCALE_MONITORING" | jq -r '.data.alerts[] | select(.state == "firing") | [.labels.alertname, .state, .activeAt, .labels.severity] | @csv')

  # Extract pending alerts from THREESCALE monitoring
  threescale_alerts_pending=$(echo "$THREESCALE_MONITORING" | jq -r '.data.alerts[] | select(.state == "pending") | [.labels.alertname, .state, .activeAt, .labels.severity] | @csv')

  # Check if there are no firing alerts
  if [[ $(echo "$threescale_alerts" | wc -l | xargs) == 1 ]]; then
    echo No alert firing
    date
  elif [[ $(echo "$threescale_alerts" | wc -l | xargs) != 1 ]]; then
    echo "============================================================================"
    date
    echo "----------------------------------------------------------------------------"
    echo "Following alerts are firing for 3scale-test:"
    echo "$threescale_alerts"
    echo "============================================================================"
    echo "Following alerts are pending for 3scale-test:"
    echo "$threescale_alerts_pending"
    echo "============================================================================"
  fi
}


#If no product is passed in then run for all products
if [[ "$2" == "" ]]; then
  while :; do

    CHECK_NO_ALERTS

    # Loop over each monitoring source
    for source_name in "${!monitoring_sources[@]}"; do
      source_data="${monitoring_sources[$source_name]}"

      # Loop over each alert state to report on
      for alert_state in "${alert_states[@]}"; do
        # Generate a report for the current alert state and monitoring source
        echo "$source_data" |
          jq -r --arg state "$alert_state" '.data.alerts[] | select(.state==$state) | [.labels.alertname, .state, .activeAt, .labels.severity] | @csv' >> "${source_name}-alert-${alert_state}-${REPORT_TIME}-report.csv"

        # Sort the report to remove duplicates
        sort -t',' -k 1,1 -u "${source_name}-alert-${alert_state}-${REPORT_TIME}-report.csv" -o "${source_name}-alert-${alert_state}-${REPORT_TIME}-report.csv"
      done
    done

    echo -e "\n=================== Sleeping for $SLEEP_TIME seconds ======================\n"
    sleep $SLEEP_TIME
    # If the above sleep failed sleep for 5 seconds (default)
    if [[ $? != 0 ]]; then
      sleep 5
    fi
  done
fi