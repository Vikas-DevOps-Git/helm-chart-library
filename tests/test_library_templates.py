"""
test_library_templates.py — Validates Helm chart template rendering
Uses subprocess to call `helm template` — requires Helm CLI installed.
Tests that all consumer charts render valid YAML for all value files.
"""
import subprocess
import sys
import yaml
import os
import pytest
from pathlib import Path

REPO_ROOT = Path(__file__).parent.parent
CHARTS_DIR = REPO_ROOT / "charts"
CONSUMER_CHARTS = ["payment-api", "notification-service", "transaction-api"]


def helm_template(chart_name: str, *extra_args) -> str:
    """Run helm template and return rendered YAML string."""
    chart_dir = CHARTS_DIR / chart_name
    cmd = [
        "helm", "dependency", "build",
        str(chart_dir),
    ]
    subprocess.run(cmd, capture_output=True, cwd=str(REPO_ROOT))

    cmd = [
        "helm", "template", chart_name,
        str(chart_dir),
    ] + list(extra_args)
    result = subprocess.run(cmd, capture_output=True, text=True, cwd=str(REPO_ROOT))
    if result.returncode != 0:
        raise RuntimeError(f"helm template failed: {result.stderr}")
    return result.stdout


def parse_all_yaml(yaml_string: str) -> list:
    """Parse multi-document YAML string into list of dicts."""
    docs = []
    for doc in yaml.safe_load_all(yaml_string):
        if doc:
            docs.append(doc)
    return docs


def get_resource(docs: list, kind: str, name: str = None) -> dict:
    """Find a resource by kind (and optionally name) in rendered docs."""
    for doc in docs:
        if doc.get("kind") == kind:
            if name is None or doc.get("metadata", {}).get("name") == name:
                return doc
    return {}


# ── Dependency check ──────────────────────────────────────────────────────────
@pytest.fixture(scope="session", autouse=True)
def build_deps():
    """Build chart dependencies before running tests."""
    for chart in CONSUMER_CHARTS:
        subprocess.run(
            ["helm", "dependency", "build", str(CHARTS_DIR / chart)],
            capture_output=True,
            cwd=str(REPO_ROOT),
        )


# ── Lint tests ────────────────────────────────────────────────────────────────
@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_helm_lint_base_values(chart):
    """All consumer charts must pass helm lint with base values."""
    result = subprocess.run(
        ["helm", "lint", str(CHARTS_DIR / chart)],
        capture_output=True, text=True,
        cwd=str(REPO_ROOT),
    )
    assert result.returncode == 0, f"helm lint failed for {chart}:\n{result.stdout}\n{result.stderr}"


@pytest.mark.parametrize("chart", ["payment-api", "notification-service"])
@pytest.mark.parametrize("env", ["dev", "prod"])
def test_helm_lint_env_values(chart, env):
    """Consumer charts must pass lint for dev and prod value overrides."""
    values_file = CHARTS_DIR / chart / f"values-{env}.yaml"
    if not values_file.exists():
        pytest.skip(f"No values-{env}.yaml for {chart}")

    result = subprocess.run(
        ["helm", "lint", str(CHARTS_DIR / chart),
         "-f", str(values_file)],
        capture_output=True, text=True,
        cwd=str(REPO_ROOT),
    )
    assert result.returncode == 0, \
        f"helm lint {env} failed for {chart}:\n{result.stdout}\n{result.stderr}"


# ── Template rendering tests ──────────────────────────────────────────────────
@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_template_renders_deployment(chart):
    """Every consumer chart must render a Deployment resource."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    deployment = get_resource(docs, "Deployment")
    assert deployment, f"No Deployment found in {chart} template output"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_deployment_has_non_root_security_context(chart):
    """All deployments must enforce non-root execution."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep, f"No Deployment in {chart}"
    pod_spec = dep["spec"]["template"]["spec"]
    security_ctx = pod_spec.get("securityContext", {})
    assert security_ctx.get("runAsNonRoot") is True, \
        f"{chart}: runAsNonRoot must be true"
    assert security_ctx.get("runAsUser") == 1000, \
        f"{chart}: runAsUser must be 1000"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_deployment_has_resource_limits(chart):
    """All containers must have resource requests and limits."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep, f"No Deployment in {chart}"
    containers = dep["spec"]["template"]["spec"]["containers"]
    for c in containers:
        resources = c.get("resources", {})
        assert "requests" in resources, \
            f"{chart}/{c['name']}: missing resource requests"
        assert "limits" in resources, \
            f"{chart}/{c['name']}: missing resource limits"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_deployment_has_probes(chart):
    """All containers must have readiness and liveness probes."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep
    containers = dep["spec"]["template"]["spec"]["containers"]
    for c in containers:
        assert "readinessProbe" in c, \
            f"{chart}/{c['name']}: missing readinessProbe"
        assert "livenessProbe" in c, \
            f"{chart}/{c['name']}: missing livenessProbe"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_deployment_rolling_update_no_downtime(chart):
    """Rolling update must have maxUnavailable=0 for zero-downtime deploys."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep
    strategy = dep["spec"].get("strategy", {})
    rolling = strategy.get("rollingUpdate", {})
    assert rolling.get("maxUnavailable") == 0, \
        f"{chart}: maxUnavailable must be 0 for zero-downtime releases"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_hpa_renders(chart):
    """HPA must be rendered for all consumer charts."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    hpa = get_resource(docs, "HorizontalPodAutoscaler")
    assert hpa, f"No HPA found in {chart}"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_pdb_renders(chart):
    """PodDisruptionBudget must be rendered for all consumer charts."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    pdb = get_resource(docs, "PodDisruptionBudget")
    assert pdb, f"No PDB found in {chart}"


@pytest.mark.parametrize("chart", CONSUMER_CHARTS)
def test_network_policy_renders(chart):
    """NetworkPolicy must be rendered for all consumer charts."""
    rendered = helm_template(chart)
    docs = parse_all_yaml(rendered)
    netpol = get_resource(docs, "NetworkPolicy")
    assert netpol, f"No NetworkPolicy found in {chart}"


def test_payment_api_dev_has_single_replica():
    """Dev payment-api must have replicas=1 to save resources."""
    values_file = CHARTS_DIR / "payment-api" / "values-dev.yaml"
    rendered = helm_template("payment-api", "-f", str(values_file))
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep
    assert dep["spec"]["replicas"] == 1, \
        "payment-api dev must have replicas=1"


def test_payment_api_prod_has_min_five_replicas():
    """Prod payment-api must have at least 5 replicas for HA."""
    values_file = CHARTS_DIR / "payment-api" / "values-prod.yaml"
    rendered = helm_template("payment-api", "-f", str(values_file))
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep
    assert dep["spec"]["replicas"] >= 5, \
        "payment-api prod must have replicas >= 5"


def test_transaction_api_requires_on_demand_nodes():
    """Transaction API must have nodeSelector for on-demand (no spot)."""
    rendered = helm_template("transaction-api")
    docs = parse_all_yaml(rendered)
    dep = get_resource(docs, "Deployment")
    assert dep
    node_selector = dep["spec"]["template"]["spec"].get("nodeSelector", {})
    assert node_selector.get("capacity") == "on-demand", \
        "transaction-api must run on on-demand nodes only"
