variable "name" {
  description = "Transit Gateway name prefix"
  type        = string
}

variable "vpc_id" {
  description = "VPC to attach"
  type        = string
}

variable "subnet_ids" {
  description = "Subnets for TGW attachment (typically private)"
  type        = list(string)
}

variable "tags" {
  description = "Tags"
  type        = map(string)
  default     = {}
}

