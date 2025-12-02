## Reference Architecture

### Accounts & Organization
| Account | Purpose | Key Workloads |
| --- | --- | --- |
| Shared Services | Centralized networking, security tooling, observability, CI/CD | Transit Gateway, AWS Config Aggregator, GuardDuty master, OpenSearch |
| Non-Prod | Dev + QA clusters (EKS), lower-cost RDS, feature testing | Login/Orders/Payments/Inventory/Catalog services |
| Prod | Mission-critical workloads, isolated IAM boundary | Same services with higher capacity, cross-region DR |

Service Control Policies enforce: mandatory tagging, KMS encryption, blocked regions, and approved instance families.

### Networking
- `/16` VPC per account (e.g., `10.20.0.0/16`) with the following subnets per AZ:  
  - Public `/20` (ingress, ALB, NAT)  
  - Private-App `/19` (EKS nodes)  
  - Private-Data `/22` (RDS, Redis)  
- AWS Transit Gateway for future hub-and-spoke connectivity.  
- AWS Network Firewall + Traffic Mirroring for east/west inspection.  
- Route53 Resolver endpoints for hybrid DNS.  
- VPC Flow Logs to centralized S3 + OpenSearch.

### Edge & Security
- AWS CloudFront (WAF + Shield Advanced) → AWS Global Accelerator → ALB (HTTP/2 + gRPC).  
- AWS WAF managed rules + custom bot/threat signatures.  
- SSL termination at CloudFront with ACM-managed certs.  
- AWS Firewall Manager enforces consistent SG & WAF policies.  
- GuardDuty, Macie, Detective, and Security Hub enabled org-wide.

### Compute & Orchestration
- Amazon EKS (control plane private) with managed node groups:
  - `general`: `m6a.large` spot/od mix for stateless services.
  - `system`: `t3.medium` on-demand for ingress, observability, Argo CD.
  - Optional Fargate profile for jobs.
- Add-ons: CoreDNS, VPC CNI, KubeProxy, EBS CSI via Terraform.  
- Policy-as-code: Kyverno/OPA Gatekeeper baseline, Pod Security Standards restricted.  
- AWS IAM Roles for Service Accounts for fine-grained AWS access (S3, SQS, Secrets Manager).  
- Cluster Autoscaler + Karpenter ready.

### Data Layer
- Amazon RDS PostgreSQL 15:  
  - Multi-AZ (prod), Single-AZ (np).  
  - Storage autoscaling, performance insights, TLS-only connections, IAM auth.  
  - Parameter groups enforce SSL + logging.  
- AWS Secrets Manager rotates DB creds every 30 days.  
- Amazon S3 for object data (encrypted, access logs, lifecycle tiers).  
- Amazon ElastiCache (optional) for session caching.

### Observability
- AWS Distro for OpenTelemetry (ADOT) DaemonSet exporting:
  - Metrics → Amazon Managed Prometheus
  - Traces → AWS X-Ray
  - Logs → CloudWatch Logs / OpenSearch
- Managed Grafana dashboards for SLOs, capacity, costs.  
- PagerDuty + Slack integration via AWS Chatbot.  
- Synthetic canaries (CloudWatch Synthetics) for critical APIs.  
- Centralized audit logging (CloudTrail org trail → S3 + Lake Formation).

### CI/CD & Supply Chain
- GitHub Actions workflows:
  - `terraform.yml`: fmt, validate, tfsec/checkov, OPA policy checks, plan/apply with manual approval for prod.
  - `app-delivery.yml`: Node/React tests, SAST (ESLint, npm audit), Docker build, Syft SBOM, Trivy scan, Cosign sign, push to ECR, deploy via Argo CD CLI.
- Environments require approval + deploy keys.  
- Artifact retention enforced, provenance metadata stored with images.

### HA & DR Strategy
- Multi-AZ EKS, ALB, RDS.  
- Cross-region read replica (prod) + snapshot copy via AWS Backup.  
- Velero backups to versioned S3 with KMS.  
- Route53 health checks & failover routing.  
- Recovery runbooks test quarterly (see `docs/dr-runbook.md`).  
- Target RTO < 30 min (app), < 2 hrs (data). RPO < 5 min with read replicas + PITR.

### Cost Optimization
- Use Graviton-based nodes for prod workloads.  
- Spot-based node group for stateless services (np).  
- Automated rightsizing via Compute Optimizer insights.  
- AWS Budgets + anomaly detection alerts to FinOps channel.  
- Required tags feed CUR & Athena cost dashboards.  
- Auto-pause analytics clusters in non-prod.

