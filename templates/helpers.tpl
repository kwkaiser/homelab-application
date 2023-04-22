{{- define "waitFor" -}}
  - name: {{ .Name }}-init
          image: busybox
          command: ['sh', '-c', 'until nslookup {{ .Name }}.default.svc.cluster.local; do echo waiting for {{ .Name }}; sleep 2; done;']
{{- end -}}