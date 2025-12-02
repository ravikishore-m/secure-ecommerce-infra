variable "name" {
  description = "Name prefix for VPC resources"
  type        = string
}

variable "cidr_block" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "azs" {
  description = "List of availability zones to span"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "List of public subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "private_app_subnet_cidrs" {
  description = "List of private app subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "private_data_subnet_cidrs" {
  description = "List of private data subnet CIDRs (one per AZ)"
  type        = list(string)
}

variable "enable_flow_logs" {
  description = "Toggle VPC flow logs"
  type        = bool
  default     = true
}

variable "flow_log_destination_arn" {
  description = "Optional destination ARN for flow logs (CloudWatch log group or S3)"
  type        = string
  default     = null
}

variable "flow_log_traffic_type" {
  description = "Traffic type to capture for flow logs"
  type        = string
  default     = "ALL"
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

