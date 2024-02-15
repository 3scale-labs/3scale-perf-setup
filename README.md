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