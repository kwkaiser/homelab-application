#! /bin/bash

ARGS=""
if [[ $PROD == true ]]; then
  ARGS="--values ./values.yaml --values ./prod.yaml"
fi

helm upgrade bingus . $ARGS --dependency-update && echo 'Updated!' || helm install bingus . $ARGS --dependency-update