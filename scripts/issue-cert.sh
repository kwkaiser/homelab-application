#!/usr/bin/env bash
# Issues (or renews) the *.kwkaiser.io wildcard cert via certbot's DNS-01
# challenge against Cloudflare. Needs `certbot` with the dns-cloudflare
# plugin on PATH (this repo's flake.nix devshell provides it) and root,
# since certbot writes to /etc/letsencrypt.
#
# The Cloudflare API token comes from secretspec (K8S_CLOUDFLARE_API_TOKEN)
# rather than a long-lived cloudflare.ini on disk - this script writes one
# to a 600-permissioned tempfile for the duration of the run and removes it
# on exit.
#
# Also writes the resulting fullchain.pem/privkey.pem straight into the
# K8S_NGINX_CERTIFICATE / K8S_NGINX_CERTIFICATE_KEY kdbx entries via
# `secretspec set ... -- "$(...)"` - passing the PEM as an argv value rather
# than through any GUI text field is what keeps its real newlines intact
# (a single-line "Password" edit box will silently flatten them on paste).
#
# After this succeeds, all that's left is: MODE=prod task deploy
set -euo pipefail

# ensure-kdbx-password checks $SECRETSPEC_KDBX_PASSWORD without a default,
# which trips `set -u` when it's completely unset - relax nounset just for
# the source call.
set +u
source ensure-kdbx-password || exit 1
set -u

CF_INI="$(mktemp)"
trap 'rm -f "$CF_INI"' EXIT
chmod 600 "$CF_INI"

printf 'dns_cloudflare_api_token = %s\n' "$(secretspec get K8S_CLOUDFLARE_API_TOKEN)" > "$CF_INI"

sudo certbot certonly \
  --dns-cloudflare \
  --dns-cloudflare-credentials "$CF_INI" \
  -d '*.kwkaiser.io' \
  --preferred-challenges dns-01 \
  --key-type rsa

LIVE_DIR=/etc/letsencrypt/live/kwkaiser.io

echo "Writing new cert into K8S_NGINX_CERTIFICATE..."
secretspec set K8S_NGINX_CERTIFICATE --profile default \
  --reason "task cert: storing newly issued fullchain.pem" \
  -- "$(sudo cat "$LIVE_DIR/fullchain.pem")"

echo "Writing new key into K8S_NGINX_CERTIFICATE_KEY..."
secretspec set K8S_NGINX_CERTIFICATE_KEY --profile default \
  --reason "task cert: storing newly issued privkey.pem" \
  -- "$(sudo cat "$LIVE_DIR/privkey.pem")"

echo "Done. Run 'MODE=prod task deploy' to roll the new cert out."
