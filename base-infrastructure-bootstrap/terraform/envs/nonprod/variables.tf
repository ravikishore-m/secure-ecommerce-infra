variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "nonprod"
}

variable "owner" {
  description = "Owner tag"
  type        = string
  default     = "platform-team"
}

variable "assume_role_arn" {
  description = "Role ARN to assume for this environment"
  type        = string
  default     = ""
}

variable "alert_emails" {
  description = "List of email addresses for alert subscriptions"
  type        = list(string)
  default     = []
}

variable "github_repositories" {
  description = "GitHub repositories allowed to deploy (org/repo)"
  type        = list(string)
  default     = []
}

variable "create_github_oidc_provider" {
  description = "Whether to create GitHub OIDC provider"
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN"
  type        = string
  default     = ""
}

variable "root_domain" {
  description = "Primary Route53 domain for this environment"
  type        = string
  default     = "demo-ecommerce.internal"
}

variable "create_hosted_zone" {
  description = "Create Route53 hosted zone"
  type        = bool
  default     = true
}

variable "cognito_domain_prefix" {
  description = "Cognito hosted domain prefix"
  type        = string
  default     = "ecommerce-demo"
}

variable "dummy_user_email" {
  description = "Bootstrap Cognito user email"
  type        = string
  default     = "demo@ecommerce.internal"
}

variable "dummy_user_temp_password" {
  description = "Temporary password for bootstrap user"
  type        = string
  default     = "ChangeMe123!"
}

