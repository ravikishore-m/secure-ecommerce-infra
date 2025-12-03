## Compliance & Governance

### Framework Mapping
| Control Family | AWS Service / Artifact |
| --- | --- |
| Identity & Access (PCI DSS 7) | IAM SCPs, least privilege roles, AWS SSO, MFA enforced |
| Data Protection (PCI DSS 3) | KMS CMKs with rotation, Secrets Manager, TLS 1.2+, S3 Object Lock |
| Logging & Monitoring (SOC 2 CC6) | CloudTrail, GuardDuty, Config, AMP/Grafana, centralized log archival |
| Change Management (SOC 2 CC8) | Terraform IaC with PR reviews, GitHub protected branches, automated drift detection |
| Vulnerability Management (PCI DSS 11) | Trivy, Dependabot alerts, AWS Inspector (optional), patching via AMIs |
| Business Continuity (SOC 2 CC7) | DR runbooks, Velero backups, AWS Backup plans, Route53 failover |

### Policies-as-Code
- **OPA/Conftest**: Runs in `Environment Infrastructure (Terraform)` (`.github/workflows/terraform.yml`) to block merges when encryption/tag/ingress policies are violated.
- **Checkov + tfsec**: Baseline IaC scanning in both `Landing Zone Bootstrap & Guardrails (bootstrap.yml)` and `Environment Infrastructure (Terraform) (terraform.yml)`.
- **Pod Security Standards + Calico policies**: Namespaces are labeled `restricted`/`baseline`, and Helm workloads enforce non-root/readonly FS/network policies—eliminating the need for an additional admission controller.
- **ResourceQuota/LimitRange manifests**: Each environment applies managed YAML from `base-infrastructure-bootstrap/k8s/resource-quotas/` so pods always declare requests/limits and namespaces have guardrails.

### Evidence & Reporting
- AWS Config recorder + delivery channel store configuration history in encrypted S3.
- Security Hub standards (CIS, AWS FSBP, PCI) enabled via `modules/security`; findings routed through SNS/email.
- Terraform state + GitHub Actions logs stored in `ecommerce-platform-artifacts` for 365 days.

### Access Control
- Break-glass roles (outside Terraform) should require MFA + ticket reference—documented in the shared-services account.  
- GitHub branch protections enforce PR review, status checks, and signed commits before merging to `main`.  
- Terraform/app deploy roles issued via GitHub OIDC are scoped to the repository/environment subject (`repo:<org>/<repo>:environment:<env>`), limiting blast radius for CI credentials.

