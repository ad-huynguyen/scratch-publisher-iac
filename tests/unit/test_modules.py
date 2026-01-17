import os
from pathlib import Path

import pytest

from tests.helpers import terraform as tf

ROOT = Path(__file__).resolve().parents[2]
PARAMS_FILE = ROOT / "tests" / "fixtures" / "params.dev.tfvars.json"
FIXTURES_ROOT = ROOT / "tests" / "unit" / "fixtures"
NAMING_MODULE_DIR = ROOT / "iac" / "modules" / "naming"

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
    assert "format_version" in plan_json
    assert "planned_values" in plan_json
