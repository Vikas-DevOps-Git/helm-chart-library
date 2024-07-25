{{/*
bny-base.deployment — Standard BNY platform deployment template

Enforces:
  - Non-root container execution (runAsUser: 1000)
  - Read-only root filesystem
  - All capabilities dropped
  - Pod anti-affinity (prefer spread across nodes)
  - Prometheus scrape annotations
  - Rolling update with maxUnavailable=0 (zero downtime)
  - Resource requests AND limits (required for HPA)
  - Both readiness and liveness probes
  - topologySpreadConstraints for AZ distribution

Required values:
  .Values.appName, .Values.namespace, .Values.image.repository,
  .Values.image.tag, .Values.resources

Optional values:
  .Values.env (map of env vars), .Values.envFrom (configMap/secret refs),
  .Values.volumes, .Values.volumeMounts, .Values.initContainers,
  .Values.nodeSelector, .Values.tolerations
*/}}
{{- define "bny-base.deployment" -}}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Values.appName }}
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
  annotations:
    deployment.kubernetes.io/revision: "1"
    bny.com/team: {{ .Values.team | default "platform" | quote }}
    bny.com/sox-compliant: "true"
spec:
  replicas: {{ .Values.replicas | default 2 }}
  selector:
    matchLabels:
      app: {{ .Values.appName }}
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        {{- include "bny-base.labels" . | nindent 8 }}
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: {{ .Values.metricsPort | default "8080" | quote }}
        prometheus.io/path: {{ .Values.metricsPath | default "/metrics" | quote }}
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum | trunc 8 | quote }}
    spec:
      serviceAccountName: {{ .Values.appName }}-sa
      automountServiceAccountToken: true
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        runAsGroup: 1000
        fsGroup: 2000
        seccompProfile:
          type: RuntimeDefault
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
            - weight: 100
              podAffinityTerm:
                labelSelector:
                  matchExpressions:
                    - key: app
                      operator: In
                      values:
                        - {{ .Values.appName }}
                topologyKey: kubernetes.io/hostname
        {{- if .Values.nodeAffinity }}
        nodeAffinity:
          {{- toYaml .Values.nodeAffinity | nindent 10 }}
        {{- end }}
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app: {{ .Values.appName }}
      {{- if .Values.tolerations }}
      tolerations:
        {{- toYaml .Values.tolerations | nindent 8 }}
      {{- end }}
      {{- if .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml .Values.nodeSelector | nindent 8 }}
      {{- end }}
      {{- if .Values.initContainers }}
      initContainers:
        {{- toYaml .Values.initContainers | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds | default 30 }}
      containers:
        - name: {{ .Values.appName }}
          image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
          imagePullPolicy: {{ .Values.image.pullPolicy | default "Always" }}
          ports:
            - name: http
              containerPort: {{ .Values.containerPort | default 8080 }}
              protocol: TCP
            {{- if .Values.metricsPort }}
            - name: metrics
              containerPort: {{ .Values.metricsPort | int }}
              protocol: TCP
            {{- end }}
          resources:
            requests:
              cpu:    {{ .Values.resources.requests.cpu    | default "100m" }}
              memory: {{ .Values.resources.requests.memory | default "128Mi" }}
            limits:
              cpu:    {{ .Values.resources.limits.cpu    | default "500m" }}
              memory: {{ .Values.resources.limits.memory | default "512Mi" }}
          readinessProbe:
            httpGet:
              path: {{ .Values.healthCheckPath | default "/health" }}
              port: {{ .Values.containerPort | default 8080 }}
            initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds | default 10 }}
            periodSeconds: {{ .Values.readinessProbe.periodSeconds | default 5 }}
            failureThreshold: {{ .Values.readinessProbe.failureThreshold | default 3 }}
            successThreshold: 1
          livenessProbe:
            httpGet:
              path: {{ .Values.healthCheckPath | default "/health" }}
              port: {{ .Values.containerPort | default 8080 }}
            initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds | default 30 }}
            periodSeconds: {{ .Values.livenessProbe.periodSeconds | default 10 }}
            failureThreshold: {{ .Values.livenessProbe.failureThreshold | default 3 }}
          startupProbe:
            httpGet:
              path: {{ .Values.healthCheckPath | default "/health" }}
              port: {{ .Values.containerPort | default 8080 }}
            initialDelaySeconds: 5
            periodSeconds: 5
            failureThreshold: 30
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: {{ .Values.readOnlyRootFilesystem | default true }}
            capabilities:
              drop: [ALL]
          {{- if .Values.env }}
          env:
            {{- range $key, $val := .Values.env }}
            - name: {{ $key }}
              value: {{ $val | quote }}
            {{- end }}
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: APP_ENV
              value: {{ .Values.environment | default "production" | quote }}
          {{- end }}
          {{- if .Values.envFrom }}
          envFrom:
            {{- toYaml .Values.envFrom | nindent 12 }}
          {{- end }}
          {{- if .Values.volumeMounts }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
            {{- toYaml .Values.volumeMounts | nindent 12 }}
          {{- else }}
          volumeMounts:
            - name: tmp
              mountPath: /tmp
          {{- end }}
      volumes:
        - name: tmp
          emptyDir: {}
        {{- if .Values.volumes }}
        {{- toYaml .Values.volumes | nindent 8 }}
        {{- end }}
{{- end }}
