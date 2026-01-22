import json
import os
import subprocess
from pathlib import Path
from typing import Dict, Iterable, Optional, Tuple

TERRAFORM_BIN = os.environ.get("TERRAFORM_BIN", "terraform")


class TerraformError(RuntimeError):
    pass


def run(cmd: Iterable[str], workdir: Path, env: Optional[Dict[str, str]] = None) -> subprocess.CompletedProcess:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    return subprocess.run(
        list(cmd),
        cwd=str(workdir),
        env=merged_env,
        capture_output=True,
        text=True,
    )


def terraform_init(workdir: Path, backend: bool = True, backend_config: Optional[Dict[str, str]] = None, env: Optional[Dict[str, str]] = None) -> None:
    args = [TERRAFORM_BIN, "init", "-input=false"]
    if not backend:
        args.append("-backend=false")
    if backend_config:
        for key, value in backend_config.items():
            args.extend(["-backend-config", f"{key}={value}"])
    result = run(args, workdir, env=env)
    if result.returncode != 0:
        raise TerraformError(f"terraform init failed: {result.stderr.strip()}")


def terraform_plan(
    workdir: Path,
    var_file: Path,
    plan_path: str = "plan.tfplan",
    lock: bool = False,
    refresh: bool = False,
    use_cache: bool = False,
    detailed_exitcode: bool = False,
    env: Optional[Dict[str, str]] = None,
) -> subprocess.CompletedProcess:
    plan_file = workdir / plan_path
    if use_cache and plan_file.exists():
        return
    allowed_exit_codes = {0}
    if detailed_exitcode:
        allowed_exit_codes.add(2)
    args = [
        TERRAFORM_BIN,
        "plan",
        "-input=false",
        "-refresh=false" if not refresh else "-refresh=true",
        f"-out={plan_path}",
        f"-var-file={var_file}",
    ]
    if not lock:
        args.append("-lock=false")
    if detailed_exitcode:
        args.append("-detailed-exitcode")
    result = run(args, workdir, env=env)
    if result.returncode not in allowed_exit_codes:
        raise TerraformError(f"terraform plan failed: {result.stderr.strip()}")
    return result


def terraform_show_json(workdir: Path, plan_path: str = "plan.tfplan", env: Optional[Dict[str, str]] = None) -> Dict:
    args = [TERRAFORM_BIN, "show", "-json", plan_path]
    result = run(args, workdir, env=env)
    if result.returncode != 0:
        raise TerraformError(f"terraform show failed: {result.stderr.strip()}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise TerraformError(f"terraform show returned invalid JSON: {exc}") from exc


def terraform_apply(workdir: Path, plan_path: str = "plan.tfplan", auto_approve: bool = True, env: Optional[Dict[str, str]] = None) -> None:
    # When applying a saved plan, -auto-approve is implicit and not needed
    args = [TERRAFORM_BIN, "apply", "-input=false", plan_path]
    result = run(args, workdir, env=env)
    if result.returncode != 0:
        raise TerraformError(f"terraform apply failed: {result.stderr.strip()}")


def load_params(var_file: Path) -> Dict:
    with var_file.open("r", encoding="utf-8") as f:
        return json.load(f)


def should_run(flag_env: str) -> bool:
    return os.environ.get(flag_env, "").lower() in ("1", "true", "yes")


def filter_vars(values: Dict[str, object], allowed_keys: Iterable[str]) -> Dict[str, object]:
    """
    Filter a dict to keys declared in allowed_keys to avoid passing undeclared vars.
    """
    allowed = set(allowed_keys)
    return {k: v for k, v in values.items() if k in allowed}


def build_backend_config_from_env() -> Tuple[Dict[str, str], Dict[str, str]]:
    """
    Build backend config and env inputs from BACKEND_* variables.
    Returns tuple (backend_config, extra_env) to pass into terraform init/plan.
    Raises TerraformError if required values are missing.
    """
    required = {
        "resource_group_name": os.environ.get("BACKEND_RESOURCE_GROUP"),
        "storage_account_name": os.environ.get("BACKEND_STORAGE_ACCOUNT"),
        "container_name": os.environ.get("BACKEND_CONTAINER"),
        "key": os.environ.get("BACKEND_KEY"),
    }
    missing = [name for name, value in required.items() if not value]
    if missing:
        raise TerraformError(f"Missing backend config env vars: {', '.join(missing)}")
    backend_config = {
        "resource_group_name": required["resource_group_name"],
        "storage_account_name": required["storage_account_name"],
        "container_name": required["container_name"],
        "key": required["key"],
    }
    # Provide ARM_* passthrough if present (for azurerm backend)
    extra_env = {k: v for k, v in os.environ.items() if k.startswith("ARM_")}
    return backend_config, extra_env
