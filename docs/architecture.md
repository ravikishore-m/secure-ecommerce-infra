## Reference Architecture

### Accounts & Organization
| Account | Purpose | Key Workloads |
| --- | --- | --- |
| Shared Services | Centralized networking, security tooling, observability, CI/CD | Transit Gateway, AWS Config Aggregator, GuardDuty master, OpenSearch |
| Non-Prod | Dev + QA clusters (EKS), lower-cost RDS, feature testing | Login/Orders/Payments/Inventory/Catalog services |
| Prod | Mission-critical workloads, isolated IAM boundary | Same services with higher capacity, cross-region DR |

Service Control Policies enforce: mandatory tagging, KMS encryption, blocked regions, and approved instance families.

### Networking
- `/16` VPC per account (e.g., `10.20.0.0/16`) carved into:  
  - Public `/20` (ALB, NAT gateways)  
  - Private-App `/19` (EKS nodes/add-ons)  
  - Private-Data `/22` (RDS, Redis)  
- AWS Transit Gateway resources provisioned for future hub-and-spoke connectivity (no attachments by default).  
- Interface VPC endpoints for Secrets Manager, ECR API/DKR, CloudWatch Logs, and SSM.  
- VPC Flow Logs stream into CloudWatch log groups (encrypted via KMS) for detection tooling.

### Edge & Security
- AWS Application Load Balancer (ALB) fronting the storefront + APIs with TLS certs from ACM.  
- AWS WAF (managed rule groups + custom geo filters) associated to the ALB via the ingress module.  
- Shield Standard + Security Hub + GuardDuty + Config delivered by the `modules/security` stack.  
- Calico network policies + AWS security groups enforce east/west segmentation.  
- GitHub OIDC-backed IAM roles issue short-lived creds to CI/CD and GitOps deployers.

### Compute & Orchestration
- Amazon EKS (private API) with two managed node groups:
  - `general`: on-demand `t3.large` nodes for baseline traffic.
  - `spot`: burstable spot capacity for cost-optimized stateless services.
- Pod Security Standards labels applied via `k8s/namespaces/bootstrap.yaml`; Helm chart enforces non-root, seccomp, dropped capabilities.  
- Calico (installed through `k8s/addons/calico`) supplies network policy + service graph enforcement.  
- AWS IAM Roles for Service Accounts (IRSA) created per environment so workloads can reach Secrets Manager / SSM without node creds.  
- AWS Load Balancer Controller + standard addons (CoreDNS/VPC CNI/EBSCsi) provisioned after cluster creation.
- Namespace-level `ResourceQuota` + `LimitRange` manifests (per env) keep runaway requests under control, while PodDisruptionBudgets are emitted for every service to guarantee availability during voluntary disruptions.
- Deployments/StatefulSets leverage RollingUpdate strategies with configurable surge/unavailable, stateful services (orders, Redis) mount PVCs for durable cache/journal storage, and HPAs consume both CPU *and* throttled-request metrics for proactive scaling.

### Data Layer
- Amazon RDS for PostgreSQL 15 managed via Terraform modules:  
  - Multi-AZ enabled in prod, single-AZ in nonprod.  
  - KMS-encrypted storage, enforced TLS (`rds.force_ssl`), enhanced/CloudWatch monitoring.  
  - Credentials stored in AWS Secrets Manager and mounted into Kubernetes via secrets.  
- Amazon S3 buckets for remote state, Config logs, and artifacts (encryption + versioning).  
- Cart cache backed by Redis (statefulset) inside the cluster; swap to ElastiCache if managed caching is required.
- Terraform remote state is stored in an object-lock enabled S3 bucket encrypted by `alias/ecommerce-platform/tf-state`, preventing tampering and satisfying audit requirements.

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
  - **Landing Zone Bootstrap & Guardrails** (`bootstrap.yml`): runs fmt/tfsec/Checkov, then Terraform plan/apply for shared-services + env scaffolding.
  - **Environment Infrastructure (Terraform)** (`terraform.yml`): fmt/tfsec/Checkov/OPA, multi-account plans, manual `workflow_dispatch` applies.
  - **Application Delivery & Promotion** (`app-delivery.yml`): mirrors Docker Hub base images into ECR, runs unit tests, builds images, generates SBOMs (Syft), scans with Trivy, signs via Cosign, deploys nonprod, promotes digests to the prod registry (`scripts/promote-image.sh`), then deploys prod.
- Short-lived GitHub OIDC sessions assume the Terraform/app deployer roles emitted by the bootstrap stack.  
- Immutable ECR repos (`mutable_tags=false`) and image mirroring remove internet pulls during deployments.

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

