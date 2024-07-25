{{/*
bny-base.configmap — Application ConfigMap
Stores non-sensitive configuration. Sensitive data goes to Vault.
The deployment template includes a checksum annotation on this ConfigMap
so pods automatically restart when configuration changes.
*/}}
{{- define "bny-base.configmap" -}}
{{- if .Values.config }}
apiVersion: v1
kind: ConfigMap
metadata:
  name: {{ .Values.appName }}-config
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
data:
  APP_ENV: {{ .Values.environment | default "production" | quote }}
  APP_PORT: {{ .Values.containerPort | default 8080 | quote }}
  LOG_LEVEL: {{ .Values.config.logLevel | default "INFO" | quote }}
  {{- if .Values.config.extraData }}
  {{- toYaml .Values.config.extraData | nindent 2 }}
  {{- end }}
{{- end }}
{{- end }}
