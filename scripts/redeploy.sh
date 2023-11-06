#! /bin/bash

helm dependency build && helm upgrade bingus . && echo 'Upgraded!' || helm install bingus .