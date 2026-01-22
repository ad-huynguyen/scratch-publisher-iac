import json
import os
import shutil
from pathlib import Path
import re

import pytest

from tests.helpers import terraform as tf

ROOT = Path(__file__).resolve().parents[2]
PARAMS_FILE = ROOT / "tests" / "fixtures" / "params.dev.tfvars.json"

ENV_ROOTS = [
    ("dev", ROOT / "iac" / "environments" / "dev"),
    ("ephemeral", ROOT / "iac" / "environments" / "ephemeral"),
    ("prod", ROOT / "iac" / "environments" / "prod"),
]


@pytest.mark.skipif(
    not tf.should_run("RUN_TF_E2E"),
    reason="Set RUN_TF_E2E=true to execute env-root tests (requires terraform + Azure auth + backend-config).",
)
@pytest.mark.parametrize("env_name, env_root", ENV_ROOTS, ids=[name for name, _ in ENV_ROOTS])
def test_env_plan(tmp_path: Path, env_name: str, env_root: Path):
    """
    E2E plan-only validation for environment roots.
    Backend config is expected via env (BACKEND_RESOURCE_GROUP, BACKEND_STORAGE_ACCOUNT, BACKEND_CONTAINER, BACKEND_KEY).
    """
    assert env_root.exists(), f"Missing env root: {env_root}"

    try:
        backend_config, backend_env = tf.build_backend_config_from_env()
    except tf.TerraformError:
        pytest.skip("Backend config env vars not set; skipping env plan.")

    apply_enabled = tf.should_run("ENABLE_ACTUAL_DEPLOYMENT")

    # Copy env root into temp dir to avoid modifying source.
    workdir = tmp_path / env_name
    workdir.mkdir(parents=True, exist_ok=True)
    for file in env_root.glob("*.tf"):
        content = file.read_text(encoding="utf-8")
        # Rewrite module sources to local modules/ directory in the temp workdir.
        content = re.sub(r'source\s*=\s*"..\/..\/modules\/', 'source = "./modules/', content)
        workdir.joinpath(file.name).write_text(content, encoding="utf-8")
    # Ensure modules are available in temp dir (module sources use relative paths).
    modules_src = ROOT / "iac" / "modules"
    modules_dst = workdir / "modules"
    if not modules_dst.exists():
        shutil.copytree(modules_src, modules_dst)

    # Flatten params/metadata into a tfvars file the env root expects.
    params = tf.load_params(PARAMS_FILE)
    metadata = params.get("metadata", {})
    p = params.get("parameters", {})
    flat_vars = {
        "owner": p.get("owner"),
        "subscription_id": metadata.get("subscriptionId") or metadata.get("subscription_id"),
        "tenant_id": p.get("tenant_id"),
        "postgres_admin_login": p.get("postgres_admin_login"),
        "postgres_admin_password": p.get("postgres_admin_password"),
        "postgres_aad_principal_id": p.get("postgres_aad_principal_id"),
        "postgres_aad_principal_name": p.get("postgres_aad_principal_name"),
        "jumphost_admin_username": p.get("jumphost_admin_username"),
        "jumphost_ssh_public_key": p.get("jumphost_ssh_public_key"),
        "system_name": p.get("system_name"),
        "location": metadata.get("location"),
        "vnet_cidr": p.get("vnet_cidr"),
        "subnet_bastion_cidr": p.get("subnet_bastion_cidr"),
        "subnet_jumphost_cidr": p.get("subnet_jumphost_cidr"),
        "subnet_private_endpoints_cidr": p.get("subnet_private_endpoints_cidr"),
        "subnet_postgres_cidr": p.get("subnet_postgres_cidr"),
        "additional_tags": p.get("additional_tags", {}),
    }
    tfvars_path = workdir / "vars.auto.tfvars.json"
    tfvars_path.write_text(json.dumps(flat_vars, indent=2), encoding="utf-8")

    # ARM auth passthrough (prefer existing env, otherwise derive from tfvars).
    extra_env = backend_env.copy()
    if flat_vars.get("subscription_id"):
        extra_env.setdefault("ARM_SUBSCRIPTION_ID", flat_vars["subscription_id"])
    if flat_vars.get("tenant_id"):
        extra_env.setdefault("ARM_TENANT_ID", flat_vars["tenant_id"])

    tf.terraform_init(workdir, backend=True, backend_config=backend_config, env=extra_env)
    plan_path = "plan.tfplan"
    tf.terraform_plan(
        workdir,
        tfvars_path,
        plan_path=plan_path,
        refresh=False,
        use_cache=tf.should_run("USE_TF_PLAN_CACHE"),
        env=extra_env,
    )
    plan_json = tf.terraform_show_json(workdir, plan_path=plan_path, env=extra_env)
    assert "format_version" in plan_json
    assert "planned_values" in plan_json

    if apply_enabled:
        tf.terraform_apply(workdir, plan_path=plan_path, env=extra_env)
        drift_result = tf.terraform_plan(
            workdir,
            tfvars_path,
            plan_path=plan_path,
            refresh=True,
            detailed_exitcode=True,
            use_cache=False,
            env=extra_env,
        )
        assert drift_result.returncode in (0, 2)
