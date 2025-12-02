## AWS Secure Ecommerce Platform

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

### Repo Structure
```
.
├── base-infrastructure-bootstrap/
│   └── terraform/
│       ├── bootstrap/        # Remote state + artifact buckets + IAM prerequisites
│       └── envs/             # Foundation stacks (DNS, VPC, EKS, Cognito, ingress)
├── terraform/
│   ├── modules/              # Versioned reusable Terraform modules
│   └── envs/                 # Application layer (RDS, ECR, observability, etc.)
├── k8s/                      # Helm chart templates & values per service
├── docs/                     # Architecture, threat model, DR runbook, compliance notes
└── .github/workflows         # Bootstrap, infra, and application CI/CD
```

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

### Required GitHub Secrets
Set these under **Settings → Secrets → Actions** to satisfy the provided workflows:

| Secret | Purpose |
| --- | --- |
| `AWS_NONPROD_TERRAFORM_ROLE` / `AWS_PROD_TERRAFORM_ROLE` | OIDC role ARN for Terraform workflow matrices |
| `AWS_APP_DEPLOY_ROLE` | Role assumed by `app-delivery` for ECR push + Helm deploy |
| `AWS_ACCOUNT_ID` | Used to compose the default ECR registry string |
| `COSIGN_PASSWORD`, `COSIGN_PRIVATE_KEY` | Required if you encrypt Cosign keys at rest |
| `SLACK_WEBHOOK` / PagerDuty key (optional) | For future ChatOps/alert routing hooks |

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

