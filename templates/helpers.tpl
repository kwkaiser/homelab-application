{{- define "waitFor" -}}
  - name: {{ .Name }}-init
          image: busybox
          command: ['sh', '-c', 'until nc -z {{ .Name }}.default.svc.cluster.local {{ .Port }}; do echo waiting for {{ .Name }}; sleep 5; done;']
{{- end -}}

{{- define "curlUntilSuccess" -}}
  - name: {{ .Name }}-init
          image: busybox
          command: ['sh', '-c', 'until curl --connect-timeout 5 ifconfig.me; do echo waiting to curl {{ .Name }}; sleep 5; done;']
{{- end -}}