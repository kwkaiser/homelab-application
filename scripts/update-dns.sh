#!/usr/bin/env bash
# Points every kwkaiser.io DNS A record at the given IP, except the apex
# domain, www, and the *.kwkaiser.io wildcard record - all intentionally
# excluded. (The apex/www exclusion matches the dns-poll CronJob at
# helmcharts/core/templates/dns-poll/cron.yaml, which has the same logic
# but only ever dry-runs it; the wildcard exclusion is specific to this
# script.)
#
# Only ever touches type=A records - MX (or any other record type) is a
# separate query entirely and never fetched here, so mail routing can't be
# affected. Defaults to a dry run (prints what *would* change, touches
# nothing) since an A record could still be something mail-adjacent (e.g. a
# self-hosted mail server's own address) that isn't safe to assume from a
# name pattern - review the dry-run output, then pass --apply once you're
# sure none of the listed changes should be excluded.
#
# Usage:
#   scripts/update-dns.sh <ip>            # dry run
#   scripts/update-dns.sh <ip> --apply    # actually update records
set -euo pipefail

IP="${1:?usage: $0 <ip> [--apply]}"
APPLY="${2:-}"
DOMAIN="kwkaiser.io"

# ensure-kdbx-password checks $SECRETSPEC_KDBX_PASSWORD without a default,
# which trips `set -u` when it's completely unset - relax nounset just for
# the source call.
set +u
source ensure-kdbx-password || exit 1
set -u

CF_API_TOKEN="$(secretspec get K8S_CLOUDFLARE_API_TOKEN --profile default --reason "scripts/update-dns.sh: pointing A records at $IP")"

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=${DOMAIN}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" | jq -r '.result[0].id // empty')

if [ -z "$ZONE_ID" ]; then
  echo "Error: could not find zone for domain ${DOMAIN}" >&2
  exit 1
fi

echo "Zone: $DOMAIN ($ZONE_ID)"
echo "Target IP: $IP"
if [ "$APPLY" = "--apply" ]; then
  echo "Mode: APPLYING changes"
else
  echo "Mode: dry run (pass --apply to actually update records)"
fi
echo

curl -s -X GET "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records?type=A&per_page=100" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  | jq -r '.result[] | "\(.id)|\(.name)|\(.content)"' \
  | while IFS='|' read -r RECORD_ID RECORD_NAME RECORD_IP; do
      if [ "$RECORD_NAME" = "$DOMAIN" ] || [ "$RECORD_NAME" = "www.${DOMAIN}" ] || [ "$RECORD_NAME" = "*.${DOMAIN}" ]; then
        echo "skip        $RECORD_NAME (excluded)"
        continue
      fi

      if [ "$RECORD_IP" = "$IP" ]; then
        echo "ok          $RECORD_NAME already -> $IP"
        continue
      fi

      if [ "$APPLY" != "--apply" ]; then
        echo "would-update $RECORD_NAME: $RECORD_IP -> $IP"
        continue
      fi

      RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
        -H "Authorization: Bearer ${CF_API_TOKEN}" \
        -H "Content-Type: application/json" \
        -d "{\"type\":\"A\",\"name\":\"${RECORD_NAME}\",\"content\":\"${IP}\"}")

      if [ "$(echo "$RESULT" | jq -r '.success')" = "true" ]; then
        echo "updated     $RECORD_NAME: $RECORD_IP -> $IP"
      else
        echo "FAILED      $RECORD_NAME: $(echo "$RESULT" | jq -c '.errors')" >&2
      fi
    done
