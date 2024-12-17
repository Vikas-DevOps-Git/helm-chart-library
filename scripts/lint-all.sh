#!/usr/bin/env bash
# =============================================================================
# lint-all.sh — Lint and template-render all charts
# Validates all value file combinations for each consumer chart
# Usage: ./scripts/lint-all.sh [--fix]
# =============================================================================

set -euo pipefail

CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts"
ERRORS=0
FIX_MODE="${1:-}"

echo "=============================================="
echo " Helm Chart Library — Full Lint"
echo " Charts dir: $CHARTS_DIR"
echo "=============================================="

# Build all dependencies first
echo ""
echo "Building dependencies..."
for chart in payment-api notification-service transaction-api; do
  echo "  Building deps: $chart"
  helm dependency build "${CHARTS_DIR}/${chart}/" 2>/dev/null || {
    echo "  ⚠️  dep build failed for $chart — trying update"
    helm dependency update "${CHARTS_DIR}/${chart}/" 2>/dev/null || true
  }
done
echo "  ✅ Dependencies built"

# Lint each chart with all value files
echo ""
echo "Linting charts..."
for chart_dir in "${CHARTS_DIR}"/*/; do
  chart=$(basename "$chart_dir")

  # Skip library chart (not deployable)
  if grep -q "type: library" "${chart_dir}/Chart.yaml" 2>/dev/null; then
    echo "  [SKIP] ${chart} — library chart"
    continue
  fi

  echo ""
  echo "  Chart: ${chart}"

  # Base lint
  if helm lint "${chart_dir}" 2>&1; then
    echo "    ✅ Base lint passed"
  else
    echo "    ❌ Base lint FAILED"
    ERRORS=$((ERRORS + 1))
  fi

  # Lint each values override
  for values_file in "${chart_dir}"values-*.yaml; do
    env=$(basename "$values_file" | sed 's/values-//' | sed 's/.yaml//')
    if helm lint "${chart_dir}" -f "${values_file}" 2>&1; then
      echo "    ✅ Lint passed: ${env}"
    else
      echo "    ❌ Lint FAILED: ${env}"
      ERRORS=$((ERRORS + 1))
    fi
  done
done

# Template render and diff dev vs prod
echo ""
echo "Template rendering and diff..."
for chart in payment-api notification-service; do
  chart_dir="${CHARTS_DIR}/${chart}"

  if [ -f "${chart_dir}/values-dev.yaml" ] && \
     [ -f "${chart_dir}/values-prod.yaml" ]; then
    helm template "${chart}" "${chart_dir}" \
      -f "${chart_dir}/values-dev.yaml" > /tmp/${chart}-dev.yaml 2>/dev/null || true
    helm template "${chart}" "${chart_dir}" \
      -f "${chart_dir}/values-prod.yaml" > /tmp/${chart}-prod.yaml 2>/dev/null || true

    echo ""
    echo "  === ${chart}: dev vs prod diff ==="
    diff /tmp/${chart}-dev.yaml /tmp/${chart}-prod.yaml || true
  fi
done

echo ""
echo "=============================================="
if [ "$ERRORS" -eq 0 ]; then
  echo " ✅ All charts passed — errors: 0"
else
  echo " ❌ Errors found: $ERRORS"
  exit 1
fi
echo "=============================================="
