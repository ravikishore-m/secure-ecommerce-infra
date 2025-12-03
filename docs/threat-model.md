## Threat Model

### Assets
- Customer PII, payment tokens, order data
- Service source code, container images, Terraform state
- AWS credentials/roles, Secrets Manager secrets

### Adversaries
- External attackers (botnets, credential stuffing, DDoS)
- Malicious insiders / compromised developer machines
- Supply-chain actors (dependency poisoning, artifact tampering)
- Opportunistic data exfiltration (misconfigured buckets, egress)

### Attack Surfaces & Mitigations

| Surface | Threats | Mitigations |
| --- | --- | --- |
| Edge (ALB + WAF) | DDoS, OWASP Top 10, bot abuse | Shield Standard, AWS WAF managed rule groups, geo filters, TLS 1.2+, health checks via Route53 |
| API/Auth | Credential stuffing, session hijack | Amazon Cognito hosted UI, adaptive MFA, short-lived tokens, secure session cookies |
| Network | Lateral movement, subnet sprawl | Dedicated private subnets, Calico network policies, SG least privilege, VPC Flow Logs + GuardDuty detections |
| Data | RDS snapshot theft, unencrypted S3 | KMS CMKs, Secrets Manager, snapshot sharing disabled via IAM, S3 Block Public Access |
| Supply Chain | Dependency trojan, image tampering | Dependabot + npm audit, Syft SBOM + Trivy scan, Cosign signing, immutable ECR repos, mirrored base images |
| CI/CD | Token theft, privilege escalation | GitHub OIDC short-lived creds scoped to repo/environment, required reviews, artifact retention in S3, terraform/app roles limited via STS |
| Kubernetes | Privilege escalation, drift | Pod Security Standards (`restricted`), read-only rootfs, seccomp defaults, IRSA, Calico network policies, namespace ResourceQuotas/LimitRanges, imagePullSecrets bound to ECR, service-level PDBs |

### Detection & Response
- GuardDuty + Security Hub (enabled via Terraform) publish findings to the shared-services account and alert lists defined in `var.alert_emails`.
- CloudTrail + Config logs live in encrypted S3 buckets; query via Athena/CloudWatch Lake for investigations.
- Fluent Bit ships container + audit logs to CloudWatch Logs where metric filters back PagerDuty/Slack alerts.
- PagerDuty / SNS notifications link to `docs/dr-runbook.md` so on-call responders follow the tested recovery steps.

