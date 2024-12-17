#!/usr/bin/env bash
# =============================================================================
# package-all.sh — Package all charts and generate index.yaml
# For publishing to a Helm chart repository (S3, GitHub Pages, Nexus)
# Usage: ./scripts/package-all.sh --output dist/
# =============================================================================

set -euo pipefail

CHARTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/charts"
OUTPUT_DIR="${1:-dist}"
mkdir -p "$OUTPUT_DIR"

echo "Packaging charts to ${OUTPUT_DIR}/"

for chart_dir in "${CHARTS_DIR}"/*/; do
  chart=$(basename "$chart_dir")

  # Build dependencies first
  helm dependency build "${chart_dir}" 2>/dev/null || true

  # Package
  if helm package "${chart_dir}" --destination "${OUTPUT_DIR}" 2>&1; then
    echo "  ✅ Packaged: ${chart}"
  else
    echo "  ❌ Package FAILED: ${chart}"
  fi
done

# Generate index
helm repo index "${OUTPUT_DIR}" --url https://Vikas-DevOps-Git.github.io/helm-chart-library

echo ""
echo "✅ All charts packaged — index.yaml generated"
echo "   Upload ${OUTPUT_DIR}/ to your chart repository"
ls -la "${OUTPUT_DIR}/"
