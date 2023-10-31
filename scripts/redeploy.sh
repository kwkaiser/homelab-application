#! /bin/bash

helm upgrade bingus . && echo 'Upgraded!' || helm install bingus .