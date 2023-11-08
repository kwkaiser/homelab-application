#! /bin/bash

helm upgrade bingus . --dependency-update && echo 'Updated!' || helm install bingus . --dependency-update