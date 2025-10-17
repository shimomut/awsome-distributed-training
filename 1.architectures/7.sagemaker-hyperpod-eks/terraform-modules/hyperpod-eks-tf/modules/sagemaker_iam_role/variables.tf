variable "resource_name_prefix" {
  description = "Prefix to be used for all resources created by this module"
  type        = string
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket used to store the cluster lifecycle scripts"
  type        = string
}

variable "tags" {
  description = "Additional tags for all resources"
  type        = map(string)
  default     = {}
}

variable "kms_key_arn" {
  description = "The ARN of the KMS key for encryption/decryption operations. If not provided, KMS permissions will not be added."
  type        = string
  default     = ""
}
