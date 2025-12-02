resource "aws_prometheus_workspace" "this" {
  alias = "${var.name}-amp"
  tags  = var.tags
}

resource "aws_cloudwatch_log_group" "eks_audit" {
  name              = "/aws/eks/${var.name}/audit"
  retention_in_days = 365
  tags              = var.tags
}

resource "aws_sns_topic" "alerts" {
  name = "${var.name}-alert-topic"
  tags = var.tags
}

resource "aws_sns_topic_subscription" "email" {
  for_each  = toset(var.alert_endpoints)
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = each.value
}

resource "aws_iam_role" "grafana" {
  name               = "${var.name}-grafana-role"
  assume_role_policy = data.aws_iam_policy_document.grafana_assume.json
  tags               = var.tags
}

data "aws_iam_policy_document" "grafana_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["grafana.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "grafana_access" {
  statement {
    effect = "Allow"
    actions = [
      "aps:ListWorkspaces",
      "aps:DescribeWorkspace",
      "aps:QueryMetrics",
      "aps:GetSeries",
      "aps:GetLabels",
      "aps:GetMetricMetadata",
      "logs:GetLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups"
    ]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "grafana_access" {
  name   = "${var.name}-grafana-data"
  role   = aws_iam_role.grafana.id
  policy = data.aws_iam_policy_document.grafana_access.json
}

resource "aws_grafana_workspace" "this" {
  name                      = "${var.name}-amg"
  account_access_type       = "CURRENT_ACCOUNT"
  authentication_providers  = ["AWS_SSO"]
  permission_type           = "SERVICE_MANAGED"
  role_arn                  = aws_iam_role.grafana.arn
  data_sources              = ["PROMETHEUS", "CLOUDWATCH", "XRAY"]
  notification_destinations = ["SNS"]
  tags                      = var.tags
}

