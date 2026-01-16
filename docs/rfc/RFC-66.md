---
notion_page_id: "2d9309d25a8c8046b2dfff34ea740661"
notion_numeric_id: 66
doc_id: "RFC-66"
notion_title: "Engineering CI/CD"
source: "notion"
pulled_at: "2026-01-16T13:00:00Z"
type: "RFC"
root_prd_numeric_id: 46
linear_issue_id: "VD-129"
---

# Decision

GitHub is the single platform for source control, CI/CD (GitHub Actions), and artifact storage (GHCR + Releases). GitHub Flow (main + feature branches) for all repos. Publisher flow uses branch-to-ACR mapping with Terraform. Managed App flow uses manifest repo for RC coordination. Ephemeral RGs for PR validation. Monthly release cadence for managed app IaC.

# Summary

Defines CI/CD standards for VibeData: repo structure, branching, deployment flows (Publisher and Managed App), artifact promotion, and environment lifecycle. Excludes customer Fabric artifact CI/CD.

# Context

- Multiple repos across Publisher and Managed App.
- Terraform for publisher infra with state; Bicep for managed app.
- Need isolated environments and auditable releases.

# Proposal Highlights

## Repository Structure

| Category | Repository | Purpose |
| --- | --- | --- |
| Publisher | publisher-services | Publisher engines (Provisioning, TLS, Registry) |
| Publisher | publisher-iac | Terraform for Publisher infrastructure |
| Managed App | platform-services | Core platform services |
| Managed App | studio | Studio application |
| Managed App | studio-agents | Studio AI agents |
| Managed App | control-panel | Control Panel application |
| Managed App | assurance-agents | Assurance agents |
| Managed App | marketplace-iac | Bicep for Marketplace deployment |
| Managed App | manifest | Manifest and RC coordination |

## Platform

| Function | Platform |
| --- | --- |
| Source Control | GitHub |
| CI/CD | GitHub Actions |
| Container Registry (Dev/Prod) | Azure Container Registry |
| Artifact Store | GitHub (GHCR + Releases) |

## Branching Strategy (GitHub Flow)

| Branch | Purpose | Lifetime | Merges To |
| --- | --- | --- | --- |
| main | Production-ready code | Permanent | — |
| feature/* | New features, fixes | Short-lived | integration/* or main |
| integration/* | Cross-repo testing | Short-lived | main |

## Publisher Flow

Branch-to-ACR mapping with Terraform deploys.

| Branch | ACR | Tag Pattern |
| --- | --- | --- |
| feature/* | Dev ACR | :feature-{name} |
| main | Prod ACR | :{version}, :latest |

Flow steps:
1) Push feature/* → CI pushes image to Dev ACR :feature-{name}
2) PR to main → CI creates ephemeral RG, runs tests
3) Merge to main (services) → push to Prod ACR :{version}
4) Merge to main (publisher_iac) → Terraform apply to Prod RG

Ephemeral RG uses mixed tags (changed: :feature-{name}, unchanged: :latest).

## Managed App Flow — Services

Manifest repo coordinates RC creation.

Flow steps:
1) Push feature/* → Dev ACR :feature-{name}
2) Manual deploy-dev.sh → Dev Managed App RG
3) PR to main → Ephemeral RG with mixed tags
4) Merge to main → Dev ACR :latest
5) PR to manifest repo updating versions
6) Merge manifest main → GHCR RC tag
7) deploy-release.sh → Release RG
8) promote:stable label → GHCR stable
9) copy to Prod ACR

## Managed App Flow — IaC (marketplace)

Monthly release cadence; PR to main deploys to ephemeral RG; merge accumulates changes; monthly label creates RC release; promote to stable then marketplace.

## Cross-Repo Integration

Integration branches for multi-repo features; deploy to integration RG (`vd-integration-{name}`); merge back to main after validation.

## Deployment Model

Single Bicep codebase; Terraform wraps Bicep for non-prod; tags injected by Terraform; marketplace uses Bicep directly.

## Resource Group Strategy

| RG Type | Naming | Lifecycle | Cleanup |
| --- | --- | --- | --- |
| Per-developer | vd-dev-{username}-managed | Long-lived | Manual |
| Ephemeral | vd-ephemeral-{pr-number} | PR lifecycle | Auto-delete on PR close |
| Integration | vd-integration-{name} | Manual | Manual |
| Release | vd-release-managed | Long-lived | None |

Ephemeral RG tagging (dev/ephemeral): owner, purpose, pr, repo, created, workflow_run_id.

## State Management

| Environment | Publisher | Managed App |
| --- | --- | --- |
| Dev | Terraform: dev | Terraform: dev-{username} |
| Ephemeral | CI-managed | CI-managed |
| Production | Terraform: prod | Marketplace (no state) |

## Retention Policy

| Registry | Retention |
| --- | --- |
| Dev ACR | Current + last version per image |
| GHCR | Current + last RC, all stable versions |
| Prod ACR | All stable versions |

## Access Control

| Action | Who | Approval |
| --- | --- | --- |
| Push to Dev ACR | Any developer | None |
| Push to Prod ACR | GitHub Actions | PR approval |
| Create RC (manifest) | Developer | PR approval |
| Label release:{version} | Release Manager | Tech Lead |
| Label promote:stable | Release Manager | Tech Lead + PM |
| Label promote:partner-center | Release Manager | Tech Lead + PM |
| Partner Center publish | Release Manager | Microsoft review |

Scripts: deploy-dev.sh, deploy-release.sh.

# Open Questions

- None listed.
