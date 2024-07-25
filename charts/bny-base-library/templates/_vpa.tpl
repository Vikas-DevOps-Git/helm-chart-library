{{/*
bny-base.vpa — VPA in Off mode (recommendations only, no auto-restart)
Provides right-sizing data without disrupting production pods.
Review recommendations with: kubectl describe vpa <name> -n <namespace>
*/}}
{{- define "bny-base.vpa" -}}
{{- if .Values.vpa.enabled | default false }}
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: {{ .Values.appName }}-vpa
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.appName }}
  updatePolicy:
    updateMode: "Off"
  resourcePolicy:
    containerPolicies:
      - containerName: {{ .Values.appName }}
        minAllowed:
          cpu: {{ .Values.vpa.minCPU | default "50m" }}
          memory: {{ .Values.vpa.minMemory | default "64Mi" }}
        maxAllowed:
          cpu: {{ .Values.vpa.maxCPU | default "4" }}
          memory: {{ .Values.vpa.maxMemory | default "4Gi" }}
        controlledResources: ["cpu", "memory"]
{{- end }}
{{- end }}
