variable "identifier" {
  description = "Identifier for the RDS instance"
  type        = string
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "15.5"
}

variable "instance_class" {
  description = "Instance class"
  type        = string
}

variable "allocated_storage" {
  description = "Initial storage in GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Max autoscaling storage in GB"
  type        = number
}

variable "multi_az" {
  description = "Deploy multi-AZ"
  type        = bool
  default     = true
}

variable "db_name" {
  description = "Initial database name"
  type        = string
}

variable "username" {
  description = "Master username"
  type        = string
}

variable "kms_key_arn" {
  description = "KMS key for storage encryption"
  type        = string
}

variable "subnet_ids" {
  description = "Private data subnet IDs"
  type        = list(string)
}

variable "vpc_id" {
  description = "VPC ID for SG"
  type        = string
}

variable "allowed_cidr_blocks" {
  description = "CIDR blocks allowed to access DB"
  type        = list(string)
  default     = []
}

variable "allowed_security_group_ids" {
  description = "Security groups allowed to access DB"
  type        = list(string)
  default     = []
}

variable "backup_retention" {
  description = "Backup retention days"
  type        = number
  default     = 7
}

variable "performance_insights_enabled" {
  description = "Enable Performance Insights"
  type        = bool
  default     = true
}

variable "monitoring_interval" {
  description = "Enhanced monitoring interval (in seconds)"
  type        = number
  default     = 60
}

variable "monitoring_role_arn" {
  description = "Existing IAM role ARN for enhanced monitoring"
  type        = string
}

variable "deletion_protection" {
  description = "Enable deletion protection"
  type        = bool
  default     = true
}

variable "environment" {
  description = "Environment label (nonprod/prod)"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

