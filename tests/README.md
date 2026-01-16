# Terraform Test Harness (Publisher IaC)

This harness mirrors the two-tier model from VD-84 (Bicep) but is Terraform-native: fast plan-only by default, with opt-in apply + drift check.

## Goals
- Deterministic validation of publisher IaC modules and env roots.
- Plan-only defaults; gated apply for real deployments.
- Single source of truth for inputs; reproducible runs; cached plans.

## Non-Goals
- Marketplace/Bicep harness changes.
- Workload/app deployment tests or marketplace UI flows.
- Full CI/CD wiring (can be added later).

## Structure
- `tests/fixtures/params.dev.tfvars.json` — single source of truth (subscriptionId, resourceGroupName, location, module inputs).
- `tests/unit/fixtures/test-<module>/main.tf` — tiny wrappers with mocked deps/locals.
- `tests/helpers/terraform.py` — helpers for init/plan/show/apply, var filtering, caching, RG lifecycle (to be implemented).
- Pytest suites:
  - `tests/unit/test_modules.py` — per-module plan tests.
  - `tests/e2e/test_envs.py` — env-root plan/apply tests (dev/ephemeral/prod).

## Backends
- E2E: RFC-80 remote state (`tfstate-prod/nonprod`, key `publisher/vd-core/<env>/<env_id>/terraform.tfstate`) via `-backend-config`.
- Unit: local backend or `-backend=false` for isolated plans.

## Workflows
### Unit (per module, plan-only)
1) `terraform init -backend=false`
2) `terraform plan -input=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`
3) `terraform show -json plan.tfplan` → save/parse; cache plan outputs per module.
4) Pytest supports `-k module_name` filtering (set `RUN_TF_TESTS=true` to run).

### E2E (env roots)
- Default: plan-only
  - `terraform init -backend-config=...`
  - `terraform plan -input=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`
  - `terraform show -json plan.tfplan` → artifacts.
- Opt-in apply (guarded by `ENABLE_ACTUAL_DEPLOYMENT=true`)
  - `terraform apply plan.tfplan`
  - Post-apply drift check: `terraform plan -input=false -lock=false -detailed-exitcode` (expect no-op).
  - RG lifecycle helper; optional `KEEP_RESOURCE_GROUP` to retain for debugging.
  - Backend config supplied via env when running tests: `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`. Set `RUN_TF_E2E=true` to run.

## Commands (examples)
- Unit: `terraform init -backend=false && terraform plan -input=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`
- E2E plan: `terraform init -backend-config=… && terraform plan -input=false -lock=false -out plan.tfplan -var-file=tests/fixtures/params.dev.tfvars.json`
- E2E apply (gated): `ENABLE_ACTUAL_DEPLOYMENT=true terraform apply plan.tfplan && terraform plan -input=false -lock=false -detailed-exitcode`

## Artifacts & Caching
- Save `plan.tfplan` + `plan.json` (`terraform show -json`) per module/env.
- Cache plan outputs per module to reduce repeat work.
- Save apply logs and post-apply plan JSON for drift checks (when applies run).

## Gating & Flags
- `ENABLE_ACTUAL_DEPLOYMENT=true` required for applies.
- `KEEP_RESOURCE_GROUP` controls cleanup (default keep for debug parity with VD-84).

## TF vs Bicep Notes
- Use `terraform plan`/`show -json` (vs Azure what-if).
- Local backend for unit; RFC-80 remote backend for env roots.
- Filter vars to avoid “undeclared variable” errors.
- Plan caching replaces what-if caching.

## Acceptance Targets (aligned with VD-136)
- Shared params JSON + validator.
- Per-module wrappers + pytest suite (plan-only, cached, artifacts).
- E2E pytest (plan-only by default with RFC-80 backend; artifacts saved).
- Opt-in apply path with drift check; RG lifecycle helper.
- Helpers for init/plan/show and RG management with apply gating.
- This README documents workflow, flags, commands.
