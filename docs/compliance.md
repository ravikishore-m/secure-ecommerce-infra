## Compliance & Governance

### Framework Mapping
| Control Family | AWS Service / Artifact |
| --- | --- |
| Identity & Access (PCI DSS 7) | IAM SCPs, least privilege roles, AWS SSO, MFA enforced |
| Data Protection (PCI DSS 3) | KMS CMKs with rotation, Secrets Manager, TLS 1.2+, S3 Object Lock |
| Logging & Monitoring (SOC 2 CC6) | CloudTrail, GuardDuty, Config, AMP/Grafana, centralized log archival |
| Change Management (SOC 2 CC8) | Terraform IaC with PR reviews, GitHub protected branches, automated drift detection |
| Vulnerability Management (PCI DSS 11) | Trivy, Dependabot, Snyk (optional), AWS Inspector, Patch Manager |
| Business Continuity (SOC 2 CC7) | DR runbooks, Velero backups, AWS Backup plans, Route53 failover |

### Policies-as-Code
- **OPA/Conftest**: Blocks Terraform if tagging/encryption/network policies violated.
- **Checkov/tfsec**: Baseline IaC scanning in CI.
- **Kyverno**: Enforces Pod Security, disallows latest tags, requires resource limits.

### Evidence & Reporting
- AWS Config conformance packs (`Operational-Best-Practices-for-NIST-800-53`).
- Security Hub standards (Foundational, PCI). Findings aggregated & auto-created as Jira tickets.
- Terraform state + CI logs stored for 1 year for auditability.

### Access Control
- Break-glass roles require MFA + IAM Approval workflow.  
- Session tags capture `ChangeID`, `Environment`, `Ticket`.  
- GitHub branch protections require code owners + security sign-off for prod.

