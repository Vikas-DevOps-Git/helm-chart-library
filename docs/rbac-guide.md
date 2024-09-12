# RBAC Subchart Guide

## Design Principle

Each service gets its own ServiceAccount, Role, and RoleBinding.
The Role is scoped to the minimum Kubernetes API permissions needed.
Application pods generally need only ConfigMap read access.

## What the Subchart Creates

1. ServiceAccount with OIDC IAM role annotation (for AWS access)
2. Role with rules defined in values.yaml
3. RoleBinding connecting SA to Role
4. Optional ClusterRoleBinding (platform services only, never app pods)

## Typical RBAC Rules Per Service Type

```yaml
# Standard application pod — ConfigMap read only
rbac:
  rules:
    - apiGroups: [""]
      resources: ["configmaps"]
      verbs: ["get", "list", "watch"]

# Service that needs to watch pods (monitoring sidecar)
rbac:
  rules:
    - apiGroups: [""]
      resources: ["pods", "pods/log"]
      verbs: ["get", "list", "watch"]

# Platform operator (broad permissions — use sparingly)
rbac:
  clusterRole: "view"
```

## OIDC Pod Identity

The ServiceAccount eks.amazonaws.com/role-arn annotation enables OIDC:
```yaml
iamRoleArn: "arn:aws:iam::123456789012:role/prod-payment-api-pod-role"
```

The IAM role trust policy must allow the ServiceAccount:
```json
{
  "Condition": {
    "StringEquals": {
      "oidc.eks.us-east-1.amazonaws.com/id/CLUSTER_ID:sub":
        "system:serviceaccount:finance:payment-api-sa"
    }
  }
}
```
