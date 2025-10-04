variable "vpc_id" {
  description = "The ID of the VPC you wish to use to create VPC endpoints"
  type        = string
}

variable "private_route_table_id" {
  description = "The Id of your private route table"
  type        = string
}

variable "additional_route_table_ids" {
  description = "Additional route table IDs for gateway endpoints (e.g., EKS node route tables)"
  type        = list(string)
  default     = []
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for interface endpoints"
  type        = list(string)
}

variable "vpc_endpoint_security_group_id" {
  description = "Security group ID for VPC interface endpoints"
  type        = string
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

