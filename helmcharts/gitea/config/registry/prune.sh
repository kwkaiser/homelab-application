#!/bin/sh
set -eu

apk add --no-cache curl jq >/dev/null

API="${GITEA_URL}/api/v1"
TAB=$(printf '\t')

api() {
  curl -sS -f -H "Authorization: token ${GITEA_TOKEN}" "$@"
}

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

  printf '%s' "$versions" | jq -s -r --argjson keep "${KEEP_VERSIONS}" '
    map(select(.version | startswith("sha256:") | not))
    | group_by(.name)
    | map(
        map(select(.version != "latest"))
        | sort_by(.created_at)
        | reverse
        | .[$keep:]
      )
    | flatten
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
