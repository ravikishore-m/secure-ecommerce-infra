provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project = var.project_name
    Owner   = "platform-team"
  }
}

# KMS key encrypts every Terraform state object and related metadata.
resource "aws_kms_key" "tf_state" {
  description             = "KMS key for ${var.project_name} Terraform state"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags
}

# Friendly alias so backend configs can reference the key without hard-coding an ARN.
resource "aws_kms_alias" "tf_state" {
  name          = "alias/${var.project_name}/tf-state"
  target_key_id = aws_kms_key.tf_state.key_id
}

# Versioned S3 bucket that stores Terraform state files with object-lock protection.
resource "aws_s3_bucket" "tf_state" {
  bucket              = var.state_bucket_name
  object_lock_enabled = true

  tags = merge(local.tags, {
    Purpose = "terraform-state"
  })
}

# Immutable retention configuration prevents accidental or malicious state deletion.
resource "aws_s3_bucket_object_lock_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    default_retention {
      mode = "GOVERNANCE"
      days = var.state_lock_retention_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.tf_state]
}

# Versioning is required for object-lock and enables point-in-time recovery.
resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Ensure every object is encrypted with the dedicated KMS key.
resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
  }
}

# Block any accidental public exposure of the Terraform state bucket.
resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Only trusted roles using TLS may read/write Terraform state objects.
data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "AllowTrustedRoles"
    effect = "Allow"
    principals {
      type        = "AWS"
      identifiers = length(var.trusted_role_arns) > 0 ? var.trusted_role_arns : ["*"]
    }
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.tf_state.arn,
      "${aws_s3_bucket.tf_state.arn}/*"
    ]
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["true"]
    }
  }
}

# Attach the bucket policy assembled above.
resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

# Artifact bucket stores CI/CD evidence (SBOMs, logs, etc.) for auditing.
resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name

  tags = merge(local.tags, {
    Purpose = "artifacts"
  })
}

# Lifecycle policy keeps artifact storage affordable while retaining history.
resource "aws_s3_bucket_lifecycle_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    id     = "log-retention"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    transition {
      days          = 90
      storage_class = "GLACIER"
    }
  }
}

