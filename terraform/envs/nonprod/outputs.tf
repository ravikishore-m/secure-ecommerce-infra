output "rds_endpoint" {
  value = module.rds.endpoint
}

output "ecr_repositories" {
  value = module.ecr.repository_urls
}

output "observability_amp_workspace" {
  value = module.observability.amp_workspace_id
}

