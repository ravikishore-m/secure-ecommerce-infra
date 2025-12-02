locals {
  derived_securityhub_standards = length(var.securityhub_standards) > 0 ? var.securityhub_standards : [
    "arn:aws:securityhub:::ruleset/cis-aws-foundations-benchmark/v/1.4.0",
    "arn:aws:securityhub:${var.region}::standards/aws-foundational-security-best-practices/v/1.0.0",
    "arn:aws:securityhub:${var.region}::standards/pci-dss/v/3.2.1"
  ]
}

resource "aws_guardduty_detector" "this" {
  enable = true
  tags   = var.tags
}

resource "aws_securityhub_account" "this" {
  depends_on = [aws_guardduty_detector.this]
  tags       = var.tags
}

resource "aws_securityhub_standards_subscription" "this" {
  for_each      = toset(local.derived_securityhub_standards)
  standards_arn = each.value
}

resource "aws_config_configuration_recorder" "this" {
  name     = "${var.name}-recorder"
  role_arn = aws_iam_role.config.arn

  recording_group {
    all_supported                 = true
    include_global_resource_types = true
  }
}

resource "aws_iam_role" "config" {
  name               = "${var.name}-config-role"
  assume_role_policy = data.aws_iam_policy_document.config_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "config_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["config.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "config_managed" {
  role       = aws_iam_role.config.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSConfigRole"
}

resource "aws_s3_bucket" "config" {
  bucket = "${var.name}-${var.region}-config-logs"
  acl    = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  versioning {
    enabled = true
  }

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true

  tags = var.tags
}

resource "aws_s3_bucket_public_access_block" "config" {
  bucket = aws_s3_bucket.config.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_config_delivery_channel" "this" {
  name           = "${var.name}-delivery"
  s3_bucket_name = aws_s3_bucket.config.bucket

  depends_on = [aws_config_configuration_recorder.this]
}

resource "aws_config_configuration_recorder_status" "this" {
  name       = aws_config_configuration_recorder.this.name
  is_enabled = true

  depends_on = [aws_config_delivery_channel.this]
}

resource "aws_wafv2_web_acl" "edge" {
  name        = "${var.name}-edge-waf"
  description = "Web ACL for CloudFront/ALB"
  scope       = "CLOUDFRONT"
  default_action {
    allow {}
  }

  dynamic "rule" {
    for_each = var.waf_allowed_country_codes
    content {
      name     = "geo-allow"
      priority = 0
      action {
        allow {}
      }
      statement {
        geo_match_statement {
          country_codes = var.waf_allowed_country_codes
        }
      }
      visibility_config {
        cloudwatch_metrics_enabled = true
        metric_name                = "geoAllow"
        sampled_requests_enabled   = true
      }
    }
  }

  rule {
    name     = "aws-common"
    priority = 10
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsCommon"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "aws-bot"
    priority = 20
    override_action {
      none {}
    }
    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesBotControlRuleSet"
        vendor_name = "AWS"
      }
    }
    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "awsBot"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.name}-waf"
    sampled_requests_enabled   = true
  }

  tags = var.tags
}

