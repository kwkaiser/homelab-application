#!/usr/bin/env bash
# Stands up (or tears down) a long-running toolbox pod for restoring from
# the Borgbase backup into whatever cluster the current kube context points
# at. Mounts the real helmcharts/borgmatic/config/borgmatic/config.yaml
# unmodified (same file the backup CronJob uses) so there's one source of
# truth for repo/hostnames/paths, with `sleep infinity` instead of
# `borgmatic create` as the entrypoint - you exec in and run
# `borgmatic list` / `extract` / `restore` yourself, service by service,
# across however many sessions the migration takes.
#
# Usage:
#   scripts/borgmatic-restore.sh [up|down]
#
# Then, once up:
#   kubectl exec -it borgmatic-restore -- sh
#   borgmatic list
#   borgmatic extract --archive latest --path bulk/application/authentik --destination /
#   borgmatic restore --archive latest --database postgres --original-hostname authentikdb
#
# Re-running `up` is a no-op if the pod's already there. If you edit
# config.yaml, `down` then `up` again to pick it up - it's mounted via
# subPath, which kubelet doesn't live-update.
set -euo pipefail

ACTION="${1:-up}"
POD_NAME="borgmatic-restore"
CONFIG_FILE="$(cd "$(dirname "$0")/.." && pwd)/helmcharts/borgmatic/config/borgmatic/config.yaml"

if [[ "$ACTION" == "down" ]]; then
  kubectl delete pod "$POD_NAME" --ignore-not-found
  kubectl delete configmap "${POD_NAME}-config" --ignore-not-found
  exit 0
fi

if [[ "$ACTION" != "up" ]]; then
  echo "usage: $0 [up|down]" >&2
  exit 1
fi

kubectl create configmap "${POD_NAME}-config" \
  --from-file=config.yaml="$CONFIG_FILE" \
  --dry-run=client -o yaml | kubectl apply -f -

if kubectl get pod "$POD_NAME" &>/dev/null; then
  echo "${POD_NAME} is already up."
else
  kubectl apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: ${POD_NAME}
spec:
  restartPolicy: Never
  volumes:
    - name: bulk-data
      persistentVolumeClaim:
        claimName: bulk-nfs
    - name: borgmatic-configs
      configMap:
        name: ${POD_NAME}-config
    - name: borgmatic-borgbase-key
      secret:
        secretName: borgmatic.borgbase.key
        items:
          - key: value
            path: value
  containers:
    - name: borgmatic
      image: b3vis/borgmatic:2.0.12
      command: ["/bin/sh", "-c"]
      args:
        - |
          cp /borgmatic-borgbase-key /borgmatic-borgbase-key-2
          echo >> /borgmatic-borgbase-key-2
          chmod 0600 /borgmatic-borgbase-key-2
          sleep infinity
      env:
        # borgmatic 2.0.12 interpolates every variable reference in
        # config.yaml at parse time regardless of which action you run - one
        # used only by the create-only opnsense backup-pull hook still has
        # to be set, or even plain "borgmatic list" fails with "Cannot find
        # variable ... in environment". OPNSENSE_HOST isn't a secret (matches
        # values/prod.yaml's borgmatic.opnsenseHost, unreachable now that
        # the physical hardware is in storage, but the value just needs to
        # exist for parsing - nothing in list/extract/restore connects to it).
        - name: BORG_PASSPHRASE
          valueFrom: { secretKeyRef: { name: backup.passphrase, key: value } }
        - name: MINIFLUX_DB_PASSWORD
          valueFrom: { secretKeyRef: { name: miniflux.db.password, key: value } }
        - name: GITEA_DB_PASSWORD
          valueFrom: { secretKeyRef: { name: gitea.db.password, key: value } }
        - name: IMMICH_DB_PASSWORD
          valueFrom: { secretKeyRef: { name: immich.db.password, key: value } }
        - name: MEALIE_DB_PASSWORD
          valueFrom: { secretKeyRef: { name: mealie.db.password, key: value } }
        - name: AUTHENTIK_DB_PASSWORD
          valueFrom: { secretKeyRef: { name: authentik.db.password, key: value } }
        - name: OPNSENSE_HOST
          value: "192.168.1.1"
        - name: OPNSENSE_API_KEY
          valueFrom: { secretKeyRef: { name: opnsense.api.key, key: value } }
        - name: OPNSENSE_API_SECRET
          valueFrom: { secretKeyRef: { name: opnsense.api.secret, key: value } }
      volumeMounts:
        - { name: bulk-data, mountPath: /bulk }
        - { name: borgmatic-configs, mountPath: /etc/borgmatic/config.yaml, subPath: config.yaml }
        - { name: borgmatic-borgbase-key, mountPath: /borgmatic-borgbase-key, subPath: value, readOnly: true }
EOF
  kubectl wait --for=condition=Ready "pod/${POD_NAME}" --timeout=60s
fi

echo
echo "Exec in with:"
echo "  kubectl exec -it ${POD_NAME} -- sh"
