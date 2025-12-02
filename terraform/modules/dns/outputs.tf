output "zone_id" {
  value = local.zone_id
}

output "zone_name" {
  value = local.zone_name
}

output "name_servers" {
  value = var.create_zone ? aws_route53_zone.this[0].name_servers : []
}

output "certificate_arn" {
  value = aws_acm_certificate_validation.this.certificate_arn
}

