# Terraform Test Harness (Publisher IaC)

Terraform-native harness for publisher infrastructure. Plan-only by default; apply + drift check is opt-in.

## Prerequisites
- Terraform CLI (>= 1.5) on PATH.
- Python 3 + pytest.
- Azure auth available (ARM_* env or Azure CLI). Apply requires permissions; plan still needs a valid subscription/tenant.
- Run commands from repo root `scratch-publisher-iac/`.

## Repo Layout (tests)
- `tests/fixtures/params.dev.tfvars.json` — single source of truth for inputs (metadata + parameters). E2E flattens this into a temp `vars.auto.tfvars.json`.
- `tests/unit/fixtures/test-<module>/main.tf` — module wrappers that include naming and inline mocks.
- `tests/helpers/terraform.py` — init/plan/show/apply helpers, backend parsing (BACKEND_*), plan cache, ARM env passthrough.
- `tests/unit/test_modules.py` — per-module plan tests with expectation comparison.
- `tests/e2e/test_envs.py` — env-root tests (dev/ephemeral/prod).
- `tests/expectations/` — auto-generated expectations from PRD-46 (parsed from the PRD “Expectations” block each run).
- `tests/plan-debug/` — optional plan JSON dumps for reviewer comparison (gitignored).

## Unit Tests (per module, plan-only)
Pytest renders fixtures into a temp dir; do **not** run `terraform` in repo root.
- Example (network module):
  ```
  RUN_TF_TESTS=true USE_TF_PLAN_CACHE=true python -m pytest tests/unit/test_modules.py -k network -vv
  ```
- Under the hood: `terraform init -backend=false`, `terraform plan -refresh=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`, `terraform show -json plan.tfplan`.
- Expectations are auto-generated from PRD-46 each run (`tests/expectations/generate_from_prd.py` parses the PRD Expectations JSON block). No manual edits unless the PRD changes.
- Actual vs expected comparison:
  - Expected: `tests/expectations/<module>.json` (generated each run).
  - Actual: `tests/plan-debug/<module>.plan.json` (written when `DUMP_TF_PLAN_JSON=true`).
  - Optional console dump: `DUMP_TF_RESOURCES=true` prints planned resources.
- `USE_TF_PLAN_CACHE=true` reuses the temp `plan.tfplan` between runs.
- Manual fallback: copy a fixture (e.g., `tests/unit/fixtures/test-network/main.tf`) to a work dir, replace placeholders, then run `terraform init -backend=false` and `terraform plan ...` in that dir.

## E2E Tests (env roots)
Validates full env stacks (dev/ephemeral/prod) with real provider auth.
- Required backend envs (RFC-80): `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`.
- Inputs: harness flattens `tests/fixtures/params.dev.tfvars.json` into `vars.auto.tfvars.json` in a temp workdir; ensure real values (owner, subscriptionId, tenant_id, postgres/jumphost creds, SSH public key, tags).
- Auth passthrough: existing `ARM_*` envs are forwarded; `ARM_SUBSCRIPTION_ID` and `ARM_TENANT_ID` are filled from tfvars if not already set. Azure CLI login works if it matches the subscription.

Plan-only (default):
```
RUN_TF_E2E=true BACKEND_RESOURCE_GROUP=... BACKEND_STORAGE_ACCOUNT=... BACKEND_CONTAINER=... BACKEND_KEY=... python -m pytest tests/e2e/test_envs.py -k dev -vv
```
Swap `-k dev` for `ephemeral` or `prod` to target other env roots. Tests copy `iac/environments/<env>` to a temp dir, rewrite module sources to `./modules`, copy modules locally, then run init/plan/show there.

Opt-in apply + drift:
```
ENABLE_ACTUAL_DEPLOYMENT=true RUN_TF_E2E=true BACKEND_RESOURCE_GROUP=... BACKEND_STORAGE_ACCOUNT=... BACKEND_CONTAINER=... BACKEND_KEY=... python -m pytest tests/e2e/test_envs.py -k dev -vv
```
Drift check uses `terraform plan -detailed-exitcode -refresh=true` (expect 0/2). `USE_TF_PLAN_CACHE=true` reuses `plan.tfplan` in the temp workdir.

## Flags
- `RUN_TF_TESTS=true` — enable unit module plans.
- `RUN_TF_E2E=true` — enable env-root plans.
- `ENABLE_ACTUAL_DEPLOYMENT=true` — allow apply + drift check.
- `USE_TF_PLAN_CACHE=true` — reuse existing `plan.tfplan` if present.
- `DUMP_TF_PLAN_JSON=true` — write plan JSON to `tests/plan-debug/<module>.plan.json`.
- `DUMP_TF_RESOURCES=true` — print planned resources to console.
- Backend envs (E2E): `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`.

## Outputs & Artifacts
- `plan.tfplan` + `terraform show -json` per module/env (stored in temp dirs during tests).
- Apply logs and post-apply drift plan JSON when apply is enabled.
- Optional: plan debug dumps in `tests/plan-debug/` when `DUMP_TF_PLAN_JSON=true`.

## Troubleshooting
- “Terraform initialized in an empty directory” — you ran `terraform` where no `main.tf` exists (e.g., repo root). Use pytest commands above or run terraform inside a rendered work dir.
- E2E skipped — set `RUN_TF_E2E=true` and all BACKEND_* env vars.
- Missing inputs — ensure `tests/fixtures/params.dev.tfvars.json` has real values (subscriptionId, tenant_id, postgres creds, jumphost SSH public key).
- Auth failures — align Azure CLI context or set `ARM_CLIENT_ID`/`ARM_CLIENT_SECRET`/`ARM_TENANT_ID`/`ARM_SUBSCRIPTION_ID` explicitly.
