output "sagemaker_iam_role_name" {
  description = "SageMaker IAM role Name"
  value       = aws_iam_role.sagemaker_execution_role.name
}

output "sagemaker_iam_role_arn" {
  description = "SageMaker IAM role Arn"
  value       = aws_iam_role.sagemaker_execution_role.arn
}

output "sagemaker_kms_policy_arn" {
  description = "ARN of the KMS policy attached to the SageMaker IAM role (if KMS key ARN was provided)"
  value       = var.kms_key_arn != "" ? aws_iam_policy.sagemaker_kms_policy[0].arn : null
}
