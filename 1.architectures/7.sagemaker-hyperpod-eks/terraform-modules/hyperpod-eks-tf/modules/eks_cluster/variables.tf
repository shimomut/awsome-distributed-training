variable "resource_name_prefix" {
  description = "Prefix to be used for all resources created by this module"
  type        = string
  default     = "sagemaker-hyperpod-eks"
}

variable "eks_cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version for the EKS cluster"
  type        = string
  default     = "1.31"
}

variable "security_group_id" {
  description = "ID of the security group for the EKS cluster"
  type        = string
}

variable "private_subnet_ids" {
  description = "IDs of the private subnets for EKS control plane"
  type        = list(string)
}

variable "private_node_subnet_id" {
  description = "ID of the private subnet for EKS node groups"
  type        = string
}
