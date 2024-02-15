# Readme 3scale-perf-setup

As series of scripts to automate preparing a cluster for Performance Testing
- Databases
- ApiManager(3scale)
- Monitoring

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

## Monitoring Setup
`setup_monitoring.sh` script needs to be run after `setup_db.sh` and `setup_apimanager.sh`
chmod and run the script 
```bash
chmod 771 setup_monitoring.sh
./setup_monitoring.sh
```