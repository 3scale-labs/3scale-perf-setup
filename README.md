# Readme 3scale-perf-setup

As series of scripts to automate preparing a cluster for Performance Testing
- Databases
- ApiManager(3scale)
- Monitoring
- Product

# Usage
## Databases Setup
>**NOTE:** Script to be run before 3scale-operator is installed
chmod and run the script against a fresh cluster
```bash
chmod 771 setup_db.sh
./setup_db.sh
```
## ApiManager Setup
`setup_apimanager.sh` script needs to be run after `setup_db.sh`
chmod and run the script 
```bash
chmod 771 setup_apimanager.sh
./setup_apimanager.sh
```
`setup_apimanager.sh` also can take in a development operator index as a command line argument to use your operator index
```bash
./setup_apimanager.sh "quay.io/<YOUR_ORG>/3scale-index:<YOUR_TAG>"
```

## Monitoring Setup
`setup_monitoring.sh` script needs to be run after `setup_db.sh` and `setup_apimanager.sh`
chmod and run the script 
```bash
chmod 771 setup_monitoring.sh
./setup_monitoring.sh
```

## Product Setup
`setup_product.sh` script needs to be run after `setup_db.sh` and `setup_apimanger`
chmod and run the script 
```bash
chmod 771 setup_product.sh
./setup_product.sh
```

## Caputure Resource Metrics
This script requires 2 files containing the start and end times generated with `date -u +%Y-%m-%dT%TZ > perf-test-start-time.txt` and `date -u +%Y-%m-%dT%TZ > perf-test-end-time.txt` respectlively 
- a "perf-test-start-time.txt" file with a valid rfc3339 timestamp from a moment before performance tests started 
- a "perf-test-end-time.txt" file with a valid rfc3339 timestamp from a moment after performance tests finished

`capture_resource-metrics.sh`

```bash
chmod 771 capture_resource-metrics.sh
./capture_resource_metrics.sh
64
32
31.64
277.05847930908203
122.5894775390625
110.1988525390625
4.415
5287.2557373046875
4215.2372829861115
0.09181629062352627
0.09181629062352627
4521.91015625
0.09843198155966482
0.09843198155966482
```

You can copy the output to our google [spreadsheet](https://docs.google.com/spreadsheets/d/1HV577_tQ_f-HRcIN9zYBB6sSIpYo04DSiQMqYe1hEds/edit#gid=0) where it will be formated

## Alerts Check
This script can be run at the start of a test run and it will capture any alerts or pending alerts while running, at the end of the run hit  Ctrl C to exit

```
chmod 771 alert_check.sh
./alert_check.sh
No alert firing
Tue 07 May 2024 14:46:17 IST

=================== Sleeping for 5 seconds ======================

No alert firing
Tue 07 May 2024 14:46:23 IST

=================== Sleeping for 5 seconds ======================

^C

```
While running it will generate and update two files which will capture any alerts that fire or go pending
```bash
threescale-alert-firing-2024-05-07-14-46-report.csv
threescale-alert-pending-2024-05-07-14-46-report.csv
```


