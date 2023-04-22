#! /bin/bash

# Sources secrets from a secrets file (testing) or env (prod) & applies to
# secrets.yaml file

set -o allexport

DIR=$(dirname "$0")
cd $DIR/..

source ./vars/devtest-secrets.txt

cat ./non-templates/secrets.yaml | envsubst | kubectl apply -f -