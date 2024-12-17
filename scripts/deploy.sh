#!/usr/bin/env bash
# =============================================================================
# deploy.sh — Deploy a consumer chart to a target environment
# Usage: ./scripts/deploy.sh payment-api dev finance-dev
#        ./scripts/deploy.sh payment-api prod finance
# =============================================================================

set -euo pipefail

CHART="${1:-payment-api}"
ENV="${2:-dev}"
NAMESPACE="${3:-finance-${ENV}}"
CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts"

echo "=============================================="
echo " Helm Deploy"
echo " Chart    : $CHART"
echo " Env      : $ENV"
echo " Namespace: $NAMESPACE"
echo "=============================================="

CHART_DIR="${CHARTS_DIR}/${CHART}"
VALUES_FILE="${CHART_DIR}/values-${ENV}.yaml"

if [ ! -d "$CHART_DIR" ]; then
  echo "ERROR: Chart not found: $CHART_DIR"
  exit 1
fi

# Build dependencies
helm dependency build "${CHART_DIR}"

# Dry run first
echo ""
echo "Running dry run..."
helm upgrade --install "${CHART}" "${CHART_DIR}" \
  -f "${CHART_DIR}/values.yaml" \
  ${VALUES_FILE:+-f "$VALUES_FILE"} \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --dry-run \
  --debug 2>&1 | tail -20

echo ""
read -p "Proceed with deploy? (yes/no): " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

# Deploy
helm upgrade --install "${CHART}" "${CHART_DIR}" \
  -f "${CHART_DIR}/values.yaml" \
  ${VALUES_FILE:+-f "$VALUES_FILE"} \
  --namespace "${NAMESPACE}" \
  --create-namespace \
  --atomic \
  --timeout 5m \
  --wait

echo ""
echo "✅ Deployed ${CHART} to ${NAMESPACE} (${ENV})"
echo ""
kubectl get pods -n "${NAMESPACE}" -l "app=${CHART}"
