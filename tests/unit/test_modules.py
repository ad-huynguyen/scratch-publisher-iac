import json
import os
from pathlib import Path

import pytest

from tests.helpers import terraform as tf

ROOT = Path(__file__).resolve().parents[2]
PARAMS_FILE = ROOT / "tests" / "fixtures" / "params.dev.tfvars.json"

# Modules under test (Terraform modules in iac/modules)
MODULES = [
    "acr",
    "appserviceplan",
    "bastion",
    "dns",
    "kv",
    "log-analytics",
    "naming",
    "network",
    "postgres",
    "storage",
    "vm-jumphost",
]


def load_parameters():
    return tf.load_params(PARAMS_FILE)


@pytest.fixture(scope="session")
def params():
    return load_parameters()


@pytest.mark.skipif(
    not tf.should_run("RUN_TF_TESTS"),
    reason="Set RUN_TF_TESTS=true to execute Terraform module plan tests (requires terraform + Azure auth).",
)
@pytest.mark.parametrize("module_name", MODULES)
def test_module_plan(tmp_path: Path, module_name: str, params):
    """
    Plan-only validation for each module. This is a scaffolding test: it writes a tiny wrapper
    that instantiates the module with placeholder values from params.dev.tfvars.json, runs init
    with backend disabled, then runs plan and show -json.

    NOTE: Azure credentials are required if the provider attempts API calls during plan.
    """
    module_dir = ROOT / "iac" / "modules" / module_name
    assert module_dir.exists(), f"Module path missing: {module_dir}"

    # Minimal wrapper that passes through required inputs where possible.
    # This does not try to resolve all dependencies; modules with richer requirements may need
    # additional wiring before enabling RUN_TF_TESTS.
    wrapper = tmp_path / "main.tf"
    wrapper.write_text(
        f"""
        terraform {{
          required_version = ">= 1.5.0"
        }}

        module "{module_name}" {{
          source = "{module_dir.as_posix()}"
        }}
        """,
        encoding="utf-8",
    )

    # Prepare a local backend init to avoid remote state.
    tf.terraform_init(tmp_path, backend=False)

    # For now, pass the shared var file; modules that need extra vars will surface errors during plan.
    # This scaffolding is expected to evolve with concrete module var mappings.
    plan_path = "plan.tfplan"
    tf.terraform_plan(tmp_path, PARAMS_FILE, plan_path=plan_path)

    plan_json = tf.terraform_show_json(tmp_path, plan_path=plan_path)
    assert isinstance(plan_json, dict)
    # Basic sanity: plan JSON should include format_version and planned_values keys.
    assert "format_version" in plan_json
    assert "planned_values" in plan_json
