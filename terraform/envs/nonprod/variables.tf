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

variable "bootstrap_state_bucket" {
  description = "S3 bucket containing the base infrastructure state"
  type        = string
  default     = "ecommerce-platform-tfstate"
}

variable "bootstrap_state_prefix" {
  description = "Key prefix for base state files"
  type        = string
  default     = "base"
}

