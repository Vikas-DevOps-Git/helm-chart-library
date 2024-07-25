{{/*
bny-base.networkpolicy — Default-deny with explicit ingress/egress allow rules

Default behavior:
  - Ingress: allow from kube-system (ALB/Ingress controller) and same-app pods
  - Egress: allow DNS (53/UDP), Vault (8200), DB (5432), AWS APIs (443)

Override via:
  .Values.networkPolicy.additionalIngress — list of extra ingress rules
  .Values.networkPolicy.additionalEgress  — list of extra egress rules
*/}}
{{- define "bny-base.networkpolicy" -}}
{{- if .Values.networkPolicy.enabled | default true }}
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {{ .Values.appName }}-netpol
  namespace: {{ .Values.namespace | default "default" }}
  labels:
    {{- include "bny-base.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "bny-base.selectorLabels" . | nindent 6 }}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
        - podSelector:
            matchLabels:
              app: {{ .Values.appName }}
      ports:
        - protocol: TCP
          port: {{ .Values.containerPort | default 8080 }}
    {{- if .Values.networkPolicy.additionalIngress }}
    {{- toYaml .Values.networkPolicy.additionalIngress | nindent 4 }}
    {{- end }}
  egress:
    - ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - ports:
        - port: 443
          protocol: TCP
    - ports:
        - port: 8200
          protocol: TCP
    - ports:
        - port: {{ .Values.dbPort | default 5432 }}
          protocol: TCP
    {{- if .Values.networkPolicy.additionalEgress }}
    {{- toYaml .Values.networkPolicy.additionalEgress | nindent 4 }}
    {{- end }}
{{- end }}
{{- end }}
