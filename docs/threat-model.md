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
| Edge (CloudFront/ALB) | DDoS, OWASP Top 10, bot abuse | Shield Advanced, AWS WAF managed + custom rules, rate limiting, Global Accelerator health checks, TLS 1.2 enforced |
| API/Auth | Credential stuffing, session hijack | Amazon Cognito with adaptive MFA, reCAPTCHA, short-lived tokens, mTLS between services |
| Network | Lateral movement, subnet sprawl | Dedicated private subnets, SG least privilege, Network Firewall, VPC Flow Logs + GuardDuty findings |
| Data | RDS snapshot theft, unencrypted S3 | KMS CMKs, IAM condition keys (`kms:ViaService`), snapshot sharing blocked via SCP, S3 Block Public Access |
| Supply Chain | Dependency trojan, image tampering | Dependabot + npm audit, Sigstore/Cosign signing, OPA policies verifying signatures, immutable ECR tags |
| CI/CD | Token theft, privilege escalation | GitHub OIDC short-lived creds, environments with required reviewers, Gitleaks secret scanning |
| Kubernetes | Privilege escalation, drift | Pod Security Standards restricted, Kyverno policies, IRSA, NS/NetworkPolicies, read-only rootfs, image scanning |

### Detection & Response
- GuardDuty + Security Hub aggregated to shared account with auto-ticketing.
- CloudTrail Lake queries for anomaly detection; Detective for lateral movement analysis.
- Fluent Bit exports Kubernetes audit logs to OpenSearch for correlation.
- PagerDuty runbooks for P1 incidents referencing `docs/dr-runbook.md`.

