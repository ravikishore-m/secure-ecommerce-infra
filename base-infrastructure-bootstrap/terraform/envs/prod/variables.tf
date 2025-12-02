variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "prod"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "platform-team"
}

variable "assume_role_arn" {
  description = "Role ARN assumed by Terraform"
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "Alert destinations"
  type        = list(string)
  default     = []
}

variable "github_repositories" {
  description = "GitHub repos allowed to assume the role"
  type        = list(string)
  default     = []
}

variable "create_github_oidc_provider" {
  description = "Create GitHub OIDC provider"
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Existing OIDC provider ARN"
  type        = string
  default     = ""
}

variable "root_domain" {
  description = "Primary Route53 domain"
  type        = string
  default     = "demo-ecommerce.prod.internal"
}

variable "create_hosted_zone" {
  description = "Create hosted zone (true) or use an existing zone"
  type        = bool
  default     = true
}

variable "cognito_domain_prefix" {
  description = "Cognito domain prefix"
  type        = string
  default     = "ecommerce-prod"
}

variable "dummy_user_email" {
  description = "Bootstrap Cognito user email"
  type        = string
  default     = "demo@prod.ecommerce"
}

variable "dummy_user_temp_password" {
  description = "Temp password"
  type        = string
  default     = "TempPassword123!"
}

