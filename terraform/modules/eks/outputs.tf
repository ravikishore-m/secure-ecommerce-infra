output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "cluster_security_group_id" {
  value = aws_security_group.cluster.id
}

output "cluster_oidc_provider_arn" {
  value       = one(aws_iam_openid_connect_provider.this[*].arn)
  description = "OIDC provider ARN for IRSA"
}

output "node_group_role_arns" {
  value = { for k, role in aws_iam_role.node : k => role.arn }
}

