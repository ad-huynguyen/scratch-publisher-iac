---
notion_page_id: "2e8309d25a8c803aae5eea0e513d456b"
notion_numeric_id: 80
doc_id: "RFC-80"
notion_title: "Publisher Terraform State & Backend Convention"
source: "notion"
pulled_at: "2026-01-16T13:00:00Z"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-129"
---

# Decision

- Separate storage accounts: `tfstate-nonprod` (dev/ephemeral) and `tfstate-prod` (prod).
- State key format: `publisher/<stack>/<env>/<env_id>/terraform.tfstate`.
- Auth via GitHub Actions OIDC (no secrets).
- Identities: `publisher-iac-nonprod` (non-prod), `publisher-iac-prod` (prod only); non-prod identity has zero access to prod state.
- Global Admin provisions backend in Publisher tenant.

# Summary

Defines secure, deterministic Terraform remote-state backend convention for Publisher Core Infrastructure: key naming, backend security, identity/RBAC, lifecycle across dev/ephemeral/prod. Avoids drift through strict key and identity rules.

# Context

Environment types: dev (developer-managed), ephemeral PR (CI-managed per PR), prod (CD on main). GitHub Flow drives lifecycle. Constraints: tight publisher-tenant controls, no developer access to prod state, OIDC auth only.

# Proposal

## 1. Terraform backend location

Backend in Publisher tenant with hard separation:
- `tfstatenonprod` storage account for ephemeral + dev
- `tfstateprod` storage account for prod

## 2. Backend Storage (per RFC-71 with overrides)

- PNA disabled (prefer private access), private endpoints required for Blob, shared key disabled, TLS >= 1.2, Azure AD auth only.
- Diagnostics enabled for audit of read/write/delete.
- Overrides vs RFC-71: Blob versioning enabled, soft delete enabled, container delete retention enabled.

## 3. State key convention

Canonical key: `publisher/<stack>/<env>/<env_id>/terraform.tfstate`
- `<stack>`: allowlist; currently `vd-core`.
- `<env>`: `ephemeral | dev | prod`.
- `<env_id>`: `pr-<PR_NUMBER>` for ephemeral; `<BRANCH_NAME>` for dev; `main` for prod.

Examples:
- `publisher/vd-core/ephemeral/pr-123/terraform.tfstate`
- `publisher/vd-core/dev/some_issue_vd-23/terraform.tfstate`
- `publisher/vd-core/prod/main/terraform.tfstate`

## 4. Backend-config contract

Pipeline inputs at `terraform init` time (modules never hardcode backend):
- Required: `backend_resource_group_name`, `backend_key` (follows convention).
- Derived by convention: `backend_container_name` (`tfstate-prod` for prod else `tfstate-nonprod`); `backend_storage_account_name` mapped per env/container to avoid drift.
- CI/CD and provisioning RFCs reference this RFC for backend config; must not duplicate.

## 5. Identity & RBAC model

OIDC federated workload identities:

| Identity | Scope | Role |
| --- | --- | --- |
| publisher-iac-nonprod | `tfstate-nonprod` storage account | Storage Blob Data Contributor |
| publisher-iac-prod | `tfstate-prod` storage account | Storage Blob Data Contributor |

Pipeline mapping:
- PR/ephemeral CI → `publisher-iac-nonprod`
- Dev deployments → `publisher-iac-nonprod`
- Prod CD → `publisher-iac-prod`

Rules:
- `publisher-iac-nonprod` has zero access to prod state.
- `publisher-iac-prod` never used in PR workflows.
- No CI/CD identity needs subscription Owner/Contributor.
- Human write access not allowed by default; break-glass time-bound only by Global Admin.

# Impact

- Observability: enable storage diagnostics/audit logs for tfstate operations.
- Use GitHub environment protections so `publisher-iac-prod` only used in controlled CD.

# Open Questions

- None.
