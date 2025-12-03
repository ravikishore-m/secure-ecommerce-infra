## Terraform Bootstrap & Remote State

All backend prerequisites (state buckets, artifact store, lock table, GitHub OIDC, and deployer roles) are codified in `base-infrastructure-bootstrap/terraform/bootstrap`. You no longer need to create buckets or roles by hand—just run Terraform once per shared-services account.

### 1. Apply the bootstrap stack
```bash
cd base-infrastructure-bootstrap/terraform/bootstrap
terraform init
terraform apply \
  -var='region=us-east-1' \
  -var='trusted_role_arns=["arn:aws:iam::111111111111:role/SharedServicesTerraform","arn:aws:iam::222222222222:role/ProdTerraform"]'
```
This provisions:
- `ecommerce-platform-tfstate` S3 bucket (versioned, SSE-KMS) + DynamoDB lock table.
- `ecommerce-platform-artifacts` bucket for CI logs/SBOMs/Velero backups.
- GitHub OIDC provider (optional) and baseline IAM roles for Terraform + app delivery.

### 2. Capture outputs
Record these outputs in your password manager / GitHub repository secrets:

| Output | Purpose |
| --- | --- |
| `github_actions_role_arn` | Used as `AWS_<ENV>_TERRAFORM_ROLE` for `Environment Infrastructure (Terraform)` (`.github/workflows/terraform.yml`) and `Landing Zone Bootstrap & Guardrails` (`bootstrap.yml`). |
| `app_deployer_role_arn` | Used as `AWS_<ENV>_APP_DEPLOY_ROLE` so GitHub Actions can build/push from ECR and run Helm. |
| `app_irsa_role_arn` | Annotate the Helm service account (`eks.amazonaws.com/role-arn`) so pods can read Secrets Manager/SSM. |

The bootstrap outputs also include the remote-state bucket name and prefix that workload envs reference through `bootstrap_state_bucket` / `bootstrap_state_prefix`.

### 3. GitHub configuration
1. Add the OIDC provider under **Settings → Security → OpenID Connect** if Terraform created it.
2. Create the secrets listed in `README.md` (Terraform roles, app deploy roles, per-account IDs, Cosign keys, optional Slack/PagerDuty).
3. Protect `main` branch with required reviews so Terraform plans run before merge.

### 4. Guardrails enabled by default
Running the bootstrap stack also enables:
- AWS Config recorder + delivery channel with encrypted S3 storage.
- GuardDuty + Security Hub standards subscriptions (CIS, AWS FSBP, PCI).  
- AWS WAF (managed rules) whose ARN feeds the ingress module.  
Keep tagging consistent (`Environment`, `Project`, `Owner`) so Config/Cost reporting stays accurate.

### 5. Apply namespace quotas per environment
Each environment ships with a curated set of `ResourceQuota` + `LimitRange` manifests under `base-infrastructure-bootstrap/k8s/resource-quotas/<env>.yaml`. After EKS, namespaces, and Calico are in place, run:

```bash
kubectl apply -f base-infrastructure-bootstrap/k8s/resource-quotas/nonprod.yaml
# repeat for prod when ready
```

These guardrails enforce default CPU/memory requests and cap the number of pods/PVCs per namespace so runaway workloads cannot starve the cluster.

