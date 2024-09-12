# bny-base-library — Developer Guide

## What Is a Library Chart?

A library chart (type: library in Chart.yaml) contains only named
templates — it cannot be deployed directly. Consumer charts declare
it as a dependency and call its templates via {{ include }}.

This avoids copying and maintaining identical deployment boilerplate
across 20+ microservice charts.

## Templates Provided

| Template | Description |
|---|---|
| bny-base.deployment | Deployment with security context, anti-affinity, probes |
| bny-base.service | ClusterIP service with Prometheus annotations |
| bny-base.hpa | HPA v2 with CPU + memory and scale behaviors |
| bny-base.vpa | VPA in Off mode (recommendations only) |
| bny-base.pdb | PodDisruptionBudget with minAvailable |
| bny-base.serviceaccount | ServiceAccount with OIDC IAM role annotation |
| bny-base.networkpolicy | Default-deny with explicit allow rules |
| bny-base.configmap | ConfigMap with checksum annotation wiring |
| bny-base.ingress | ALB Ingress with WAF and HTTPS-only |
| bny-base.cronjob | CronJob with identical security context |
| bny-base.labels | Standard label set for all resources |
| bny-base.selectorLabels | Minimal immutable selector labels |

## Creating a New Consumer Chart

```bash
# Create chart directory
mkdir -p charts/my-service/templates

# Chart.yaml — declare library dependency
cat > charts/my-service/Chart.yaml << YAML
apiVersion: v2
name: my-service
version: 1.0.0
dependencies:
  - name: bny-base-library
    version: "0.5.0"
    repository: "file://../bny-base-library"
  - name: bny-rbac
    version: "0.3.0"
    repository: "file://../bny-rbac"
YAML

# templates/deployment.yaml — one line
echo '{{ include "bny-base.deployment" . }}' \
  > charts/my-service/templates/deployment.yaml

echo '{{ include "bny-base.service" . }}' \
  > charts/my-service/templates/service.yaml

echo '{{ include "bny-base.hpa" . }}' \
  > charts/my-service/templates/hpa.yaml

echo '{{ include "bny-base.pdb" . }}' \
  > charts/my-service/templates/pdb.yaml

echo '{{ include "bny-base.networkpolicy" . }}' \
  > charts/my-service/templates/networkpolicy.yaml

# Build deps and lint
helm dependency build charts/my-service/
helm lint charts/my-service/
```

## Required Values

```yaml
appName: my-service          # Used for all resource names
namespace: finance           # Target namespace
team: my-team                # Label and annotation
environment: production      # dev | staging | production

image:
  repository: 123456789.dkr.ecr.us-east-1.amazonaws.com/my-service
  tag: "1.0.0"

resources:
  requests:
    cpu: "100m"
    memory: "128Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"
```
