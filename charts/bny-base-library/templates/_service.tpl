{{/*
bny-base.service — ClusterIP service with optional headless mode
Includes Prometheus scrape annotations for service monitor discovery.

Optional:
  .Values.service.headless — true creates headless service (clusterIP: None)
  .Values.service.sessionAffinity — ClientIP for sticky sessions
*/}}
{{- define "bny-base.service" -}}
apiVersion: v1
kind: Service
metadata:
  name: {{ .Values.appName }}
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
  annotations:
    prometheus.io/scrape: "true"
    prometheus.io/port: {{ .Values.metricsPort | default .Values.containerPort | default "8080" | quote }}
    prometheus.io/path: {{ .Values.metricsPath | default "/metrics" | quote }}
spec:
  {{- if .Values.service }}
  {{- if .Values.service.headless }}
  clusterIP: None
  {{- end }}
  {{- if .Values.service.sessionAffinity }}
  sessionAffinity: {{ .Values.service.sessionAffinity }}
  {{- end }}
  {{- end }}
  selector:
    {{- include "bny-base.selectorLabels" . | nindent 4 }}
  ports:
    - name: http
      port: {{ .Values.service.port | default 80 }}
      targetPort: {{ .Values.containerPort | default 8080 }}
      protocol: TCP
    {{- if .Values.metricsPort }}
    - name: metrics
      port: {{ .Values.metricsPort | int }}
      targetPort: {{ .Values.metricsPort | int }}
      protocol: TCP
    {{- end }}
  type: ClusterIP
{{- end }}
