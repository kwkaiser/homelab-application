#!/bin/sh
set -eu

apk add --no-cache curl jq >/dev/null

API="${GITEA_URL}/api/v1"
K8S_API="${K8S_API:-https://kubernetes.default.svc}"
SA_DIR="${SA_DIR:-/var/run/secrets/kubernetes.io/serviceaccount}"
INUSE="${INUSE:-/tmp/registry-inuse}"
TAB=$(printf '\t')

api() {
  curl -sS -f -H "Authorization: token ${GITEA_TOKEN}" "$@"
}

k8s() {
  curl -sS -f --cacert "${SA_DIR}/ca.crt" \
    -H "Authorization: Bearer $(cat "${SA_DIR}/token")" \
    "${K8S_API}$1"
}

: > "$INUSE"

for path in \
  /api/v1/pods \
  /apis/apps/v1/deployments \
  /apis/apps/v1/statefulsets \
  /apis/apps/v1/daemonsets \
  /apis/batch/v1/jobs \
  /apis/batch/v1/cronjobs
do
  resp=$(k8s "$path")
  printf '%s' "$resp" | jq -r --arg host "$REGISTRY_HOST" '
    [.. | objects | select(has("image")) | .image | select(type == "string")]
    | unique
    | .[]
    | select(startswith($host + "/"))
    | ltrimstr($host + "/")
    | select(contains("@") | not)
    | capture("^(?<owner>[^/]+)/(?<name>.+):(?<version>[^:/]+)$")
    | "\(.owner)|\(.name)|\(.version)"
  ' >> "$INUSE"
done

sort -u "$INUSE" -o "$INUSE"
echo "in-use registry images: $(wc -l < "$INUSE")"

for OWNER in ${OWNERS}; do
  page=1
  versions=""

  while :; do
    resp=$(api "${API}/packages/${OWNER}?type=container&page=${page}&limit=50")
    n=$(printf '%s' "$resp" | jq 'length')

    if [ "$n" -eq 0 ]; then
      break
    fi

    versions="${versions}$(printf '%s' "$resp" | jq -c '.[]')
"
    page=$((page + 1))
  done

  if [ -z "$versions" ]; then
    echo "${OWNER}: no container packages"
    continue
  fi

  printf '%s' "$versions" | jq -s -r \
    --argjson keep "${KEEP_VERSIONS}" \
    --arg owner "$OWNER" \
    --rawfile inuse "$INUSE" '
    ($inuse | split("\n") | map(select(length > 0))) as $pinned
    | map(select(.version | startswith("sha256:") | not))
    | group_by(.name)
    | map(
        map(select(.version != "latest"))
        | sort_by(.created_at)
        | reverse
        | .[$keep:]
      )
    | flatten
    | map(select(($owner + "|" + .name + "|" + .version) as $k | ($pinned | index($k)) == null))
    | .[]
    | "\(.name)\t\(.version)\t\(.version | @uri)"
  ' | while IFS="$TAB" read -r name version encoded; do
    if [ -z "$name" ]; then
      continue
    fi

    if [ "${DRY_RUN}" = "true" ]; then
      echo "would delete ${OWNER}/${name}:${version}"
    else
      echo "deleting ${OWNER}/${name}:${version}"
      api -X DELETE -o /dev/null "${API}/packages/${OWNER}/container/${name}/${encoded}"
    fi
  done
done
