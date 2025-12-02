variable "name" {
  description = "Prefix for IAM resources"
  type        = string
}

variable "environment" {
  description = "Environment label"
  type        = string
}

variable "github_repositories" {
  description = "List of GitHub repos allowed to assume the role (org/repo)"
  type        = list(string)
}

variable "github_oidc_audience" {
  description = "Audience for GitHub OIDC (typically sts.amazonaws.com)"
  type        = string
  default     = "sts.amazonaws.com"
}

variable "create_github_oidc_provider" {
  description = "Create the GitHub OIDC provider if not already present"
  type        = bool
  default     = false
}

variable "github_oidc_provider_arn" {
  description = "Existing GitHub OIDC provider ARN (if create flag is false)"
  type        = string
  default     = ""

  validation {
    condition     = var.create_github_oidc_provider || var.github_oidc_provider_arn != ""
    error_message = "Set github_oidc_provider_arn when create_github_oidc_provider is false."
  }
}

variable "github_oidc_thumbprints" {
  description = "Thumbprints for GitHub OIDC"
  type        = list(string)
  default     = ["6938fd4d98bab03faadb97b34396831e3780aea1"]
}

variable "github_oidc_url" {
  description = "GitHub OIDC URL"
  type        = string
  default     = "https://token.actions.githubusercontent.com"
}

variable "permissions_boundary_arn" {
  description = "Optional permissions boundary"
  type        = string
  default     = null
}

variable "additional_policy_statements" {
  description = "Additional IAM policy statements to append"
  type = list(object({
    effect    = string
    actions   = list(string)
    resources = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Common tags"
  type        = map(string)
  default     = {}
}

