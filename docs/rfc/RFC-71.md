---
notion_page_id: "2db309d25a8c805e9698f78d6c5438e3"
notion_numeric_id: 71
doc_id: "RFC-71"
notion_title: "**Infrastructure Standards**"
source: "notion"
pulled_at: "2026-01-16T13:00:00Z"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-129"
---

# Decision

All VibeData infrastructure deployments (Publisher and Managed Application) must conform to these standards for consistency, security, and cost optimization.

# Summary

Authoritative configuration standards for Azure resources across Publisher and Managed App. Defines naming, security baselines, diagnostics, and resource-specific settings. Applies unless explicitly overridden.

# Proposal (selected standards)

## 1. Naming Convention

| Component | Pattern | Example |
| --- | --- | --- |
| Resource Group | `vd-rg-{purpose}-{nanoid}` | `vd-rg-publisher-a1b2c3d4` |
| Standard Resource | `vd-{rtype}-{purpose}-{nanoid}` | `vd-kv-private-a1b2c3d4e5f6g7h8` |
| Storage Account | `vdst{purpose}{nanoid}` | `vdstpublishera1b2c3d4` |
| FQDN | `{nanoid}.vibedata.ai` | `x9y8z7w6.vibedata.ai` |

Nanoid: lowercase alphanumerics; 8 chars for RG/storage, 16 for resources; per-resource.  
Overrides: Publisher vs Managed App (e.g., ACR PNA enabled for publisher, public KV).

Resource type identifiers (subset): kv, st, psql, acr, asp, app, func, logic, agw, aks, law, aa, search, ai, vnet, snet, nsg, pip, uami, pe, pdns, nat, rt, disk, nic.

## 2. Core Networking Principles

- Ingress via Application Gateway + WAF only; private endpoints for PaaS; public access disabled.
- Egress via VNet integration; NSG control.

## 3. Key Vault

Standard: Standard SKU, RBAC auth, soft delete 90d, purge protection, PNA disabled, private endpoint required, network ACL default deny, bypass AzureServices.  
Publisher public KV override: PNA enabled, private endpoint not required, ARM template deployment enabled.

## 4. Storage Account

Standard: Standard_LRS, StorageV2, TLS1_2, secure transfer, disable blob public access, disable shared key, PNA disabled, private endpoints for blob/queue/table. Access tier: Cool for artifacts, Hot for operational. Blob containers private, versioning/soft delete disabled (unless overridden).

## 5. PostgreSQL Flexible Server

Standard: version 16, storage auto-grow enabled, PNA disabled, private endpoint required, Entra-only auth, PgBouncer disabled, HA disabled, storage min 32 GB with auto-grow, backups 7d LRS, geo-backup disabled. Roles `vd_dbo`, `vd_reader`. Compute tiers allowed: GP_Standard_D2s_v3 (default), D4s_v3; burstable excluded.

## 6. Azure Container Registry

Standard: Premium, admin disabled, anonymous disabled, zone redundancy disabled, data endpoint disabled, PNA disabled, private endpoint required. Publisher override: PNA enabled with trusted services, PE not required.

## 7. App Service Plan

Linux, zone redundancy disabled; SKU options P1v3 (default), P2v3, P3v3.

## 8. App Service / Functions

Containerized; HTTPS only; TLS 1.2; FTP/remote debugging disabled; Always On enabled; PNA disabled; private endpoint required inbound; VNet integration required outbound.

## 9. AKS

Private cluster; Azure CNI/network policy; OIDC/workload identity enabled; autoscaling disabled; patch channel; defaults: 2 nodes Ubuntu, ephemeral OS disk 128 GB; node sizes D4s_v3/D8s_v3/D16s_v3.

## 10. Application Gateway + WAF

WAF_v2, capacity 1, autoscaling disabled, zone redundancy disabled, HTTP2 enabled, prevention mode OWASP 3.2. Custom rule priority ranges: 100-199 allow customer IPs; 200-299 allow publisher IPs; 1000+ deny all others. SSL policy AppGwSslPolicy20220101S.

## 11. Log Analytics Workspace

SKU PerGB2018; retention 30 days (configurable via runbook); no daily cap, archive, or commitment tier.

## 12. Automation Account

Basic SKU; local auth disabled; PNA enabled; deployed empty; runbooks packaged as OCI in ACR and pulled post-deploy; updated via streaming updates.

## 13. AI Services

AI Search: private endpoint required; PNA disabled; SKUs S1/S2/S3 (no Basic); replicas 1, partitions 1.  
Cognitive Services: kind CognitiveServices, SKU S0, PNA disabled, private endpoint required.

## 14. Logic Apps

Consumption plan; state enabled.

## 15. Virtual Network

DNS servers: Azure default. Address space min /24 max /16; must not overlap common ranges. Subnet sizing: App Gateway /27, AKS /25, App Service integration /28, Private Endpoints /28. Subnet names: snet-appgw, snet-aks, snet-appsvc, snet-private-endpoints.

## 16. Network Security Groups

Default inbound allow VNet/VNet, deny all; outbound allow VNet/VNet. Workload subnet inbound deny Internet; outbound allow Internet. Gateway subnet inbound allow 443 Internet, allow AzureLoadBalancer, allow GatewayManager 65200-65535; outbound allow all. Private endpoint subnet VNet-only.

## 17. Private DNS Zones

Auto-registration disabled; VNet link required. Zones: Key Vault `privatelink.vaultcore.azure.net`, Postgres `privatelink.postgres.database.azure.com`, Storage blob/queue/table, ACR `privatelink.azurecr.io`, App Service `privatelink.azurewebsites.net`, AI Search `privatelink.search.windows.net`, Cognitive `privatelink.cognitiveservices.azure.com`.

## 18. Public IP

Standard SKU, static, regional.

## 19. Observability

Diagnostic settings to LAW required; metrics AllMetrics. Log categories per resource (e.g., KV AuditEvent; Storage Read/Write/Delete; Postgres PostgreSQLLogs; ACR Repository/Login Events; App Service HTTP/Console/App logs; FunctionAppLogs; AKS control plane; App Gateway Access/Performance/WAF; Automation JobLogs/JobStreams).

## 20. Resource Tagging

Tags for non-production: environment (dev, release, prod), owner (ci or username), purpose (ephemeral, dev, release), created (ISO timestamp). Production marketplace deployments not tagged by publisher.

## 21. Security Baseline

No public endpoints; WAF ingress; NSG egress; private DNS; managed identity only; local auth disabled; encryption at rest and in transit; KV soft delete + purge protection.

## 22. Cost Optimization

Start with smallest SKU; scale via runbook; storage redundancy LRS unless HA required; disable autoscaling; share App Service plans where possible.

# Open Questions

- None.
