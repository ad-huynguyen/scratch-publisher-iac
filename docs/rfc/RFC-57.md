---
notion_page_id: "2d7309d25a8c8039b8c1fc35d570606f"
notion_numeric_id: 57
doc_id: "RFC-57"
notion_title: "Publisher Architecture"
source: "notion"
pulled_at: "2026-01-16T13:00:00Z"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-129"
---

# Decision

VibeData operates a publisher-owned control plane in the publisher Azure tenant to manage lifecycle operations for customer-deployed managed applications.

Key decisions:
1. The publisher control plane does not host or process customer data.
2. The publisher control plane maintains a publisher registry as the system of record for all deployed instances.
3. All customer instance lifecycle actions are executed inside the customer tenant via Azure Managed Application permissions.
4. Publisher-initiated actions are always executed using automation runbooks executed using Azure Resource Manager (ARM) with Entra ID authentication and RBAC.
5. All cross-tenant interactions are idempotent and auditable.

# Summary

Centralized publisher control plane manages provisioning and updates for all instances deployed via Azure Marketplace while enforcing tenant isolation and identity-driven control. Publisher never directly accesses customer workloads or data planes; actions are mediated through automation within managed application boundaries.

# Context

- VibeData delivered as Azure Managed Application deployed into customer tenants.
- Marketplace offers are immutable; runtime changes delivered via streaming updates.
- Publisher needs centralized coordination across tenants without breaking isolation.
- Access is constrained by Azure Marketplace and ARM rules.

# Scope

Covered: publisher control plane services and cross-tenant invocation model.  
Not covered: customer-side managed app internals (RFC-42), shared identity architecture (RFC-13), marketplace notifications (RFC-55), publisher registry (RFC-54), observability/audit, data product logic (dbt, Fabric, dashboards).

# Proposal

## 1. Architecture Overview

Components:
- Publisher Registry (RFC-54)
- Provisioning Engine (RFC-55)
- Update Engine (RFC-44)
- HMAC Rotation Engine (RFC-53)
- SPN Secret Rotation Engine
- Automation Runbook set for day-2 operations
- Key Vaults (private/public)
- Publisher ACR
- Storage services (queues/tables per referenced engines)

## 2. Publisher Tenant Boundary

All publisher services in publisher-owned tenant; no customer data; no inbound connectivity from customer VNets; access via ARM only.

## 3. Publisher Control Plane

Responsibilities: marketplace notifications, registry maintenance, streaming updates, HMAC lifecycle, audit logs.  
Key resources and purposes outlined above.

## 4. Azure Architecture

- Dedicated subscription, naming per RFC-71 Section 1.
- Networking: Services VNet with subnets for app service integration and private endpoints; private DNS zones linked.
- Database: PostgreSQL Flexible Server per RFC-71 Section 5, Entra-only auth.
- Automation runbooks triggered via ARM; identities per RFC-13.
- Functions (private) for engines with private endpoints and VNet integration; public function for marketplace webhook with trusted services.
- ACR (public for marketplace), Key Vaults (public for ARM secret reference, private for internal secrets), Storage with private endpoints.

## 5. Observability and Audit

Publisher LAW for control-plane logs; customer LAW write-only for operational correlation (no customer data querying).

## 6. Cross-Tenant Invocation Model (RFC-13)

Identities: managed_application_operator SPN, publisher_acr_pull SPN, vibedata-uami (customer). Flow: publisher function authenticates, calls ARM in customer tenant, triggers runbook executed as vibedata-uami, actions contained in customer tenant, results reported back.

## 7. Provisioning Engine

Marketplace notifications bootstrap registry; uses publisher ACR pull SPN with AcrPull role only; client secret stored in publisher KV; referenced via ARM template.

## 8. Update Engine

Streaming updates, not new offers (RFC-44).

## 9. Health Orchestration

Health via update-health runbook; publisher does not probe directly.

## 10. Out of Scope (MVP)

DR, formal SLO/SLI, cost/capacity planning beyond defaults.

# Open Questions

- None listed.
