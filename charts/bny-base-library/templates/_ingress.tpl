{{/*
bny-base.ingress — ALB Ingress with WAF, HTTPS-only, and health check config
Uses AWS Load Balancer Controller annotations for ALB provisioning.
HTTP redirects to HTTPS with 301. WAF ACL attached when arn is provided.
*/}}
{{- define "bny-base.ingress" -}}
{{- if .Values.ingress.enabled | default false }}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ .Values.appName }}-ingress
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: {{ .Values.ingress.scheme | default "internal" }}
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
    alb.ingress.kubernetes.io/healthcheck-path: {{ .Values.healthCheckPath | default "/health" }}
    alb.ingress.kubernetes.io/healthcheck-interval-seconds: "30"
    alb.ingress.kubernetes.io/healthy-threshold-count: "2"
    alb.ingress.kubernetes.io/unhealthy-threshold-count: "3"
    alb.ingress.kubernetes.io/tags: >-
      Environment={{ .Values.environment | default "production" }},
      Team={{ .Values.team | default "platform" }},
      App={{ .Values.appName }}
    {{- if .Values.ingress.wafAclArn }}
    alb.ingress.kubernetes.io/wafv2-acl-arn: {{ .Values.ingress.wafAclArn }}
    {{- end }}
    {{- if .Values.ingress.certificateArn }}
    alb.ingress.kubernetes.io/certificate-arn: {{ .Values.ingress.certificateArn }}
    {{- end }}
    {{- if .Values.ingress.additionalAnnotations }}
    {{- toYaml .Values.ingress.additionalAnnotations | nindent 4 }}
    {{- end }}
spec:
  ingressClassName: alb
  rules:
    - host: {{ .Values.ingress.host | default (printf "%s.bny-internal.com" .Values.appName) }}
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: {{ .Values.appName }}
                port:
                  number: {{ .Values.service.port | default 80 }}
{{- end }}
{{- end }}
