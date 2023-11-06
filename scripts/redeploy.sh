#! /bin/bash

helm dependency build 
helm template . | kubectl apply -f -