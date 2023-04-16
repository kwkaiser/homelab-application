#! /bin/bash

DIR=$(dirname "$0")

helm uninstall bingus
sleep 10 
helm install bingus .
cd $HOME/documents/homelab-system
sleep 10
make k8s