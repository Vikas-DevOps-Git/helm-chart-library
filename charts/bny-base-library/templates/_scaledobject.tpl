{{/*
bny-base.scaledobject — KEDA ScaledObject for event-driven autoscaling
Replaces HPA when .Values.keda.enabled is true.
Requires KEDA operator: helm install keda kedacore/keda -n keda

Example values.yaml for SQS-based scaling:
  keda:
    enabled: true
    minReplicas: 0
    maxReplicas: 20
    pollingInterval: 30
    cooldownPeriod: 300
    triggers:
      - type: aws-sqs-queue
        metadata:
          queueURL: https://sqs.us-east-1.amazonaws.com/123/my-queue
          queueLength: "10"
          awsRegion: us-east-1
          identityOwner: pod
*/}}
{{- define "bny-base.scaledobject" -}}
{{- if .Values.keda -}}
{{- if .Values.keda.enabled }}
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: {{ .Values.appName }}-scaledobject
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    app: {{ .Values.appName }}
    app.kubernetes.io/name: {{ .Values.appName }}
    app.kubernetes.io/managed-by: Helm
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ .Values.appName }}
  minReplicaCount: {{ .Values.keda.minReplicas | default 1 }}
  maxReplicaCount: {{ .Values.keda.maxReplicas | default 10 }}
  pollingInterval: {{ .Values.keda.pollingInterval | default 30 }}
  cooldownPeriod: {{ .Values.keda.cooldownPeriod | default 300 }}
  triggers:
    {{- toYaml .Values.keda.triggers | nindent 4 }}
{{- end }}
{{- end }}
{{- end }}
