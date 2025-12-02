## Terraform Backend Bootstrap

Before running any workload environment, apply the helper in `base-infrastructure-bootstrap/terraform/bootstrap` (or follow the manual commands below) to create the remote state, centralized artifact bucket, and DynamoDB locking resources inside the **shared-services** account.

### 1. Create S3 Buckets
```bash
aws s3api create-bucket \
  --bucket ecommerce-platform-tfstate \
  --region us-east-1 \
  --acl private \
  --object-lock-enabled-for-bucket

aws s3api create-bucket \
  --bucket ecommerce-platform-artifacts \
  --region us-east-1 \
  --acl private
```
- Enable default encryption (SSE-KMS) with a dedicated CMK.
- Turn on versioning and intelligent tiering.
- Attach bucket policy to allow only the Terraform role and AWS Config to read.

### 2. Create DynamoDB Lock Table
```bash
aws dynamodb create-table \
  --table-name tf-state-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --sse-specification Enabled=true,SSEType=KMS
```

### 3. Provision IAM Roles
- `role/SharedServicesTerraform` (shared account) and `role/ProdTerraform` (prod account).
- Trust policy allows GitHub Actions OIDC provider (`token.actions.githubusercontent.com`) with repo constraint.
- Inline policy permits `s3:GetObject`, `dynamodb:PutItem`, `sts:AssumeRole` into workload accounts.

### 4. Configure GitHub OIDC
- Add AWS provider under **Settings → Security → OIDC**.
- Update `.github/workflows/terraform.yml` with the AWS role ARN(s).

### 5. Tagging & Guardrails
- Tag all resources with `Environment`, `CostCenter`, `Owner`, `DataClassification`.
- Enable AWS Config, GuardDuty, Security Hub before Terraform apply for consistent baselines.

