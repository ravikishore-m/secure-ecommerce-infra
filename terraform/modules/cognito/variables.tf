variable "project_name" {
  description = "Project prefix for naming"
  type        = string
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "domain_prefix" {
  description = "Hosted Cognito domain prefix"
  type        = string
}

variable "dummy_user_email" {
  description = "Email for bootstrap demo user"
  type        = string
}

variable "dummy_user_temp_password" {
  description = "Temp password for demo user"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

