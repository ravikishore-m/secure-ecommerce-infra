## AWS Secure Ecommerce Platform

**Owner:** Machiraju Ravikishore

**Repository Description**  
The Secure Ecommerce Platform repository is a turnkey, security-first reference implementation for running an AWS-native ecommerce business. It bundles Terraform  automation, reusable infrastructure modules, GitHub Actions pipelines with supply-chain gates, and Kubernetes manifests for every customer-facing microservice so platform teams can bootstrap a compliant environment quickly.

### About & Tech Stack
This project packages everything a platform team needs to stand up a secure ecommerce shop on AWS—landing zone, infrastructure code, CI/CD, and the storefront plus API services. It favors boring, proven services so day-2 ops stay simple.

**Tech stack (plain English):**
- AWS (VPC, EKS Kubernetes, RDS PostgreSQL, ALB + WAF, Cognito, Route53, Secrets Manager, KMS)
- Terraform modules for every account + AWS resource, stored alongside GitHub Actions pipelines
- Kubernetes/Helm for app deployment, Calico for network policies, AWS Load Balancer Controller for ingress
- Docker images, SBOM + security scans via Syft/Grype/Trivy, Cosign for image signing
- React + Vite frontend, Node.js/Express microservices (login, orders, payments, inventory, catalog), shared DB helpers
- Prometheus/Grafana (AMP) + CloudWatch + ADOT for metrics, logs, and traces
- OPA/Conftest and Checkov policies keeping IaC compliant and production ready

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
└── .github/workflows/               # Landing Zone Bootstrap, Terraform envs, and Application Delivery CI/CD
```

## Deployment Inputs & Parameters

Capture these inputs early so every stage (Terraform + Kubernetes) can be executed non-interactively.

### Stage 0 – CI/CD & Identity (GitHub Secrets)
| Input | Description | Where to set |
| --- | --- | --- |
| `AWS_NONPROD_TERRAFORM_ROLE` / `AWS_PROD_TERRAFORM_ROLE` | Role ARNs assumed by Terraform plans/applies. | GitHub repo → Settings → Secrets and variables → Actions |
| `AWS_NONPROD_APP_DEPLOY_ROLE` / `AWS_PROD_APP_DEPLOY_ROLE` | Cross-account IAM roles created by the bootstrap stack for building/pushing images and running Helm per environment. | GitHub Secrets |
| `AWS_NONPROD_ACCOUNT_ID` / `AWS_PROD_ACCOUNT_ID` | Account IDs used to compose each ECR registry URL (mirroring + deployments). | GitHub Secrets |
| `COSIGN_PRIVATE_KEY` / `COSIGN_PASSWORD` | Required if Cosign keys are stored encrypted for image signing. | GitHub Secrets |
| `SLACK_WEBHOOK` / PagerDuty key (optional) | Enables ChatOps notifications from workflows. | GitHub Secrets |

### Stage 1 – Terraform Bootstrap (`base-infrastructure-bootstrap/terraform/bootstrap`)
| Input | Description | Where to set |
| --- | --- | --- |
| `region` | AWS region that hosts remote state + artifacts. | `terraform.tfvars` or CLI flag |
| `project_name` | Prefix applied to S3 buckets, IAM roles, and tags. | `terraform.tfvars` |
| `state_bucket_name` | Global, unique S3 bucket for Terraform remote state. | `terraform.tfvars` |
| `artifact_bucket_name` | Bucket for CI/CD logs, SBOMs, Velero backups. | `terraform.tfvars` |
| `state_lock_retention_days` | Days to keep each Terraform state version immutable via S3 Object Lock. | `terraform.tfvars` |
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

#### IAM Outputs to capture
After `terraform apply` in `base-infrastructure-bootstrap/terraform/envs/<env>`, copy these outputs into your secret manager or GitHub repository secrets:

- `github_actions_role_arn` → feeds `AWS_<ENV>_TERRAFORM_ROLE`
- `app_deployer_role_arn` → feeds `AWS_<ENV>_APP_DEPLOY_ROLE`
- `app_irsa_role_arn` → annotate the Helm service account (`serviceAccount.annotations.eks.amazonaws.com/role-arn`) so workloads can reach Secrets Manager/SSM through IRSA.

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
| `imagePullSecrets` | Registry secrets (ECR credentials) required for pulling mirrored images. | Helm values |
| `serviceAccount.annotations.eks.amazonaws.com/role-arn` | IRSA role binding so pods can reach AWS APIs (e.g., Secrets Manager). | Helm values |
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
   - `ecommerce-platform-tfstate` S3 bucket (SSE-KMS + Object Lock honoring `state_lock_retention_days` of immutability)  
   - `ecommerce-platform-artifacts` bucket for CI/CD logs, SBOMs, and Velero data

   The stack also creates the `alias/ecommerce-platform/tf-state` KMS alias, which every Terraform backend consumes via the `kms_key_id` setting.

2. **Deploy the foundation stack (per environment)**  
   ```bash
   cd base-infrastructure-bootstrap/terraform/envs/nonprod
   terraform init
   terraform apply
   ```
   Repeat for `prod` when ready (or run `Landing Zone Bootstrap & Guardrails` in `.github/workflows/bootstrap.yml`). This stage stands up the hosted zone + ACM, VPC/TGW, interface endpoints, EKS (with namespaces), Cognito, ingress ALB/WAF, and IAM deployer roles.

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

   # namespace-level quotas + default requests/limits
   kubectl apply -f base-infrastructure-bootstrap/k8s/resource-quotas/<env>.yaml

   # AWS Load Balancer Controller CRDs (required for TargetGroupBinding)
   helm repo add eks https://aws.github.io/eks-charts
   helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
     --namespace kube-system --set clusterName=<cluster> --set serviceAccount.create=true \
     --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=arn:aws:iam::<acct>:role/<alb-controller-role> \
     --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller
   ```

6. **Deploy services**  
   - Build and push microservice images via `Application Delivery & Promotion` (`.github/workflows/app-delivery.yml`) or `scripts/build.sh`.  
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
   - Promote the vetted digest into the prod registry via `scripts/promote-image.sh <src-registry> <dest-registry> ecom-<service> <tag>` (the GitHub workflow calls this script automatically after nonprod deploys succeed).

## Cluster Operations & Deployments

### Calico & network policy workflow
1. Mirror the Calico operator images (see *Image mirroring* below) so EKS never pulls directly from the internet.
2. Apply namespaces and Pod Security Standards:
   ```bash
   kubectl apply -f k8s/namespaces/bootstrap.yaml
   ```
3. Deploy Calico via kustomize (installs the operator + project-specific custom resources):
   ```bash
   kubectl apply -k k8s/addons/calico
   kubectl get tigerastatus default --watch
   ```
4. Re-apply whenever you bump the version in `k8s/addons/calico/kustomization.yaml`.

### Namespace quotas, default resources & pod disruption budgets
- Apply `base-infrastructure-bootstrap/k8s/resource-quotas/<env>.yaml` right after namespaces exist to enforce `ResourceQuota` + `LimitRange` objects for `ecommerce`, `observability`, and `networking`. These YAMLs live beside the bootstrap Terraform so they can be versioned per environment.
- LimitRanges ensure every pod/request has sensible defaults (and caps runaway CPU/memory), while the Helm chart sets per-service `resources` and PodDisruptionBudgets (`services.<name>.pdb`) so voluntary disruptions never take the entire tier offline.

### Rolling updates, persistence & throttling-aware autoscaling
- Deployments use an explicit RollingUpdate strategy (`rollingUpdate.maxSurge` / `maxUnavailable`) and StatefulSets expose `podManagementPolicy` + `rollingUpdate.partition`.
- Stateful workloads (e.g., `orders`) now attach PVCs via `.services.orders.persistence` so write-ahead cache survives restarts.
- HorizontalPodAutoscalers include an optional throttling metric hook (`autoscaling.throttling.*`) so you can scale ReplicaSets when Prometheus exposes `http_requests_throttled_per_second`, not just CPU utilization.

### Image mirroring & registry controls
- Run `scripts/mirror-images.sh` (or let the `Application Delivery & Promotion` workflow do it) to copy hardened base images from Docker Hub → ECR (`mirrors/node` + `mirrors/nginx`).  
- The `scripts/build.sh` helper and GitHub Actions build step inject those mirrored tags through Docker build args so workloads never reference the public internet.
- Create a pull secret per namespace so the cluster authenticates against your ECR registry:
  ```bash
  aws ecr get-login-password --region <region> \
    | kubectl create secret docker-registry ecr-registry \
      --namespace ecommerce \
      --docker-server=<account>.dkr.ecr.<region>.amazonaws.com \
      --docker-username=AWS \
      --docker-password-stdin
  ```
- Reference that secret via `imagePullSecrets` in `k8s/helm/platform-chart/values.yaml` or the env-specific overrides.
- Promote artifacts between registries via `scripts/promote-image.sh <source> <destination> <repository> <tag>` (used automatically by the GitHub workflow after nonprod deployments pass).

### IRSA + pod security defaults
- Bootstrap now creates an `app_irsa_role_arn` bound to `system:serviceaccount:ecommerce:*`. Annotate the Helm service account:
  ```yaml
  serviceAccount:
    annotations:
      eks.amazonaws.com/role-arn: "<app_irsa_role_arn>"
  ```
- Namespaces in `k8s/namespaces/bootstrap.yaml` ship with `pod-security.kubernetes.io/*` labels (`restricted` for `ecommerce`, `baseline`/`privileged` for system namespaces) to enforce Pod Security Standards at admission time.
- The Helm chart defaults to `runAsNonRoot`, drops all Linux capabilities, and applies `seccompProfile: RuntimeDefault`.

### Helm release workflow (nonprod & prod)
1. Populate `k8s/envs/nonprod.values.yaml` and `k8s/envs/prod.values.yaml` with environment-specific domains, RDS endpoints, Cognito IDs, IRSA role ARN, and `imagePullSecrets`.
2. Manual deploy (nonprod example):
   ```bash
   export AWS_REGION=us-east-1
   aws eks update-kubeconfig --name ecommerce-platform-nonprod-eks --region $AWS_REGION
   helm upgrade --install ecommerce k8s/helm/platform-chart \
     --namespace ecommerce --create-namespace \
     --values k8s/envs/nonprod.values.yaml \
     --set global.imageRegistry=<nonprod-account>.dkr.ecr.$AWS_REGION.amazonaws.com \
     --wait --atomic
   ```
3. Repeat for prod with the prod cluster and values file. The `Application Delivery & Promotion` workflow now deploys **both** environments after images are built and signed, so the manual command above is only needed for break-glass or local testing.

### CI/CD safety rails
- **Landing Zone Bootstrap & Guardrails** (`.github/workflows/bootstrap.yml`) now runs `terraform fmt`, `tfsec`, and Checkov before every plan/apply to catch misconfigurations earlier.
- **Application Delivery & Promotion** (`.github/workflows/app-delivery.yml`) mirrors base images, builds/pushes per-environment images, promotes digests to prod, and runs Helm upgrades against nonprod and prod with the correct IAM roles.

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

