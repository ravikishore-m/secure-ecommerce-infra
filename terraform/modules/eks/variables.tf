variable "cluster_name" {
  description = "EKS cluster name"
  type        = string
}

variable "kubernetes_version" {
  description = "EKS control plane version"
  type        = string
  default     = "1.29"
}

variable "vpc_id" {
  description = "VPC ID for the cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "Private subnet IDs for node groups and control plane endpoints"
  type        = list(string)
}

variable "public_subnet_ids" {
  description = "Public subnet IDs (used for load balancers if needed)"
  type        = list(string)
  default     = []
}

variable "node_groups" {
  description = "Map of node group configurations"
  type = map(object({
    desired_size   = number
    min_size       = number
    max_size       = number
    instance_types = list(string)
    capacity_type  = string
    subnets        = optional(list(string))
    labels         = optional(map(string))
    taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })))
  }))
}

variable "enable_irsa" {
  description = "Create IAM OIDC provider for IRSA"
  type        = bool
  default     = true
}

variable "enable_control_plane_logs" {
  description = "Enable EKS control plane logs"
  type        = bool
  default     = true
}

variable "kms_key_arn" {
  description = "Customer managed key ARN for secrets encryption"
  type        = string
}

variable "tags" {
  description = "Resource tags"
  type        = map(string)
  default     = {}
}

