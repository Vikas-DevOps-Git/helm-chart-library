{{/*
bny-base.labels — Standard BNY platform labels
Applied to all resources for consistent selection and monitoring.
*/}}
{{- define "bny-base.labels" -}}
app: {{ .Values.appName }}
app.kubernetes.io/name: {{ .Values.appName }}
app.kubernetes.io/version: {{ .Values.image.tag | default "latest" | quote }}
app.kubernetes.io/managed-by: Helm
app.kubernetes.io/component: {{ .Values.component | default "service" }}
app.kubernetes.io/part-of: {{ .Values.partOf | default "bny-platform" }}
bny.com/team: {{ .Values.team | default "platform" }}
bny.com/environment: {{ .Values.environment | default "production" }}
version: {{ .Values.image.tag | default "latest" | quote }}
{{- end }}

{{/*
bny-base.selectorLabels — Minimal labels for selector (immutable after creation)
*/}}
{{- define "bny-base.selectorLabels" -}}
app: {{ .Values.appName }}
{{- end }}

{{/*
bny-base.fullname — Full resource name with optional release prefix
*/}}
{{- define "bny-base.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- .Values.appName | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{/*
bny-base.chart — Chart name and version for helm.sh/chart label
*/}}
{{- define "bny-base.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}
