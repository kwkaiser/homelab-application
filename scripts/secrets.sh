#! /bin/bash
# Sources secrets from a secrets file (testing) or env (prod) & applies to

set -o allexport
DIR=$(dirname "$0")
cd "$DIR"/.. || exit

# TODO: only apply this in dev test -- not prod
source ./vars/devtest-secrets.txt

while IFS='=' read -r -d '' n v; do
  if echo "$n" | grep -i 'k8s_' -q
  then
    cleaned_name=$(echo "$n" | cut -c5- | sed 's/_/./g' )
    kubectl delete secret "$cleaned_name" --ignore-not-found
    kubectl create secret generic "$cleaned_name" --from-literal=value=bingus
  fi
done < <(env -0)