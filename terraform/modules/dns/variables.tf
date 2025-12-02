variable "root_domain" {
  description = "Primary DNS name (e.g., ecommerce-demo.com)"
  type        = string
}

variable "create_zone" {
  description = "Create the hosted zone (true) or use an existing zone id"
  type        = bool
  default     = true
}

variable "existing_zone_id" {
  description = "Existing hosted zone ID if create_zone is false"
  type        = string
  default     = ""
}

variable "subject_alternative_names" {
  description = "Additional SANs for the ACM certificate"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Common tags to apply"
  type        = map(string)
  default     = {}
}

