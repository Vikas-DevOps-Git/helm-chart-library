# helm-chart-library

Production-grade Helm chart library for BNY Mellon platform microservices.
Provides a reusable base library chart, RBAC subchart, and three fully
configured consumer charts covering payment-api, notification-service,
and transaction-api.

Built to eliminate deployment YAML duplication across 20+ microservices
on AWS EKS — reduced per-team onboarding from weeks to days.

---

## Charts

| Chart | Type | Version | Description |
|---|---|---|---|
| `bny-base-library` | library | 0.5.0 | Reusable named templates — Deployment, HPA, VPA, PDB, NetworkPolicy, Ingress, CronJob |
| `bny-rbac` | application | 0.3.0 | ServiceAccount + Role + RoleBinding per service |
| `payment-api` | application | 3.0.0 | Payment gateway API — full production config |
| `notification-service` | application | 1.2.0 | Event notification service |
| `transaction-api` | application | 2.1.0 | High-throughput transaction processor |

---

## Repository Structure

```
helm-chart-library/
├── charts/
│   ├── bny-base-library/          # Library chart — named templates only
│   │   └── templates/
│   │       ├── _deployment.tpl    # Standard deployment + security context
│   │       ├── _helpers.tpl       # Shared label helpers
│   │       ├── _service.tpl       # ClusterIP service
│   │       ├── _hpa.tpl           # HPA v2 with CPU + memory
│   │       ├── _vpa.tpl           # VPA Off mode (recommendations)
│   │       ├── _pdb.tpl           # PodDisruptionBudget
│   │       ├── _serviceaccount.tpl# ServiceAccount + OIDC annotation
│   │       ├── _networkpolicy.tpl # Default-deny + explicit allows
│   │       ├── _configmap.tpl     # ConfigMap with checksum wiring
│   │       ├── _ingress.tpl       # ALB Ingress + WAF
│   │       └── _cronjob.tpl       # CronJob with security context
│   ├── bny-rbac/                  # RBAC subchart
│   │   └── templates/
│   │       ├── serviceaccount.yaml
│   │       ├── role.yaml
│   │       ├── rolebinding.yaml
│   │       └── clusterrolebinding.yaml
│   ├── payment-api/               # Consumer — payment gateway
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   ├── values-staging.yaml
│   │   └── values-prod.yaml
│   ├── notification-service/      # Consumer — event notifications
│   │   ├── values.yaml
│   │   ├── values-dev.yaml
│   │   └── values-prod.yaml
│   └── transaction-api/           # Consumer — transaction processing
│       └── values.yaml
├── scripts/
│   ├── lint-all.sh                # Lint all charts with all value files
│   ├── package-all.sh             # Package charts + generate index.yaml
│   └── deploy.sh                  # Deploy a chart to a target environment
├── tests/
│   └── test_library_templates.py  # pytest — validates template rendering
├── ci/
│   └── ct.yaml                    # chart-testing configuration
├── docs/
│   ├── library-chart-guide.md     # How to create a consumer chart
│   ├── values-guide.md            # Values reference + env override pattern
│   └── rbac-guide.md              # RBAC design and OIDC pod identity
└── .github/workflows/
    └── lint-test.yml               # Lint matrix + pytest + Trivy scan
```

---

## Quick Start

### Prerequisites
```
helm >= 3.14
python >= 3.9
pip install pytest pyyaml
```

### Lint all charts
```bash
./scripts/lint-all.sh
```

### Run template tests
```bash
# Build deps first
for chart in bny-base-library bny-rbac payment-api \
             notification-service transaction-api; do
  helm dependency build charts/${chart}/ 2>/dev/null || true
done

pytest tests/ -v
```

### Deploy a chart
```bash
# Dev
./scripts/deploy.sh payment-api dev finance-dev

# Production (prompts for confirmation)
./scripts/deploy.sh payment-api prod finance
```

---

## How the Library Works

Consumer charts include bny-base-library as a dependency and
call named templates in their own template files:

**charts/payment-api/templates/deployment.yaml:**
```
{{ include "bny-base.deployment" . }}
```

That single line renders the full 100-line deployment manifest
with security context, anti-affinity, probes, and Prometheus annotations.
All values come from payment-api/values.yaml.

---

## Design Decisions

### readOnlyRootFilesystem: true
All containers use read-only root filesystem. Apps write to /tmp
which is mounted as an emptyDir volume. Prevents runtime tampering.

### maxUnavailable: 0
Rolling updates never take a pod down before the replacement is ready.
Critical for zero-downtime financial APIs.

### PDB + HPA Relationship
PDB minAvailable is always set lower than HPA minReplicas:
```yaml
pdb:
  minAvailable: 2   # Guaranteed minimum during disruptions
hpa:
  minReplicas: 3    # 3 - 1 = 2 available during a drain
```

### topologySpreadConstraints
Pods spread across AZs automatically. If one AZ fails, surviving
pods in other AZs continue serving traffic.

### OIDC Pod Identity
ServiceAccount annotations enable IAM role assumption without
static AWS credentials. Zero hardcoded keys in any manifest.

---

## Adding a New Consumer Chart

1. Create chart directory: `charts/my-service/`
2. Add `Chart.yaml` with bny-base-library and bny-rbac dependencies
3. Add `templates/*.yaml` files that call `include "bny-base.*"`
4. Add `values.yaml` with required fields
5. Add `values-dev.yaml` and `values-prod.yaml`
6. Run `helm dependency build charts/my-service/ && helm lint charts/my-service/`

See [docs/library-chart-guide.md](docs/library-chart-guide.md) for full walkthrough.

---

## CI/CD Pipeline

| Trigger | Job | What Runs |
|---|---|---|
| PR to main | lint matrix | helm lint on base + dev + staging + prod values per chart |
| PR to main | test-python | pytest validating deployment security, probes, resources |
| Push/PR | security-scan | Trivy scan on rendered manifests |

---

## SLO Impact

Using this library across 20+ services at BNY Mellon:

| Metric | Before Library | After Library |
|---|---|---|
| New service onboarding | 2–3 weeks (manual YAML) | 1–2 days |
| Security policy compliance | Manual review each chart | Enforced in templates |
| Deployment failures (misconfigured probes) | ~3/month | ~0/month |
| Configuration drift (prod vs staging) | Discovered in incidents | Caught at lint time |

---

## Author

Vikas Dhamija — Senior DevOps Engineer | VP Platform Engineering, BNY Mellon
GitHub: https://github.com/Vikas-DevOps-Git
