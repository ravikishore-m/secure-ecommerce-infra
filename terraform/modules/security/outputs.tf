output "waf_arn" {
  value = aws_wafv2_web_acl.edge.arn
}

output "guardduty_detector_id" {
  value = aws_guardduty_detector.this.id
}

output "config_bucket" {
  value = aws_s3_bucket.config.bucket
}

