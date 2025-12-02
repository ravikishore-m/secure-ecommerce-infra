variable "name" {
  description = "Prefix for security resources"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "securityhub_standards" {
  description = "List of Security Hub standard ARNs"
  type        = list(string)
  default     = []
}

variable "waf_allowed_country_codes" {
  description = "Country codes allowed (others blocked) - empty allows all"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

