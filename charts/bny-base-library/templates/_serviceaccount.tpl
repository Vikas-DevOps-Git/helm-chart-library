{{/*
bny-base.serviceaccount — ServiceAccount with OIDC IAM role annotation
The eks.amazonaws.com/role-arn annotation enables pod identity —
pods can assume an IAM role without static AWS credentials.
*/}}
{{- define "bny-base.serviceaccount" -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ .Values.appName }}-sa
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
  annotations:
    eks.amazonaws.com/role-arn: {{ .Values.iamRoleArn | default "" | quote }}
    {{- if .Values.serviceAccountAnnotations }}
    {{- toYaml .Values.serviceAccountAnnotations | nindent 4 }}
    {{- end }}
automountServiceAccountToken: true
{{- end }}
