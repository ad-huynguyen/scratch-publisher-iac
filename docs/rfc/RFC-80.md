---
notion_page_id: "2e8309d2-5a8c-803a-ae5e-ea0e513d456b"
notion_numeric_id: 80
doc_id: "RFC-80"
notion_title: "Publisher Terraform State & Backend Convention"
source: "notion"
pulled_at: "2026-01-22T14:37:00+07:00"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-136"
---

# Decision
- Separate storage accounts: `tfstate-nonprod` and `tfstate-prod`
- State key: `publisher/<stack>/<env>/<env_id>/terraform.tfstate`
- Auth: GitHub Actions OIDC (no secrets)
- Identities: `publisher-iac-nonprod` (non-prod), `publisher-iac-prod` (prod only)
- Non-prod identity has zero access to prod state
- Global Admin provisions backend in Publisher tenant

---
# Summary
Defines a secure, deterministic Terraform remote-state backend convention for Publisher Core Infrastructure. Establishes the state key naming convention, storage backend security posture, identity and RBAC model, and lifecycle management across developer-managed dev environments, CI-managed ephemeral (PR) environments, and production.

---
# Context
### Environment Model
Publisher uses three environment types:
- **Dev**: Developer-managed environments for local development and testing. Developers can create development environment by branch or have long-running dev environments.
- **Ephemeral (PR)**: CI pipeline-managed environments created automatically when a PR is opened. Used for integration testing before merge. Destroyed on PR close.
- **Prod**: Production environment updated via CD pipeline on merge to main. Protected by strict access controls.

### Deployment Flow (GitHub Flow)
1. Developer creates a feature branch from main.
2. PR is opened → CI pipeline provisions ephemeral environment and runs tests.
3. PR is merged to main → CD pipeline updates production.
4. Ephemeral environment is destroyed on PR close.

### Tech Stack
- **IaC:** Terraform
- **Frontend:** TypeScript/React
- **Backend:** FastAPI on Azure App Service/Containers; Azure durable functions in C#
- **Webhooks/Callbacks:** Azure Functions (Python)
- **Database migrations:** Flyway

### Constraints & Requirements
- One publisher platform; convention must avoid undefined/free-form naming dimensions that cause drift.
- Operational: Publisher tenant is tightly restricted; production-ready provisioning executed by Global Admin. Break-glass only by Global Admin.
- Security: developers/PR pipelines must not be able to modify/delete production state.

---
# Proposal
## 1. Terraform backend location
- Terraform backend lives in the Publisher tenant provisioned and controlled under tight restrictions.
- Maintain hard separation between non-prod and prod state:
  - `tfstate-nonprod` storage account for `ephemeral` + `dev`
  - `tfstate-prod` storage account for `prod`

## 2. Backend Storage
- Storage accounts must follow security settings from RFC-71:
  - Public network access: Disabled (prefer private access)
  - Private endpoints: Required for Blob (and any other used services)
  - Shared key access: Disabled
  - Minimum TLS: 1.2+
  - Access method: Azure AD authentication only (OIDC federated workload identity)
  - Diagnostics: Enabled (read/write/delete operations audited)
- Overrides from RFC-71:
  - Blob versioning: Enabled
  - Soft delete (blob): Enabled
  - Container delete retention: Enabled

## 3. State key convention
- Canonical key format: `publisher/<stack>/<env>/<env_id>/terraform.tfstate`
- Definitions:
  - `<stack>`: Terraform root allowlist (for now only `vd-core`).
  - `<env>`: one of `ephemeral | dev | prod`
  - `<env_id>`:
    - `ephemeral`: `pr-<PR_NUMBER>`
    - `dev`: `<BRANCH_NAME>`
    - `prod`: `main`
- Examples:
  - `publisher/vd-core/ephemeral/pr-123/terraform.tfstate`
  - `publisher/vd-core/dev/some_issue_vd-23/terraform.tfstate`
  - `publisher/vd-core/prod/main/terraform.tfstate`

## 4. Backend-config contract
- Backend configured at `terraform init` time; modules must not hardcode backend details.
- **Required pipeline inputs (minimal):**
  - `backend_resource_group_name` — Resource group containing the tfstate storage account.
  - `backend_key` — Full state file path following the key convention.
- **Derived by convention (do not pass independently):**
  - `backend_container_name` — derived from `backend_key`:
    - if `<env>` == `prod` → `tfstate-prod`
    - else (`dev`/`ephemeral`) → `tfstate-nonprod`
  - `backend_storage_account_name` — derived from environment/container selection (fixed mapping), avoiding mismatched key/container/account.
- Purpose: minimize configuration surface area and prevent inconsistencies (e.g., prod key with non-prod container).
- CI/CD PRD and publisher provisioning RFCs should reference this RFC for backend config rules and must not duplicate backend conventions.

## 5. Identity & RBAC model
- Authentication: GitHub Actions OIDC federation (no long-lived secrets).
- Workload Identities:

| Identity | Scope | Role |
| --- | --- | --- |
| `publisher-iac-nonprod` | `tfstate-nonprod` storage account | Storage Blob Data Contributor |
| `publisher-iac-prod` | `tfstate-prod` storage account | Storage Blob Data Contributor |

- Pipeline-to-Identity Mapping:
  - PR / Ephemeral CI → `publisher-iac-nonprod`
  - Dev deployments → `publisher-iac-nonprod`
  - Prod CD → `publisher-iac-prod`

- Access Rules:
  - `publisher-iac-nonprod` has zero access to `tfstate-prod`
  - `publisher-iac-prod` is never used in PR workflows
  - No CI/CD identity requires Subscription Owner/Contributor

- Human Access:
  - Default: No write access to tfstate storage accounts
  - Break-glass: Time-bound, least-privilege, audited, granted only by Global Admin

---
# Impact
- Enable storage diagnostics/audit logs for tfstate read/write/delete operations.
- Use GitHub environment protections (approvals) to ensure `publisher-iac-prod` is only exercised in controlled CD.

---
# Open Questions
- None
