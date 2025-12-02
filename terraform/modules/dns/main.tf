locals {
  zone_id   = var.create_zone ? aws_route53_zone.this[0].zone_id : var.existing_zone_id
  zone_name = var.create_zone ? aws_route53_zone.this[0].name : var.root_domain
}

resource "aws_route53_zone" "this" {
  count = var.create_zone ? 1 : 0

  name = var.root_domain

  tags = var.tags
}

resource "aws_acm_certificate" "this" {
  domain_name               = var.root_domain
  validation_method         = "DNS"
  subject_alternative_names = var.subject_alternative_names

  tags = var.tags
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options :
    dvo.domain_name => {
      name   = dvo.resource_record_name
      type   = dvo.resource_record_type
      record = dvo.resource_record_value
    }
  }

  zone_id = local.zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

