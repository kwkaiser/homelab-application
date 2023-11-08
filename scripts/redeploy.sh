#! /bin/bash

helm upgrade bingus . --dependency-update --debug && echo 'Updated!' || helm install bingus . --dependency-update --debug