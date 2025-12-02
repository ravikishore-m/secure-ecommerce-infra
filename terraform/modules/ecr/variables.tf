variable "repositories" {
  description = "Map of repository name => config"
  type = map(object({
    scan_on_push = optional(bool, true)
    mutable_tags = optional(bool, false)
  }))
}

variable "kms_key_arn" {
  description = "KMS key ARN for image encryption"
  type        = string
}

variable "lifecycle_policy" {
  description = "Lifecycle policy JSON (applied to all repos)"
  type        = string
  default     = <<EOF
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Retain last 30 images",
      "selection": {
        "tagStatus": "any",
        "countType": "imageCountMoreThan",
        "countNumber": 30
      },
      "action": {
        "type": "expire"
      }
    }
  ]
}
EOF
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

