#! /bin/bash

ARGS=""
if [[ $PROD == true ]]; then
  ARGS="--values ./values/shared.yaml --values ./values/prod.yaml"
else
  ARGS="--values ./values/shared.yaml --values ./values/dev.yaml"
fi

helm upgrade bingus . $ARGS --dependency-update && echo 'Updated!' || helm install bingus . $ARGS --dependency-update