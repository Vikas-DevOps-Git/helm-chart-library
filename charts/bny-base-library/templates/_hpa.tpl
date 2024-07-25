{{/*
bny-base.hpa — HPA v2 with CPU and memory metrics
Scale-up: aggressive (max of 4 pods or 100% per minute, 60s stabilization)
Scale-down: conservative (2 pods per 2 min, 300s stabilization)
Prevents thrashing on financial APIs with variable load patterns.
*/}}
{{- define "bny-base.hpa" -}}
{{- if .Values.hpa.enabled | default true }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ .Values.appName }}-hpa
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.appName }}
  minReplicas: {{ .Values.hpa.minReplicas | default 2 }}
  maxReplicas: {{ .Values.hpa.maxReplicas | default 10 }}
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetCPU | default 70 }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.hpa.targetMemory | default 80 }}
    {{- if .Values.hpa.customMetrics }}
    {{- toYaml .Values.hpa.customMetrics | nindent 4 }}
    {{- end }}
  behavior:
    scaleUp:
      stabilizationWindowSeconds: {{ .Values.hpa.scaleUpStabilization | default 60 }}
      policies:
        - type: Pods
          value: {{ .Values.hpa.scaleUpPods | default 4 }}
          periodSeconds: 60
        - type: Percent
          value: 100
          periodSeconds: 60
      selectPolicy: Max
    scaleDown:
      stabilizationWindowSeconds: {{ .Values.hpa.scaleDownStabilization | default 300 }}
      policies:
        - type: Pods
          value: {{ .Values.hpa.scaleDownPods | default 2 }}
          periodSeconds: 120
      selectPolicy: Min
{{- end }}
{{- end }}
