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
| Log Analytics | Centralized logging with 30-day retention (Azure minimum) |

## Monitoring & Observability (RFC-71 §19, PRD-46 SR-7)

All resources send diagnostic logs and metrics to a centralized Log Analytics Workspace per environment.

| Resource | Log Categories | Metrics |
|----------|---------------|---------|
| Key Vault | AuditEvent | AllMetrics |
| Storage (Blob) | StorageRead, StorageWrite, StorageDelete | Capacity, Transaction |
| Storage (Queue) | StorageRead, StorageWrite, StorageDelete | Transaction |
| Storage (Table) | StorageRead, StorageWrite, StorageDelete | Transaction |
| ACR | ContainerRegistryRepositoryEvents, ContainerRegistryLoginEvents | AllMetrics |
| PostgreSQL | PostgreSQLLogs | AllMetrics |
| Bastion | BastionAuditLogs | AllMetrics |
| JumpHost VM | — | AllMetrics (platform metrics only) |

**Retention Policy (SR-7):**
- Non-prod (dev/ephemeral): 30 days (Azure minimum)
- Prod: 30 days

> **Note:** JumpHost VM diagnostic settings capture platform metrics only. Guest OS logs require Azure Monitor Agent (AMA) extension, which is out of scope for the current milestone.

## Azure Policy & RBAC (PRD-46 Section 4.4)

### Azure Policy Assignments
Policies are assigned at resource group level in audit mode by default:

| Policy | Requirement | Description |
|--------|-------------|-------------|
| POL-1 | Private Endpoints | Audit Key Vault, Storage, ACR, PostgreSQL for private endpoint configuration |
| POL-2 | Deny Public Access | Audit Key Vault, Storage, ACR for public network access |
| POL-3 | Tagging | Require `environment`, `owner`, `purpose` tags per RFC-71 Section 20 |

### AAD Security Groups
Groups created per environment for access control:

| Group | Control Plane Role | Data Plane Roles |
|-------|-------------------|------------------|
| `publisher-{env}-contributor` | Contributor | Key Vault Secrets Officer, Storage Blob Data Contributor, AcrPush |
| `publisher-{env}-reader` | Reader | Key Vault Secrets User, Storage Blob Data Reader, AcrPull |
| `publisher-{env}-db-operator` | — | PostgreSQL read/write (via AAD auth) |
| `publisher-{env}-db-admin` | — | PostgreSQL DBO (via AAD auth) |

All role assignments are scoped to resource group level for auditability (SR-6).

### Database RBAC (RBAC-7, VD-133)

**AAD Integration:**
- The `publisher-{env}-db-admin` group is configured as a PostgreSQL AAD administrator via Terraform
- Members of this group can authenticate to PostgreSQL using AAD tokens

**Admin Credentials (FR-11):**
- PostgreSQL admin password is stored in Key Vault as `postgres-admin-password`
- Password auth is enabled for bootstrap/emergency access only
- Recommend using AAD authentication for regular operations

**Post-Deployment SQL Configuration:**
Database-level permissions for `db-operator` and `db-admin` groups require SQL execution after deployment:

```sql
-- For db-admin group (DBO permissions)
CREATE ROLE "publisher-{env}-db-admin" WITH LOGIN;
GRANT ALL PRIVILEGES ON DATABASE publisher TO "publisher-{env}-db-admin";

-- For db-operator group (read/write permissions)
CREATE ROLE "publisher-{env}-db-operator" WITH LOGIN;
GRANT CONNECT ON DATABASE publisher TO "publisher-{env}-db-operator";
GRANT USAGE ON SCHEMA public TO "publisher-{env}-db-operator";
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO "publisher-{env}-db-operator";
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO "publisher-{env}-db-operator";
```

> **Note:** PostgreSQL data plane permissions (database roles) cannot be configured via Terraform. The above SQL must be executed by a database administrator after initial deployment.

**Password Rotation (FR-12 - Prod Only):**
Production environments require automated password rotation for the PostgreSQL admin account. Recommended approaches:
1. **Azure Automation Runbook** - Scheduled runbook that rotates password and updates Key Vault secret
2. **Azure Logic App** - Event-driven or scheduled workflow with Key Vault connector
3. **Key Vault Auto-Rotation** - Configure Key Vault secret rotation policy (requires custom rotation function)

Password rotation automation is outside the scope of Terraform IaC and should be implemented as a separate operational component.

## Prerequisites
- Terraform >= 1.5
- Python 3 + pytest
- Azure CLI/credentials for remote state + applies (plan-only can run with mocks and `-refresh=false`)
- Access to the RFCs/PRD in `docs/` for policy/state conventions (RFC-57/66/71/80, PRD-46)

## Repository Layout
- `iac/modules/` — Terraform modules (naming, network, dns, kv, storage, acr, postgres, appserviceplan, bastion, vm-jumphost, log-analytics, policy, rbac)
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
