locals {
  github_conditions = [
    for repo in var.github_repositories :
    {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${repo}:environment:${var.environment}"]
    }
  ]
  github_oidc_provider_arn = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
}

resource "aws_iam_openid_connect_provider" "github" {
  count = var.create_github_oidc_provider ? 1 : 0

  client_id_list  = [var.github_oidc_audience]
  thumbprint_list = var.github_oidc_thumbprints
  url             = var.github_oidc_url
  tags            = var.tags
}

data "aws_iam_policy_document" "github_assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [local.github_oidc_provider_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = [var.github_oidc_audience]
    }

    dynamic "condition" {
      for_each = local.github_conditions
      content {
        test     = condition.value.test
        variable = condition.value.variable
        values   = condition.value.values
      }
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name                 = "${var.name}-${var.environment}-gha"
  assume_role_policy   = data.aws_iam_policy_document.github_assume_role.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Environment = var.environment
  })
}

data "aws_iam_policy_document" "github_inline" {
  statement {
    sid    = "TerraformStateAccess"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:ListBucket",
      "s3:DeleteObject"
    ]
    resources = ["arn:aws:s3:::*tf-state*", "arn:aws:s3:::*tf-state*/*"]
  }

  statement {
    sid     = "AssumeWorkloadRoles"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      "arn:aws:iam::*:role/*Terraform",
      "arn:aws:iam::*:role/*Deployment"
    ]
  }

  dynamic "statement" {
    for_each = var.additional_policy_statements
    content {
      effect    = statement.value.effect
      actions   = statement.value.actions
      resources = statement.value.resources
    }
  }
}

resource "aws_iam_role_policy" "github_inline" {
  name   = "${aws_iam_role.github_actions.name}-inline"
  role   = aws_iam_role.github_actions.id
  policy = data.aws_iam_policy_document.github_inline.json
}

