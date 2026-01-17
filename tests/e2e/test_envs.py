import os
from pathlib import Path

import pytest

from tests.helpers import terraform as tf

ROOT = Path(__file__).resolve().parents[2]
PARAMS_FILE = ROOT / "tests" / "fixtures" / "params.dev.tfvars.json"

ENV_ROOTS = [
    ROOT / "iac" / "environments" / "dev",
    ROOT / "iac" / "environments" / "ephemeral",
    ROOT / "iac" / "environments" / "prod",
]


@pytest.mark.skipif(
    not tf.should_run("RUN_TF_E2E"),
    reason="Set RUN_TF_E2E=true to execute env-root tests (requires terraform + Azure auth + backend-config).",
)
@pytest.mark.parametrize("env_root", ENV_ROOTS)
def test_env_plan(tmp_path: Path, env_root: Path):
    """
    E2E plan-only validation for environment roots.
    Backend config is expected via env (BACKEND_RESOURCE_GROUP, BACKEND_STORAGE_ACCOUNT, BACKEND_CONTAINER, BACKEND_KEY).
    """
    assert env_root.exists(), f"Missing env root: {env_root}"

    try:
        backend_config, _backend_env = tf.build_backend_config_from_env()
    except tf.TerraformError:
        pytest.skip("Backend config env vars not set; skipping env plan.")

    apply_enabled = tf.should_run("ENABLE_ACTUAL_DEPLOYMENT")

    # Copy env root into temp dir to avoid modifying source.
    workdir = tmp_path / env_root.name
    workdir.mkdir(parents=True, exist_ok=True)
    for file in env_root.glob("*.tf"):
        workdir.joinpath(file.name).write_text(file.read_text(encoding="utf-8"), encoding="utf-8")

    tf.terraform_init(workdir, backend=True, backend_config=backend_config)
    plan_path = "plan.tfplan"
    tf.terraform_plan(
        workdir,
        PARAMS_FILE,
        plan_path=plan_path,
        refresh=False,
        use_cache=tf.should_run("USE_TF_PLAN_CACHE"),
    )
    plan_json = tf.terraform_show_json(workdir, plan_path=plan_path)
    assert "format_version" in plan_json
    assert "planned_values" in plan_json

    if apply_enabled:
        tf.terraform_apply(workdir, plan_path=plan_path)
        drift_result = tf.terraform_plan(
            workdir,
            PARAMS_FILE,
            plan_path=plan_path,
            refresh=True,
            detailed_exitcode=True,
            use_cache=False,
        )
        assert drift_result.returncode in (0, 2)
