# Publisher IaC

Infrastructure-as-code for the publisher control plane (PRD-46) using Terraform. Includes modules, environment roots (dev/ephemeral/prod), and a pytest-based harness for module and env validation.

## Current Deployment (dev)

| Resource | Configuration |
|----------|---------------|
| Region | **westus2** |
| VNet | 4 subnets (bastion, jumphost, private-endpoints, postgres) |
| PostgreSQL | VNet integration (delegated subnet), private endpoint only |
| App Service Plan | P1v3 SKU (RFC-71 §7.2 VNet integration requirement) |
| Storage | Queue + Table + 3 private endpoints (blob, queue, table) |
| Key Vault | Private endpoint only |
| ACR | Private endpoint only |
| DNS | 7 private zones with VNet links |
| Bastion + JumpHost | Sole operational access path |

## Prerequisites
- Terraform >= 1.5
- Python 3 + pytest
- Azure CLI/credentials for remote state + applies (plan-only can run with mocks and `-refresh=false`)
- Access to the RFCs/PRD in `docs/` for policy/state conventions (RFC-57/66/71/80, PRD-46)

## Repository Layout
- `iac/modules/` — Terraform modules (naming, network, dns, kv, storage, acr, postgres, appserviceplan, bastion, vm-jumphost, log-analytics)
- `iac/environments/` — env roots (`dev`, `ephemeral`, `prod`) composed from modules
- `tests/` — pytest harness (unit module wrappers + env-root tests); see `tests/README.md` for detailed usage
- `tests/fixtures/params.dev.tfvars.json` — shared input values for plans/tests
- `tests/expectations/` — module expectation files (resource counts and naming patterns)
- `prompts/` — Codex prompts for orientation/execution
- `docs/prd/PRD-46.md` and `docs/rfc/*.md` — source specs

## State & Backend (RFC-80)
- Remote state containers: `tfstate-nonprod` (dev/ephemeral) and `tfstate-prod` (prod)
- State key format: `publisher/vd-core/<env>/<env_id>/terraform.tfstate`
- Backend env vars expected by tests/E2E runs: `BACKEND_RESOURCE_GROUP`, `BACKEND_STORAGE_ACCOUNT`, `BACKEND_CONTAINER`, `BACKEND_KEY`

## Workflows
### Test Harness (recommended)
Use pytest to run plans; it renders fixtures into temp dirs. See `tests/README.md` for full commands.
- Unit example (plan-only):  
  `RUN_TF_TESTS=true USE_TF_PLAN_CACHE=true python -m pytest tests/unit/test_modules.py -k network`
- E2E example (plan-only):  
  `RUN_TF_E2E=true BACKEND_RESOURCE_GROUP=... BACKEND_STORAGE_ACCOUNT=... BACKEND_CONTAINER=... BACKEND_KEY=... python -m pytest tests/e2e -k dev`
- Opt-in apply (with drift check): add `ENABLE_ACTUAL_DEPLOYMENT=true` and target the desired env paramized test.

### Manual Terraform (advanced)
If you need direct Terraform runs, work inside an env root copy that contains `main.tf` (not the repo root). Provide backend config per RFC-80 and the shared var file:  
```
terraform init -backend-config=...
terraform plan -var-file=tests/fixtures/params.dev.tfvars.json -out plan.tfplan
terraform show -json plan.tfplan
```
Use `-refresh=false` for offline plans; enable `-refresh=true` only when live access is intended.

## Conventions & Constraints
- Follow RFC-71 for naming/tagging/security baselines; RFC-80 for backend/state
- **All PaaS services use private endpoints** with private DNS zones for name resolution
- PostgreSQL uses VNet integration (delegated subnet) - no public endpoint
- App Service Plan requires P1v3 minimum SKU for VNet integration (RFC-71 §7.2)
- GitHub Actions + OIDC for CI/CD (RFC-66)
- Deterministic naming via `iac/modules/naming`

## Helpful Files
- `tests/helpers/terraform.py` — shared helpers for init/plan/apply/backend parsing
- `tests/README.md` — step-by-step test harness guide
- `docs/prd/PRD-46.md` — scope/requirements
- `docs/rfc/RFC-57.md`, `RFC-66.md`, `RFC-71.md`, `RFC-80.md` — architecture, CI/CD, standards, state conventions
