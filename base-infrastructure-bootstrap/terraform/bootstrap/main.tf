provider "aws" {
  region = var.region
}

locals {
  tags = {
    Project = var.project_name
    Owner   = "platform-team"
  }
}

resource "aws_kms_key" "tf_state" {
  description             = "KMS key for ${var.project_name} Terraform state"
  deletion_window_in_days = 10
  enable_key_rotation     = true
  tags                    = local.tags
}

resource "aws_kms_alias" "tf_state" {
  name          = "alias/${var.project_name}/tf-state"
  target_key_id = aws_kms_key.tf_state.key_id
}

resource "aws_s3_bucket" "tf_state" {
  bucket = var.state_bucket_name

  tags = merge(local.tags, {
    Purpose = "terraform-state"
  })
}

resource "aws_s3_bucket_versioning" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.tf_state.arn
    }
  }
}

resource "aws_s3_bucket_public_access_block" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

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

resource "aws_s3_bucket_policy" "tf_state" {
  bucket = aws_s3_bucket.tf_state.id
  policy = data.aws_iam_policy_document.state_bucket.json
}

resource "aws_dynamodb_table" "locks" {
  name         = var.lock_table_name
  billing_mode = "PAY_PER_REQUEST"

  attribute {
    name = "LockID"
    type = "S"
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.tf_state.arn
  }

  tags = merge(local.tags, {
    Purpose = "terraform-locking"
  })
}

resource "aws_s3_bucket" "artifacts" {
  bucket = var.artifact_bucket_name

  tags = merge(local.tags, {
    Purpose = "artifacts"
  })
}

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

