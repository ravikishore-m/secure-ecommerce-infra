variable "region" {
  description = "AWS region for bootstrap resources"
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Project identifier used for tagging/naming"
  type        = string
  default     = "ecommerce-platform"
}

variable "state_bucket_name" {
  description = "Name of the Terraform remote state bucket"
  type        = string
  default     = "ecommerce-platform-tfstate"
}

variable "artifact_bucket_name" {
  description = "Bucket for CI/CD artifacts and backups"
  type        = string
  default     = "ecommerce-platform-artifacts"
}

variable "trusted_role_arns" {
  description = "Roles allowed to access the remote state bucket"
  type        = list(string)
  default     = []
}

variable "state_lock_retention_days" {
  description = "Number of days to retain each Terraform state object via S3 Object Lock (immutability window)"
  type        = number
  default     = 1
}

