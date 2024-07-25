{{/*
bny-base.cronjob — CronJob template with identical security context to deployment
Used for batch jobs, data cleanup, report generation, and health checks.
*/}}
{{- define "bny-base.cronjob" -}}
{{- if .Values.cronjob.enabled | default false }}
apiVersion: batch/v1
kind: CronJob
metadata:
  name: {{ .Values.appName }}-{{ .Values.cronjob.name | default "job" }}
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
spec:
  schedule: {{ .Values.cronjob.schedule | default "0 * * * *" | quote }}
  concurrencyPolicy: {{ .Values.cronjob.concurrencyPolicy | default "Forbid" }}
  successfulJobsHistoryLimit: {{ .Values.cronjob.successHistory | default 3 }}
  failedJobsHistoryLimit: {{ .Values.cronjob.failedHistory | default 3 }}
  jobTemplate:
    spec:
      backoffLimit: {{ .Values.cronjob.backoffLimit | default 2 }}
      template:
        metadata:
          labels:
            {{- include "bny-base.labels" . | nindent 12 }}
        spec:
          serviceAccountName: {{ .Values.appName }}-sa
          restartPolicy: {{ .Values.cronjob.restartPolicy | default "OnFailure" }}
          securityContext:
            runAsNonRoot: true
            runAsUser: 1000
            fsGroup: 2000
          containers:
            - name: {{ .Values.appName }}-{{ .Values.cronjob.name | default "job" }}
              image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
              command: {{ toJson .Values.cronjob.command }}
              resources:
                requests:
                  cpu: {{ .Values.resources.requests.cpu | default "50m" }}
                  memory: {{ .Values.resources.requests.memory | default "64Mi" }}
                limits:
                  cpu: {{ .Values.resources.limits.cpu | default "200m" }}
                  memory: {{ .Values.resources.limits.memory | default "256Mi" }}
              securityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                capabilities:
                  drop: [ALL]
{{- end }}
{{- end }}
