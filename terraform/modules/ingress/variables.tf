variable "name" {
  description = "ALB name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "Public subnet IDs for ALB"
  type        = list(string)
}

variable "certificate_arn" {
  description = "ACM certificate ARN for HTTPS listener"
  type        = string
}

variable "routes" {
  description = "Map of routes (path prefix) to target group definitions"
  type = map(object({
    priority = number
    path     = string
    port     = optional(number, 80)
    protocol = optional(string, "HTTP")
  }))
  default = {}
}

variable "health_check_path" {
  description = "Path for ALB health checks"
  type        = string
  default     = "/healthz"
}

variable "waf_arn" {
  description = "Optional WAF ACL ARN to associate"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

