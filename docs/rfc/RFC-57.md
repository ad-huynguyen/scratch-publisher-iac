---
notion_page_id: "2d7309d2-5a8c-8039-b8c1-fc35d570606f"
notion_numeric_id: 57
doc_id: "RFC-57"
notion_title: "Publisher Architecture"
source: "notion"
pulled_at: "2026-01-22T14:37:00+07:00"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-136"
---

# Decision
VibeData operates a publisher-owned control plane in the publisher Azure tenant to manage lifecycle operations for customer-deployed managed applications.

Key decisions:
1. The publisher control plane does not host or process customer data.
2. The publisher control plane maintains a publisher registry as the system of record for all deployed instances.
3. All customer instance lifecycle actions are executed inside the customer tenant via Azure Managed Application permissions.
4. Publisher-initiated actions are always executed using automation runbooks executed using Azure Resource Manager (ARM) with Entra ID authentication and RBAC.
5. All cross-tenant interactions are idempotent and auditable.

---
# Summary
The publisher architecture provides a centralized control plane responsible for managing the provisioning and updates for all VibeData instances deployed via Azure Marketplace. It also provides the framework for Accelerate Data support operations. The publisher (automation and human access) never directly accesses customer workloads or data planes; actions are invoked within each customer’s managed application boundary using delegated permissions, enforcing tenant isolation, zero data exfiltration, and identity-driven control.

---
# Context
- VibeData is delivered as an Azure Managed Application deployed into customer tenants.
- Marketplace offers are immutable; runtime changes are delivered via streaming updates.
- The publisher requires centralized visibility and coordination across tenants without breaking tenant isolation.
- Azure Marketplace and ARM impose specific constraints on cross-tenant operations.

---
# Scope
This RFC covers:
- Publisher control plane services
- Cross-tenant invocation model

This RFC does not cover:
- Customer-side managed application internals (see RFC-42)
- Shared identity architecture (RFC-13)
- Azure Marketplace Notifications (RFC-55)
- Publisher registry (RFC-54)
- Observability and audit model
- Data product logic (dbt, Fabric, dashboards)

---
# Proposal
## 1. Architecture Overview
The publisher operates a centralized control plane with the following core services:
- **Publisher Registry** — Single source of truth for all VibeData instances, their lifecycle state, configuration metadata, and operational status.
- **Update Engine** — Coordinates streaming updates across eligible instances using versioned manifests and publisher-controlled artifacts.
- **SPN Secret Rotation Engine** — Rotates the secret for the SPN with the ACR pull role on the publisher ACR.
- **TLS Certificate Rotation Engine** — Rotates the TLS wildcard certificate in the publisher KV and updates in all the managed apps.
Publisher access is constrained to approved operational workflows executed within the managed application boundary. The publisher does not host customer data or process data on behalf of the managed application.

---
## 2. Publisher Tenant Boundary
All publisher services are deployed in a publisher-owned Azure tenant.

Characteristics:
- No customer data stored
- No customer network access
- No inbound connectivity from customer VNets
- All access mediated by Azure control plane (ARM)

---
## 3. Publisher Control Plane
### 3.1 Responsibilities
The publisher control plane is responsible for:
- Receiving Azure Marketplace managed application notifications
- Maintaining the publisher registry
- Orchestrating streaming updates
- Coordinating HMAC key lifecycle
- Providing audit logs for all actions

### 3.2 Components

| Component | Purpose |
| --- | --- |
| Publisher Registry | RFC-54 |
| Provisioning Engine | Includes the Azure Marketplace notification and processing and is covered in RFC-55. |
| Update Engine | RFC-44 |
| HMAC Rotation Engine | RFC-53 |
| SPN Secret Rotation Engine | Rotates the client secret for the publisher SPNs |
| Automation Runbook | Publisher automations used by the managed services team for day-2 operations for the managed app. |
| Key Vault | Publisher has 2 key vaults. Private - Stores publisher secrets such as HMAC keys and marketplace webhook secrets. Public - Stores the password for the scoped ACR token used by marketplace deployment to copy the images from the publisher ACR to managed application ACR. |
| Publisher ACR | Stores the container and OCI images. Versioning strategy defined in RFC-49. |
| Storage Services | Stores the queue storage and table storage used for Azure Marketplace Notifications, Update Engine, and HMAC Rotation Engine. |

---
## 4. Azure Architecture
- All resources deployed in a dedicated subscription.
- Naming per RFC-71 Section 1.

### 4.1 Networking (Services VNet)
Configuration per RFC-71 Sections 15-17.
- Single Services VNet hosting publisher compute and private endpoints.
- Subnets:
  - `snet-appsvc-integration` — Azure Functions VNet integration (delegated)
  - `snet-private-endpoints` — Private Endpoint NICs
- Private DNS Zones linked to VNet for all private endpoints.

### 4.2 Database
Configuration per RFC-71 Section 5.
- PostgreSQL Flexible Server for publisher registry.
- Roles: `vd_dbo`, `vd_reader` with Entra ID authentication.

### 4.3 Automation Runbook
- Used to trigger publisher-initiated changes in the managed application.
- Publisher functions trigger automation runbooks via ARM.
- Configured to run either with the identity of the human invoking the runbook or with the managed_application_operator identity.
- All actions logged to LAW (via diagnostic settings).

### 4.4 Azure Functions (Private)
Configuration per RFC-71 Section 8.
- Hosts rotation and update engines.
- Private Endpoint for inbound; VNet integration for outbound.
- Functions defined by RFC-53 (HMAC Rotation Engine), RFC-44 (Update Engine), RFC-69 (SPN Rotation Engine), RFC-62 (TLS Rotation Engine).

### 4.5 Azure Functions (Public)
Configuration per RFC-71 Section 8, with override: Public Network Access enabled for trusted Microsoft services.
- RFC-55: Marketplace webhook (Provisioning Engine)

### 4.6 ACR (Public)
Configuration per RFC-71 Section 6.2.
- Hosts container and OCI images for managed app deployment.
- `publisher_acr_pull` SPN has AcrPull role only.

### 4.7 Key Vault (Public)
Configuration per RFC-71 Section 3.2 (Public Key Vault).
- Stores publisher ACR SPN client secret for Marketplace deployment.

### 4.8 Key Vault (Private)
Configuration per RFC-71 Section 3.2 (Private Key Vault).
- Stores HMAC keys and internal publisher secrets.

### 4.9 Storage Services
Configuration per RFC-71 Section 4. Private Endpoints for blob, queue, table.
Engines set message-level TTL per their requirements.

**Queues** defined by:
- RFC-55: Webhook processing
- RFC-53: HMAC rotation
- RFC-62: TLS rotation
- RFC-69: SPN rotation
- RFC-51: Alert processing

**Tables** defined by:
- RFC-55: `processedCallbacks` (webhook deduplication)
- RFC-78: `engineHistory`, `engineDlq` (schema and field requirements)

---
## 5. Observability and Audit
### 5.1 Publisher Observability
Publisher services emit:
- Application logs
- Workflow state
- Errors and retries

Destination:
- Publisher Log Analytics Workspace

### 5.2 Customer Observability
Customer-side actions emit logs to:
- Customer Log Analytics Workspace (LAW)

Publisher access to customer LAW is write-only, used only for operational correlation, and never for querying customer data.

---
## 6. Cross-Tenant Invocation Model
Details are covered in RFC-13.

### 6.1 Identity
The publisher uses two identities:

| Identity | Purpose |
| --- | --- |
| managed_application_operator (SPN) | Publisher automation |
| publisher_acr_pull (SPN) | AcrPull RBAC on the publisher ACR for ARM during managed app deployment |
| vibedata-uami (Customer tenant) | Execution identity inside managed app |

### 6.2 Invocation Flow
1. Publisher Function authenticates using `managed-app-operator` SPN.
2. Calls ARM in the customer tenant.
3. Triggers a managed application runbook.
4. Runbook executes as `vibedata-uami`.
5. All actions occur inside the customer tenant.
6. Results are reported back to publisher registry.

No direct network connectivity is established between tenants.

---
## 7. Provisioning Engine
Provisioning Engine uses the Azure managed application notifications to bootstrap the instance details in the publisher registry (see RFC-55).

### 7.1 Publisher ACR Pull Service Principal (SPN)
- Dedicated multi-tenant Entra ID application is used as the Publisher ACR Pull SPN for Marketplace deployments.
- Permissions:
  - SPN must be granted AcrPull on the publisher ACR scope only.
  - SPN must not have Contributor/Owner on the subscription or resource group.
- Credential handling:
  - SPN client ID embedded in the Marketplace Bicep/ARM template as a parameter.
  - SPN client secret stored in the Publisher Key Vault and referenced by secret name from the ARM template using the Key Vault `reference()` mechanism.
  - Secret must have an explicit expiry and be rotated by the publisher.
- Usage:
  - During Marketplace deployment, ARM resolves the SPN client secret from the Publisher Key Vault and uses it only to authenticate `az acr import` (or `oras cp`) to copy artifacts into the customer ACR.

---
## 8. Update Engine
Publisher-initiated updates are delivered via streaming updates, not new Marketplace offers (details in RFC-44).

---
## 9. Health Orchestration
The publisher never performs health probes directly. The managed services team can use the `update-health` runbook to perform either a full instance health evaluation or a targeted component health.

---
## 10. Out of Scope (MVP)
Out of scope for MVP and to be addressed during hardening:
- Reliability / DR: multi-region failover, defined RPO/RTO targets, and automated disaster recovery testing for the publisher control plane.
- Operational Excellence: formal SLO/SLI definitions, on-call runbooks, incident response automation, and comprehensive operational dashboards beyond basic audit logging.
- Cost / Scale: detailed capacity planning (tenant scale targets, throughput modeling), cost budgets/alerts, and long-term retention policies for logs and history tables beyond default settings.

---
# Impact
- Azure Well-Architected Framework Review
- Azure Marketplace Security Questionnaire (MSQ) mapping
- Azure Marketplace Security Questionnaire (MSQ) — Evidence Index

---
# Open Questions
- None
