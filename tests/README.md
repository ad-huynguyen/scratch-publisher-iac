# Terraform Test Harness (Publisher IaC)

Terraform-native harness for publisher infrastructure. Defaults to plan-only; apply + drift check is opt-in.

## Prerequisites
- Terraform CLI on PATH (>= 1.5).
- Python 3 + pytest.
- Azure credentials only required for apply; plan-only uses mocks and `-refresh=false`.
- Run commands from repo root: `scratch-publisher-iac/`.

## Repo Layout (tests)
- `tests/fixtures/params.dev.tfvars.json` — single source of truth for inputs.
- `tests/unit/fixtures/test-<module>/main.tf` — module wrappers that include the naming module and inline mocks.
- `tests/helpers/terraform.py` — init/plan/show/apply helpers, backend parsing (BACKEND_*), plan cache, var filtering.
- `tests/unit/test_modules.py` — per-module plan tests.
- `tests/e2e/test_envs.py` — env-root tests (dev/ephemeral/prod).

## Unit Tests (per module, plan-only)
Pytest renders fixtures into a temp dir; do **not** run `terraform` in repo root.
- Example (network module):
  ```
  RUN_TF_TESTS=true USE_TF_PLAN_CACHE=true python -m pytest tests/unit/test_modules.py -k network
  ```
- Under the hood: `terraform init -backend=false`, `terraform plan -refresh=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`, `terraform show -json plan.tfplan`.
- `USE_TF_PLAN_CACHE=true` reuses the temp `plan.tfplan` between runs.
- Manual run (if needed): copy a fixture (e.g., `tests/unit/fixtures/test-network/main.tf`) to a work dir, replace `__MODULE_DIR__`/`__NAMING_MODULE__` with real paths, then run `terraform init -backend=false` and `terraform plan ...` **in that work dir**.

## E2E Tests (env roots)
Requires backend config envs (RFC-80): `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`.

Plan-only (default):
```
RUN_TF_E2E=true BACKEND_RESOURCE_GROUP=... BACKEND_STORAGE_ACCOUNT=... BACKEND_CONTAINER=... BACKEND_KEY=... python -m pytest tests/e2e -k dev
```
Swap `-k dev` for `ephemeral` or `prod` to target other env roots. Tests copy `iac/environments/<env>` to a temp dir, then run init/plan/show there.

Opt-in apply + drift:
```
ENABLE_ACTUAL_DEPLOYMENT=true RUN_TF_E2E=true BACKEND_RESOURCE_GROUP=... BACKEND_STORAGE_ACCOUNT=... BACKEND_CONTAINER=... BACKEND_KEY=... python -m pytest tests/e2e/test_envs.py::test_env_plan[ephemeral]
```
Drift check uses `terraform plan -detailed-exitcode -refresh=true` (expect 0/2). You need Azure creds for apply. `USE_TF_PLAN_CACHE=true` reuses `plan.tfplan` in the temp work dir.

## Flags
- `RUN_TF_TESTS=true` — enable unit module plans.
- `RUN_TF_E2E=true` — enable env-root plans.
- `ENABLE_ACTUAL_DEPLOYMENT=true` — allow apply + drift check.
- `USE_TF_PLAN_CACHE=true` — reuse existing `plan.tfplan` if present.
- Backend envs (E2E): `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`.

## Outputs & Artifacts
- `plan.tfplan` + `terraform show -json` per module/env (stored in temp dirs during tests).
- Apply logs and post-apply drift plan JSON when apply is enabled.

## Troubleshooting
- “Terraform initialized in an empty directory” — you ran `terraform` where no `main.tf` exists (e.g., repo root). Use pytest commands above or run terraform inside a work dir that contains a rendered `main.tf`.
- E2E skipped — set all BACKEND_* env vars.
- Apply failures — ensure Azure auth is available; keep `-refresh=false` for plan-only to avoid live lookups.
