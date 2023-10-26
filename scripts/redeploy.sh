#! /bin/bash

helm upgrade bingus . --recreate-pods && echo 'Upgraded!' || helm install bingus .