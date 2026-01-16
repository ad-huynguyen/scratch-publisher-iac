---
notion_page_id: "2e6309d25a8c80a19cc6dbae6b781909"
notion_numeric_id: 46
doc_id: "PRD-46"
notion_title: "Publisher Core Infrastructure and CICD"
source: "notion"
pulled_at: "2026-01-16T13:00:00Z"
type: "PRD"
root_prd_numeric_id: 46
linear_issue_id: "VD-129"
---

# 1. Objective

Enable deterministic, repeatable provisioning of the publisher baseline infrastructure across all environments (production, development, ephemeral) with automated validation of changes before production deployment. This PRD establishes the foundation for secure, private-access publisher infrastructure. It excludes applications, workloads, and software distribution surfaces (public-facing resources).

# 2. Success Metrics

| Metric | Target |
| --- | --- |
| New environment provisioning time | < 30 minutes |
| Environment configuration drift | Zero unplanned drift in production |
| PR validation coverage | 100% of infrastructure PRs validated before merge |
| Production deployment success rate | > 99% |
| Mean time to restore environment | < 1 hr |

# 3. Scope

## 3.1 In-Scope

**Infrastructure Components (all environments):**

| Domain | Components | Constraints |
| --- | --- | --- |
| Network | Virtual network with subnets for bastion, jumphost, and private endpoints | All PaaS connectivity via private endpoints |
| Storage | Storage account with queue and table services | Private access only |
| Database | PostgreSQL instance (registry database) | Private connectivity only |
| Secrets | Key Vault | Private endpoint required; no public ingress |
| Container Registry | Azure Container Registry | Private endpoint required; no public network access |
| Compute | App Service Plan (plan only; no applications) |  |
| Operational Access | Bastion and JumpHost VM | JumpHost is the sole operational access path |
| Observability | Log Analytics Workspace | Shared per environment; all resources send diagnostics to this workspace |

**CI/CD Capabilities:**
- Automated validation of infrastructure changes on pull requests
- Ephemeral environment lifecycle management for PR validation
- Gated promotion of validated changes to production
- Scheduled drift detection with reporting

## 3.2 Out-of-Scope

- Application deployments (App Services, Functions, container workloads)
- Software distribution infrastructure (public Key Vault, public ACR)
- Marketplace managed application manifests

# 4. Requirements

## 4.0 Summary of workflow by environment

| Environment | Plan | Apply | Approval Required? |
| --- | --- | --- | --- |
| Ephemeral (PR validation) | Auto | Auto | No |
| Dev | Auto | Auto | No |
| Prod | Auto | Gated | Yes |

## 4.1 Functional Requirements

| ID | Requirement |
| --- | --- |
| FR-1 | The system must provision exactly the infrastructure components listed in Section 3.1 for any environment. |
| FR-2 | Infrastructure provisioning must be idempotent—repeated executions with identical inputs must produce no unintended changes. |
| FR-3 | All environments (production, development, ephemeral) must use the same infrastructure definition with environment-specific parameters. |
| FR-4 | Pull requests must be validated against an isolated ephemeral environment before merge eligibility. |
| FR-5 | Ephemeral environments must be automatically created when a PR is opened and destroyed when the PR is closed. |
| FR-6 | Ephemeral environment names must be deterministic and collision-free across concurrent PRs. |
| FR-7 | Production deployments must be gated and require explicit approval before execution. |
| FR-8 | Production changes must include post-deployment verification confirming resources exist and configuration is correct. |
| FR-9 | Build artifacts must be traceable to their source commit and associated PR. |
| FR-10 | Artifact promotion to production must only occur after PR approval and merge. |
| FR-11 | All environments: Provision an internal Postgres admin account with the password in the KV for the environment. |
| FR-12 | Prod environment: There should be a mechanism to rotate the password for internal Postgres admin account. |
| FR-13 | Private DNS zones must be provisioned for each PaaS service with private endpoints. VNet links must be configured to enable name resolution within the virtual network. |
| FR-14 | Ephemeral PR validation must execute a full apply (not plan-only) to validate infrastructure provisioning. Plan output must be included in CI/CD artifacts for review. |
| FR-15 | Each environment must provision a Log Analytics Workspace for centralized log collection. |
| FR-16 | All in-scope resources (Key Vault, Storage, ACR, PostgreSQL, Bastion, JumpHost, VNet) must have diagnostic settings configured to send logs to the environment's Log Analytics Workspace. |

## 4.2 Security Requirements

| ID | Requirement |
| --- | --- |
| SR-1 | CI/CD pipelines must authenticate using managed identity (Azure) or short-lived, automatically rotated tokens; no long-lived secrets. |
| SR-2 | Access control must follow least-privilege principles with distinct permission sets for pipeline automation, human administrators, and runtime workloads. |
| SR-3 | Pipeline identities must not have standing permissions to modify access controls during normal operation. |
| SR-4 | All in-scope resources must enforce private-only connectivity—no public ingress required for data plane operations. |
| SR-5 | Private endpoints must exist for Key Vault, ACR, Storage, and PostgreSQL. |
| SR-6 | Access control assignments must be auditable and managed declaratively. |
| SR-7 | Log Analytics Workspace must retain logs for a minimum of 30 days for prod and 7 days for other environments. |

## 4.3 Operational Requirements

| ID | Requirement |
| --- | --- |
| OR-1 | Infrastructure must be managed declaratively with full state tracking. |
| OR-2 | Configuration drift in production must be detected automatically on a recurring schedule (minimum daily). |
| OR-3 | Drift detection must produce a report without automatically remediating. |
| OR-4 | Every CI/CD execution must produce auditable artifacts including: change plan, execution logs, and validation results. |
| OR-5 | Artifacts must be retained for a minimum of 14 days. |
| OR-6 | CI/CD failures must not leave orphaned resources; cleanup must execute even when validation fails. |
| OR-7 | Existing environments must be recoverable to a known-good state on demand. |
| OR-8 | Administrator access to environment resources must be via Bastion → JumpHost. Direct access to PaaS data planes from outside the virtual network must not be permitted. |
| OR-9 | Terraform state files must be stored using the key convention `publisher/<stack>/<env>/<env_id>/terraform.tfstate` per RFC-80. |

## 4.4 Policy and RBAC Requirements

**Azure Control Plane RBAC**

| ID | Requirement |
| --- | --- |
| RBAC-1 | Each environment type (prod, dev, ephemeral) must have dedicated AAD security groups for access control. Production: `publisher-<env>-contributor`, `publisher-<env>-reader`, `publisher-<env>-db-operator`, `publisher-<env>-db-admin`. |
| RBAC-2 | Production: create AAD groups `publisher-prod-contributor`, `publisher-prod-reader`, `publisher-prod-db-operator`, `publisher-prod-db-admin`. |
| RBAC-3 | Dev / Ephemeral: create AAD groups `publisher-dev-contributor`, `publisher-dev-reader`, `publisher-dev-db-operator`, `publisher-dev-db-admin`. |
| RBAC-4 | Role assignments must be scoped to the resource group level. |

**Data Plane RBAC**

| ID | Requirement |
| --- | --- |
| RBAC-5 | `publisher-<env>-contributor` groups must be assigned Contributor role on the resource group; `publisher-<env>-reader` groups assigned Reader on the resource group. |
| RBAC-6 | `publisher-<env>-contributor` data plane roles: Key Vault Secrets Officer, Storage Blob Data Contributor, ACR Push, read/write. `publisher-<env>-reader` data plane roles: Key Vault Secrets User, Storage Blob Data Reader, ACR Pull. |
| RBAC-7 | `publisher-<env>-db-operator` should have read/write permission on PG; `publisher-<env>-db-admin` should have DBO permission on PG. |

**Policy Requirement**

| ID | Requirement |
| --- | --- |
| POL-1 | Azure Policy must enforce private endpoint requirements for all PaaS resources (Key Vault, Storage, ACR, PostgreSQL). |
| POL-2 | Azure Policy must deny public network access on all in-scope resources. |
| POL-3 | Azure Policy must enforce tagging requirements per RFC-71. |

## 4.5 Constraints

| ID | Constraint |
| --- | --- |
| C-1 | Infrastructure definitions must comply with RFC-71 (Infrastructure Standards) for naming, tagging, and security baseline. |
| C-2 | CI/CD patterns must align with RFC-66 (Engineering CI/CD). |
| C-3 | Architecture must conform to RFC-57 (Publisher Architecture). |
| C-4 | State management must follow RFC-80 (Publisher Terraform State & Backend Convention). |
| C-5 | Deployment parameters must follow RFC-79 (Publisher Deployment Parameters) for environment-specific configuration. |
| C-6 | App Service plan only; no applications deployed as part of this PRD. |

# 5. Acceptance Criteria

### Infrastructure
- [ ] All components in Section 3.1 are provisioned correctly for a new environment.
- [ ] Provisioning the same environment twice produces no unexpected changes.
- [ ] Private DNS zones exist for Key Vault, Storage, ACR, and PostgreSQL.
- [ ] VNet links are configured for all private DNS zones.
- [ ] Key Vault, ACR, Storage, and PostgreSQL have private endpoints and no public ingress.
- [ ] Log Analytics Workspace exists for each environment.
- [ ] All in-scope resources have diagnostic settings sending logs to the workspace.
- [ ] Log retention policy is configured per requirements.

### Access Control
- [ ] Pipeline identity can deploy infrastructure without ability to modify access controls.
- [ ] Administrator identity can operate resources via Bastion → JumpHost.
- [ ] Access control assignments are documented and auditable.
- [ ] AAD groups `publisher-<env>-contributor` and `publisher-<env>-reader` exist for each environment.
- [ ] AAD groups `publisher-<env>-db-operator` and `publisher-<env>-db-admin` exist for each environment.
- [ ] Contributor groups have Contributor role + data plane write roles (Key Vault Secrets Officer, Storage Blob Data Contributor, ACR Push).
- [ ] Reader groups have Reader role + data plane read roles (Key Vault Secrets User, Storage Blob Data Reader, ACR Pull).
- [ ] All role assignments are scoped to resource group level (no subscription-level assignments).
- [ ] Administrator access is only possible via Bastion → JumpHost path.

### Policy
- [ ] Azure Policy denying public network access is assigned and enforcing.
- [ ] Azure Policy enforcing private endpoints is assigned and enforcing.
- [ ] Azure Policy enforcing tagging standards is assigned and enforcing.

### CI/CD
- [ ] Opening a PR triggers automated validation.
- [ ] Validation runs against an isolated ephemeral environment.
- [ ] Closing a PR (merge or reject) destroys the ephemeral environment.
- [ ] Ephemeral cleanup executes even when validation fails.
- [ ] Merging to main triggers production deployment with approval gate.
- [ ] Production deployment includes post-apply verification.
- [ ] All CI/CD runs produce required artifacts (plan, logs, results).
- [ ] No long-lived credentials are stored in the CI/CD system.

### Drift Detection
- [ ] State files are stored at `publisher/<stack>/<env>/<env_id>/terraform.tfstate`.
- [ ] Scheduled drift detection runs at least daily.
- [ ] Drift report is generated and accessible without auto-remediation.

# 6. Dependencies

| Dependency | Type | Notes |
| --- | --- | --- |
| RFC-66 | Input | Defines CI/CD patterns and reusable components |
| RFC-57 | Input | Publisher environment architecture context |
| RFC-71 | Input | Naming, tagging, and security baseline |
| RFC-80 | Input | State management conventions |

# 7. Open Questions

- None

# 8. References

- None
