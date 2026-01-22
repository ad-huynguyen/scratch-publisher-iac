import os
import json
from pathlib import Path

import pytest

from tests.helpers import terraform as tf

ROOT = Path(__file__).resolve().parents[2]
PARAMS_FILE = ROOT / "tests" / "fixtures" / "params.dev.tfvars.json"
FIXTURES_ROOT = ROOT / "tests" / "unit" / "fixtures"
NAMING_MODULE_DIR = ROOT / "iac" / "modules" / "naming"
EXPECTATIONS_DIR = ROOT / "tests" / "expectations"

def _load_expectation(module_name: str) -> dict:
    """
    Load expectation from JSON generated from PRD if available; otherwise fall back to built-in defaults.
    """
    from tests.expectations.generate_from_prd import main as generate_expectations

    # Regenerate expectations on each run to stay aligned with PRD.
    generate_expectations()
    exp_file = EXPECTATIONS_DIR / f"{module_name}.json"
    if exp_file.exists():
        return tf.load_params(exp_file)

    # Minimal built-in defaults
    defaults = {
        "network": {
            "counts": {"azurerm_virtual_network": 1, "azurerm_subnet": 4},
            "names": {
                "azurerm_virtual_network": ["vd-*"],
                "azurerm_subnet": [
                    "AzureBastionSubnet",
                    "snet-jumphost",
                    "snet-private-endpoints",
                    "snet-postgres",
                ],
            },
        },
    }
    return defaults.get(module_name)

# (module_name, fixture_rel_path)
MODULE_FIXTURES = [
    ("naming", "test-naming/main.tf"),
    ("network", "test-network/main.tf"),
    ("dns", "test-dns/main.tf"),
    ("kv", "test-kv/main.tf"),
    ("storage", "test-storage/main.tf"),
    ("acr", "test-acr/main.tf"),
    ("postgres", "test-postgres/main.tf"),
    ("appserviceplan", "test-appserviceplan/main.tf"),
    ("bastion", "test-bastion/main.tf"),
    ("vm-jumphost", "test-vm-jumphost/main.tf"),
    ("log-analytics", "test-log-analytics/main.tf"),
]


def load_fixture(template_path: Path, module_dir: Path) -> str:
    text = template_path.read_text(encoding="utf-8")
    rendered = text.replace("__MODULE_DIR__", module_dir.as_posix())
    return rendered.replace("__NAMING_MODULE__", NAMING_MODULE_DIR.as_posix())


def _collect_resources(module_plan: dict) -> list:
    """
    Flatten resource list from planned_values (root_module + nested).
    """
    resources = []
    if "resources" in module_plan:
        resources.extend(module_plan["resources"])
    for nested in module_plan.get("child_modules", []):
        resources.extend(_collect_resources(nested))
    return resources


def _resource_name(res: dict) -> str:
    return res.get("values", {}).get("name", "")


def _debug_dump_resources(module_name: str, resources: list) -> None:
    if os.environ.get("DUMP_TF_RESOURCES", "").lower() not in ("1", "true", "yes"):
        return
    print(f"\n[DEBUG] Planned resources for {module_name}:")
    for res in resources:
        print(f"  - {res.get('type')} {res.get('name')} name={_resource_name(res)} address={res.get('address')}")


def _matches_pattern(name: str, pattern: str) -> bool:
    if pattern.endswith("*"):
        return name.startswith(pattern[:-1])
    return name == pattern


def _maybe_write_plan_json(module_name: str, plan_json: dict) -> None:
    """Optionally write the plan JSON to tests/plan-debug/<module>.plan.json for reviewer visibility."""
    if os.environ.get("DUMP_TF_PLAN_JSON", "").lower() not in ("1", "true", "yes"):
        return
    out_dir = ROOT / "tests" / "plan-debug"
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{module_name}.plan.json"
    out_path.write_text(
        json.dumps(plan_json, indent=2),
        encoding="utf-8",
    )
    print(f"[DEBUG] Wrote plan JSON for {module_name} to {out_path}")


@pytest.mark.skipif(
    not tf.should_run("RUN_TF_TESTS"),
    reason="Set RUN_TF_TESTS=true to execute Terraform module plan tests (requires terraform + Azure auth).",
)
@pytest.mark.parametrize("module_name, fixture_rel", MODULE_FIXTURES)
def test_module_plan(tmp_path: Path, module_name: str, fixture_rel: str):
    module_dir = ROOT / "iac" / "modules" / module_name
    assert module_dir.exists(), f"Module path missing: {module_dir}"

    template_path = FIXTURES_ROOT / fixture_rel
    assert template_path.exists(), f"Fixture missing: {template_path}"

    rendered = load_fixture(template_path, module_dir)
    (tmp_path / "main.tf").write_text(rendered, encoding="utf-8")

    tf.terraform_init(tmp_path, backend=False)
    plan_path = "plan.tfplan"
    tf.terraform_plan(
        tmp_path,
        PARAMS_FILE,
        plan_path=plan_path,
        refresh=False,
        use_cache=tf.should_run("USE_TF_PLAN_CACHE"),
    )
    plan_json = tf.terraform_show_json(tmp_path, plan_path=plan_path)
    _maybe_write_plan_json(module_name, plan_json)
    assert "format_version" in plan_json
    assert "planned_values" in plan_json

    # Sanity-check resources against expectations derived from PRD/RFC.
    expected = _load_expectation(module_name)
    if expected:
        resources = _collect_resources(plan_json["planned_values"]["root_module"])
        _debug_dump_resources(module_name, resources)
        counts = {}
        for res in resources:
            counts[res["type"]] = counts.get(res["type"], 0) + 1
        for rtype, expected_count in expected.get("counts", {}).items():
            assert counts.get(rtype, 0) == expected_count, f"{module_name}: expected {expected_count} {rtype}, found {counts.get(rtype,0)}"
        # Name expectations with optional wildcard suffix.
        for rtype, patterns in expected.get("names", {}).items():
            matched_any = False
            for res in resources:
                if res["type"] != rtype:
                    continue
                name = _resource_name(res)
                # Match by name wildcard or address fallback (useful when name not present in plan).
                if any(_matches_pattern(name, p) for p in patterns) or (
                    name == "" and res.get("address", "").endswith("virtual_network.this")
                ):
                    matched_any = True
                    break
            assert matched_any, f"{module_name}: no resources of type {rtype} satisfied name expectations {patterns}"
