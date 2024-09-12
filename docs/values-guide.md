# Values Reference Guide

## Environment Override Pattern

All consumer charts follow a three-layer values pattern:

```
values.yaml          ← base defaults (used in all envs)
values-dev.yaml      ← dev overrides (minimal resources, latest tag)
values-staging.yaml  ← staging overrides (RC tag, staging-sized resources)
values-prod.yaml     ← prod overrides (full scale, pinned tag)
```

Deploy command:
```bash
helm upgrade --install payment-api charts/payment-api/ \
  -f charts/payment-api/values.yaml \
  -f charts/payment-api/values-prod.yaml \
  -n finance
```

## Key Values Explained

### HPA Configuration
```yaml
hpa:
  enabled: true
  minReplicas: 3       # Must be >= pdb.minAvailable + 1
  maxReplicas: 20      # Set based on load test peak
  targetCPU: 70        # Lower for financial APIs (faster scale-up)
  targetMemory: 80
  scaleUpStabilization: 60    # Seconds before scale-up (aggressive)
  scaleDownStabilization: 300 # Seconds before scale-down (conservative)
```

### PDB and HPA Relationship
minReplicas >= pdb.minAvailable + 1 ensures node drains can proceed.
Example: pdb.minAvailable=2, hpa.minReplicas=3 → one pod can be drained.

### NetworkPolicy additionalIngress
```yaml
networkPolicy:
  additionalIngress:
    - from:
        - podSelector:
            matchLabels:
              app: transaction-api
      ports:
        - protocol: TCP
          port: 8080
```

### VPA Mode
VPA is always deployed in Off mode. Check recommendations:
```bash
kubectl describe vpa payment-api-vpa -n finance
# Look for: Recommendation: Lower Bound / Target / Upper Bound
```
