## AWS Secure Ecommerce Platform

**Repository Description**  
The Secure Ecommerce Platform repository is a turnkey, security-first reference implementation for running an AWS-native ecommerce business. It bundles Terraform  automation, reusable infrastructure modules, GitHub Actions pipelines with supply-chain gates, and Kubernetes manifests for every customer-facing microservice so platform teams can bootstrap a compliant environment quickly.

This repository delivers a production-ready reference implementation for deploying a security-first ecommerce stack on AWS. It codifies multi-account landing-zone practices, Terraform modules for reusable infrastructure, GitHub Actions CI/CD, and EKS-ready application manifests for the following microservices:

- `frontend` (React storefront served via Nginx)
- `login`
- `orders`
- `payments`
- `inventory`
- `catalog` (CX-focused merchandising service)

### High-Level Architecture
- **Accounts**: `shared-services` (network + tooling), `nonprod`, `prod`. Cross-account IAM roles are assumed via GitHub OIDC for Terraform and CI/CD.
- **Network**: Dedicated VPC per workload account using /16 CIDR split into scalable public, private app, and data subnets spanning three AZs. AWS Transit Gateway ready via optional outputs.
- **Edge + Security**: AWS Application Load Balancer + AWS WAF protect ingress. AWS Certificate Manager issues TLS certs and Route53 hosts the public zone. AWS Firewall Manager + GuardDuty + Security Hub enforce guardrails.
- **Compute**: Amazon EKS with managed node groups (Bottlerocket, Graviton for prod). IRSA, pod security standards, Fargate profiles for system workloads, and Karpenter-ready annotations.
- **Data**: Amazon RDS for PostgreSQL (multi-AZ, encryption, automated backups), Secrets Manager for credentials, KMS CMKs per account.
- **Observability**: CloudWatch Container Insights, AWS Distro for OpenTelemetry (ADOT) for metrics/traces to Amazon Managed Prometheus/Grafana, plus cross-account log aggregation to OpenSearch (optional).
- **CI/CD**: GitHub Actions implements Terraform pipeline (plan/apply with OPA policy gates) and application pipeline (SAST, container scan, SBOM, image signing, Argo CD deployment).
- **HA & DR**: Multi-AZ workloads, cross-region read replicas for RDS (prod), Velero EKS backups to versioned S3, Route53 health checks, documented RTO/RPO targets. Runbooks captured in `docs/dr-runbook.md`.
- **Cost & Compliance**: Savings Plans guardrails, budget alerts, tagging policies, AWS Config conformance packs mapped to PCI DSS + SOC2 controls. Workflows enforce policy-as-code with Checkov + OPA.

## Production Readiness & Security Posture
- **Multi-account landing zone**: Bootstrap + env Terraform codify shared-services/nonprod/prod accounts with centralized logging, dedicated VPC tiers, and cross-account IAM via GitHub OIDC.
- **Guardrailed IaC**: Every workflow runs `terraform fmt`, `tflint`, Checkov, and OPA policies before plan/apply, ensuring encryption/tagging/network policies are enforced pre-merge.
- **Supply-chain protections**: App delivery pipeline builds SBOMs (Syft), scans images (Grype/Trivy), signs artifacts with Cosign, and pushes to immutable ECR repos.
- **Network & ingress hardening**: AWS WAF + ALB, Calico network policies, namespaced service accounts with IRSA, and TargetGroupBinding integration for zero-trust ingress.
- **Data & secrets safety**: RDS with KMS CMKs, Secrets Manager for credentials, IAM fine-grained roles, and automated rotation hooks.
- **Observability & DR**: AMP/Grafana dashboards, CloudWatch alarms, ADOT traces, DR runbooks, and Velero/S3 backups aligned to documented RPO/RTO.
- **Governance & compliance**: Policy-as-code backed by Terraform OPA module, docs mapping controls to PCI DSS/SOC2, plus AWS Config/GuardDuty/Security Hub enablement.

## Prerequisites

**Accounts & IAM**
- An AWS Organization (or equivalent) with at least `shared-services`, `nonprod`, and `prod` accounts plus the ability to create cross-account IAM roles.
- Permission to create/update Route53 hosted zones, ACM certificates, KMS CMKs, VPC networking components, and GitHub OIDC identity providers.
- GitHub repository admin rights to configure OIDC trust and Actions secrets.

**Local & CI Tooling**
- Terraform `>= 1.6`, AWS CLI v2 (with SSO or long-lived profiles), and access to `jq`.
- `kubectl >= 1.28`, `helm >= 3.12`, and (optional) Argo CD CLI for GitOps.
- Docker (for building/pushing images), Cosign (image signing), Syft/Grype (SBOM + scanning), and Node.js 20+ with npm or pnpm for the React frontend.

**Networking & Domain Readiness**
- A registered Route53 domain for `root_domain` plus DNS delegation ability.
- Outbound internet access from the operator machine / CI runners to reach AWS APIs and GitHub.
- Optional: Slack webhook or PagerDuty routing keys if you plan to enable ChatOps alerts.

### Repo Structure (High-Level)
```
.
├── base-infrastructure-bootstrap/   # Remote state + multi-account bootstrap Terraform
├── terraform/                       # Reusable modules + env-specific stacks (RDS, ECR, obs, etc.)
├── services/                        # Node microservices (login, orders, payments, inventory, catalog)
├── frontend/                        # React storefront built with Vite
├── k8s/                             # Helm chart, add-ons, namespaces, policies
├── docs/                            # Architecture, threat model, DR, observability, compliance
├── policy/                          # OPA/Conftest policies
├── scripts/                         # Tooling (docker builds, helpers)
├── db/                              # Schema migrations and seed SQL
└── .github/workflows/               # Bootstrap, infra, and application CI/CD pipelines
```

## Deployment Inputs & Parameters

Capture these inputs early so every stage (Terraform + Kubernetes) can be executed non-interactively.

### Stage 0 – CI/CD & Identity (GitHub Secrets)
| Input | Description | Where to set |
| --- | --- | --- |
| `AWS_NONPROD_TERRAFORM_ROLE` / `AWS_PROD_TERRAFORM_ROLE` | Role ARNs assumed by Terraform plans/applies. | GitHub repo → Settings → Secrets and variables → Actions |
| `AWS_APP_DEPLOY_ROLE` | Role assumed by the app delivery workflow for ECR pushes + Helm deploys. | GitHub Secrets |
| `AWS_ACCOUNT_ID` | Used to compose the default ECR registry URL inside workflows. | GitHub Secrets |
| `COSIGN_PRIVATE_KEY` / `COSIGN_PASSWORD` | Required if Cosign keys are stored encrypted for image signing. | GitHub Secrets |
| `SLACK_WEBHOOK` / PagerDuty key (optional) | Enables ChatOps notifications from workflows. | GitHub Secrets |

### Stage 1 – Terraform Bootstrap (`base-infrastructure-bootstrap/terraform/bootstrap`)
| Input | Description | Where to set |
| --- | --- | --- |
| `region` | AWS region that hosts remote state + artifacts. | `terraform.tfvars` or CLI flag |
| `project_name` | Prefix applied to S3 buckets, IAM roles, and tags. | `terraform.tfvars` |
| `state_bucket_name` | Global, unique S3 bucket for Terraform remote state. | `terraform.tfvars` |
| `artifact_bucket_name` | Bucket for CI/CD logs, SBOMs, Velero backups. | `terraform.tfvars` |
| `lock_table_name` | DynamoDB table used for Terraform state locking. | `terraform.tfvars` |
| `trusted_role_arns` | IAM role ARNs allowed to read/write the remote state bucket. | `terraform.tfvars` |

### Stage 2 – Foundation Stack (`base-infrastructure-bootstrap/terraform/envs/<env>`)
| Input | Description | Where to set |
| --- | --- | --- |
| `environment` / `region` / `owner` | Tagging + scoping for each account. Defaults provided per env. | `terraform.tfvars` |
| `assume_role_arn` | Role assumed by Terraform when deploying the environment. | `terraform.tfvars` |
| `github_repositories` | `org/repo` strings allowed to assume deployer roles via OIDC (set to your repo, e.g. `your-github-user/secure-ecommerce-infra`). | `terraform.tfvars` |
| `create_github_oidc_provider` | Boolean to create the GitHub OIDC provider if it does not exist. | `terraform.tfvars` |
| `github_oidc_provider_arn` | ARN of an existing GitHub OIDC provider (if not creating a new one). | `terraform.tfvars` |
| `root_domain` / `create_hosted_zone` | Public domain managed in Route53 + flag to create or reuse the zone. | `terraform.tfvars` |
| `cognito_domain_prefix` | Hosted UI prefix for the user pool domain. | `terraform.tfvars` |
| `dummy_user_email` / `dummy_user_temp_password` | Seed Cognito user credentials for smoke testing. | `terraform.tfvars` (rotate in Secrets Manager after bootstrap) |
| `alert_emails` | Distribution lists for foundational CloudWatch alarm subscriptions. | `terraform.tfvars` |

### Stage 3 – Application Layer (`terraform/envs/<env>`)
| Input | Description | Where to set |
| --- | --- | --- |
| `assume_role_arn` | Role used for RDS/ECR/observability stacks per environment. | `terraform.tfvars` |
| `bootstrap_state_bucket` / `bootstrap_state_prefix` | Location of the base stack state outputs consumed by modules. | `terraform.tfvars` |
| `alert_emails` | Recipients for AMP/Grafana/CloudWatch alerts emitted by the observability module. | `terraform.tfvars` |

### Stage 4 – Kubernetes & Application Deployments
| Input | Description | Where to set |
| --- | --- | --- |
| `global.domain` | Public domain used by the storefront + API ingress. | `k8s/helm/platform-chart/values.yaml` or Helm CLI `--set` |
| `database.*` | Host, port, db name, username, and the Secret holding the RDS password. Populate from Terraform outputs. | Helm values |
| `cognito.*` | User pool ID, client ID, region, and callback URIs for the login flow. | Helm values / Argo CD parameters |
| `ingressBindings.targetGroups` | TargetGroup ARNs exported by the bootstrap stack for ALB bindings. | Helm values (JSON via `--set-json`) |
| `image.repository` / `tag` | Per-service container image references pointing at the ECR repos created in Stage 3. | Helm values / GitOps |
| AWS Load Balancer Controller IAM role | Needed for the controller Helm release to manage TargetGroupBinding CRDs. | EKS IRSA annotations (see Getting Started step 5) |

> 📘 All module variables are documented inline (`variables.tf` files) and in `docs/` for deeper explanations.

### Getting Started
1. **Bootstrap remote state + artifact buckets**  
   ```bash
   cd base-infrastructure-bootstrap/terraform/bootstrap
   terraform init
   terraform apply -var='trusted_role_arns=["arn:aws:iam::111111111111:role/SharedServicesTerraform","arn:aws:iam::222222222222:role/ProdTerraform"]'
   ```
   This provisions:
   - `ecommerce-platform-tfstate` S3 bucket (SSE-KMS) + `ecommerce-platform-tf-locks` DynamoDB table  
   - `ecommerce-platform-artifacts` bucket for CI/CD logs, SBOMs, and Velero data

2. **Deploy the foundation stack (per environment)**  
   ```bash
   cd base-infrastructure-bootstrap/terraform/envs/nonprod
   terraform init
   terraform apply
   ```
   Repeat for `prod` when ready (or run `.github/workflows/bootstrap.yml`). This stage stands up the hosted zone + ACM, VPC/TGW, interface endpoints, EKS (with namespaces), Cognito, ingress ALB/WAF, and IAM deployer roles.

3. **Configure AWS providers**  
   - Export AWS profiles or assume roles matching `assume_role_arn` in each environment (`SharedServicesTerraform`, `ProdTerraform`).

4. **Apply the application layer (RDS/ECR/observability)**  
   ```bash
   cd terraform/envs/nonprod
   terraform init
   terraform apply
   ```
   These stacks automatically read the base state from `s3://ecommerce-platform-tfstate/base/<env>/terraform.tfstate`. Repeat for `prod` once non-prod has been validated.

5. **Prime the cluster right after EKS creation**  
   ```bash
   # namespaces + platform add-ons
   kubectl apply -f k8s/namespaces/bootstrap.yaml
   kubectl apply -k k8s/addons/calico

   # AWS Load Balancer Controller CRDs (required for TargetGroupBinding)
   helm repo add eks https://aws.github.io/eks-charts
   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --namespace kube-system --set clusterName=<cluster> --set serviceAccount.create=true \
     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<acct>:role/<alb-controller-role> \
     --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller
   ```

6. **Deploy services**  
   - Build and push microservice images via `.github/workflows/app-delivery.yml` or `scripts/build.sh`.  
   - Populate the Helm values for `global.domain`, `database.*`, and `cognito.*` using outputs from the app/core Terraform (`terraform output`) and the bootstrap stack (Cognito/RDS endpoints).  
   - Export ALB target group ARNs from the bootstrap state and feed them to Helm/Argo:  
     ```bash
     cd base-infrastructure-bootstrap/terraform/envs/nonprod
     terraform output -json ingress_target_group_arns > /tmp/tg.json
     helm upgrade --install ecommerce k8s/helm/platform-chart \
       --namespace ecommerce --create-namespace \
       --set ingressBindings.enabled=true \
       --set-json ingressBindings.targetGroups="$(cat /tmp/tg.json)"
     ```
   - Use Argo CD or Flux for GitOps sync if preferred.

### Security Highlights
- Defence-in-depth with layered network segmentation, WAF, Shield, Security Groups, and NACLs.
- Encrypted everywhere (TLS 1.2+, KMS CMKs, Secrets Manager, EBS & EFS encryption).
- IAM least privilege, SCPs, session tagging, access analyzer, automated key rotation.
- Supply-chain security with SLSA-aligned pipeline, SBOM (Syft), image signing (Cosign), and policy gates (Conftest + Checkov + Trivy).

### Observability & Operations
- Metrics: CloudWatch Container Insights, AMP, Grafana dashboards under `docs/observability.md`.
- Logs: Fluent Bit DaemonSet ships to centralized OpenSearch + S3 for immutable storage.
- Traces: ADOT Collector exports to X-Ray and AMP.
- Alerting: AWS Chatbot + PagerDuty integrations triggered by CloudWatch/AMP alerts.

### Compliance & Governance
- AWS Config conformance packs for PCI DSS/SOC2 + custom guardrails.
- GuardDuty, Macie, IAM Access Analyzer, Detective enabled organization-wide.
- Terraform + CI/CD enforce tagging, encryption, and CIDR policies with OPA.

Refer to the `docs/` directory for detailed architecture diagrams, threat models, and operational runbooks. Update variables and secrets per environment before deployment.

