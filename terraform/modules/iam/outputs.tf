output "github_actions_role_arn" {
  value = aws_iam_role.github_actions.arn
}

output "github_oidc_provider_arn" {
  value = var.create_github_oidc_provider ? aws_iam_openid_connect_provider.github[0].arn : var.github_oidc_provider_arn
}

