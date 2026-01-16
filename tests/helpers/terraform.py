import json
import os
import subprocess
from pathlib import Path
from typing import Dict, Iterable, Optional

TERRAFORM_BIN = os.environ.get("TERRAFORM_BIN", "terraform")


class TerraformError(RuntimeError):
    pass


def run(cmd: Iterable[str], workdir: Path, env: Optional[Dict[str, str]] = None) -> subprocess.CompletedProcess:
    merged_env = os.environ.copy()
    if env:
        merged_env.update(env)
    result = subprocess.run(
        list(cmd),
        cwd=str(workdir),
        env=merged_env,
        capture_output=True,
        text=True,
    )
    return result


def terraform_init(workdir: Path, backend: bool = True, backend_config: Optional[Dict[str, str]] = None) -> None:
    args = [TERRAFORM_BIN, "init", "-input=false"]
    if not backend:
        args.append("-backend=false")
    if backend_config:
        for key, value in backend_config.items():
            args.extend(["-backend-config", f"{key}={value}"])
    result = run(args, workdir)
    if result.returncode != 0:
        raise TerraformError(f"terraform init failed: {result.stderr.strip()}")


def terraform_plan(
    workdir: Path,
    var_file: Path,
    plan_path: str = "plan.tfplan",
    lock: bool = False,
) -> None:
    args = [
        TERRAFORM_BIN,
        "plan",
        "-input=false",
        f"-out={plan_path}",
        f"-var-file={var_file}",
    ]
    if not lock:
        args.append("-lock=false")
    result = run(args, workdir)
    if result.returncode != 0:
        raise TerraformError(f"terraform plan failed: {result.stderr.strip()}")


def terraform_show_json(workdir: Path, plan_path: str = "plan.tfplan") -> Dict:
    args = [TERRAFORM_BIN, "show", "-json", plan_path]
    result = run(args, workdir)
    if result.returncode != 0:
        raise TerraformError(f"terraform show failed: {result.stderr.strip()}")
    try:
        return json.loads(result.stdout)
    except json.JSONDecodeError as exc:
        raise TerraformError(f"terraform show returned invalid JSON: {exc}") from exc


def load_params(var_file: Path) -> Dict:
    with var_file.open("r", encoding="utf-8") as f:
        return json.load(f)


def should_run(flag_env: str) -> bool:
    return os.environ.get(flag_env, "").lower() in ("1", "true", "yes")
