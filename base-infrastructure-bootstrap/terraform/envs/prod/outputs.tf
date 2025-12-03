output "vpc_id" {
  value = module.network.vpc_id
}

output "private_app_subnet_ids" {
  value = module.network.private_app_subnet_ids
}

output "private_data_subnet_ids" {
  value = module.network.private_data_subnet_ids
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_oidc_arn" {
  value = module.eks.cluster_oidc_provider_arn
}

output "kms_general_arn" {
  value = aws_kms_key.general.arn
}

output "route53_zone_id" {
  value = module.dns.zone_id
}

output "route53_zone_name" {
  value = module.dns.zone_name
}

output "acm_certificate_arn" {
  value = module.dns.certificate_arn
}

output "alb_dns_name" {
  value = module.ingress.alb_dns_name
}

output "alb_zone_id" {
  value = module.ingress.alb_zone_id
}

output "ingress_target_group_arns" {
  value = module.ingress.target_group_arns
}

output "cognito_user_pool_id" {
  value = module.cognito.user_pool_id
}

output "cognito_user_pool_client_id" {
  value = module.cognito.user_pool_client_id
}

output "cognito_domain" {
  value = module.cognito.user_pool_domain
}

output "github_actions_role_arn" {
  value = module.iam.github_actions_role_arn
}

output "app_deployer_role_arn" {
  value = aws_iam_role.app_deployer.arn
}

output "app_irsa_role_arn" {
  value = aws_iam_role.app_irsa.arn
}

