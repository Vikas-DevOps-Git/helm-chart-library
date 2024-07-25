{{/*
bny-base.pdb — PodDisruptionBudget
minAvailable ensures pods survive node drains and cluster upgrades.
Default minAvailable=2 combined with minReplicas=3 allows draining one node
while still satisfying the PDB constraint.
*/}}
{{- define "bny-base.pdb" -}}
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: {{ .Values.appName }}-pdb
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
spec:
  {{- if .Values.pdb.minAvailable }}
  minAvailable: {{ .Values.pdb.minAvailable }}
  {{- else if .Values.pdb.maxUnavailable }}
  maxUnavailable: {{ .Values.pdb.maxUnavailable }}
  {{- else }}
  minAvailable: {{ .Values.pdb.minAvailable | default 1 }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "bny-base.selectorLabels" . | nindent 6 }}
{{- end }}
