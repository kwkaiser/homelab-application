{{- define "core.nginx.configs" -}}
{{- $root := .root -}}
{{- range $scope := list "shared" .instance }}
{{- range $path, $_ := $root.Files.Glob (printf "config/nginx/%s/**" $scope) }}
{{ trimPrefix (printf "config/nginx/%s/" $scope) $path }}: {{ $path }}
{{- end }}
{{- end }}
{{- end -}}

{{- define "core.nginx.configmap" -}}
{{- $root := .root -}}
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-{{ .instance }}-configs
data:
{{- range $rel, $path := include "core.nginx.configs" . | fromYaml }}
  {{ regexReplaceAll "\\/" $rel "_" }}: {{ tpl ($root.Files.Get $path) $root | quote }}
{{- end }}
{{- end -}}

{{- define "core.nginx.deployment" -}}
{{- $root := .root -}}
{{- $configs := include "core.nginx.configs" . | fromYaml -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    configmap.reloader.stakater.com/reload: "nginx-{{ .instance }}-configs"
    secret.reloader.stakater.com/reload: "nginx.certificate.key,nginx.certificate,owntracks.basic.auth.user,owntracks.basic.auth.password"
  name: nginx-{{ .instance }}
spec:
  selector:
    matchLabels:
      app: nginx-{{ .instance }}
  replicas: 1
  template:
    metadata:
      labels:
        app: nginx-{{ .instance }}
        app.kubernetes.io/name: nginx-{{ .instance }}
    spec:
      volumes:
        {{- range $name := list "nginx-certificate-key" "nginx-certificate" }}
        - name: {{$name}}
          secret:
            secretName: {{ regexReplaceAll "-" $name "." }}
            items:
              - key: value
                path: value
        {{- end }}

        - name: nginx-configs
          configMap:
            name: nginx-{{ .instance }}-configs
            items:
            {{- range $rel, $_ := $configs }}
              - key: {{ regexReplaceAll "\\/" $rel "_" }}
                path: {{ regexReplaceAll "\\/" $rel "_" }}
            {{- end }}

      containers:
        - name: nginx
          image: {{ $root.Values.nginx.image.repository }}:{{ $root.Values.nginx.image.tag }}
          ports:
            - containerPort: 80
            - containerPort: 443

          env:
            - name: OWNTRACKS_BASIC_AUTH_USER
              valueFrom:
                secretKeyRef:
                  name: owntracks.basic.auth.user
                  key: value

            - name: OWNTRACKS_BASIC_AUTH_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: owntracks.basic.auth.password
                  key: value

          volumeMounts:
            - name: nginx-certificate
              mountPath: /usr/local/openresty/nginx/conf/keys/{{ $root.Values.global.domainName }}.{{ $root.Values.global.tld }}.crt
              subPath: value
              readOnly: true
            - name: nginx-certificate-key
              mountPath: /usr/local/openresty/nginx/conf/keys/{{ $root.Values.global.domainName }}.{{ $root.Values.global.tld }}.key
              subPath: value
              readOnly: true

          {{- range $rel, $_ := $configs }}
            - name: nginx-configs
              mountPath: /usr/local/openresty/nginx/conf/{{ $rel }}
              subPath: {{ regexReplaceAll "\\/" $rel "_" }}
              readOnly: true
          {{- end }}
{{- end -}}
