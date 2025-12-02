variable "name" {
  description = "Observability stack name"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Tags to apply"
  type        = map(string)
  default     = {}
}

variable "alert_endpoints" {
  description = "List of email endpoints for SNS subscriptions"
  type        = list(string)
  default     = []
}

