output "s3_vpc_endpoint_id" {
  description = "The ID of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.id
}

output "s3_vpc_endpoint_state" {
  description = "The state of the S3 VPC endpoint"
  value       = aws_vpc_endpoint.s3.state
}

output "ecr_api_vpc_endpoint_id" {
  description = "The ID of the ECR API VPC endpoint"
  value       = aws_vpc_endpoint.ecr_api.id
}

output "ecr_dkr_vpc_endpoint_id" {
  description = "The ID of the ECR DKR VPC endpoint"
  value       = aws_vpc_endpoint.ecr_dkr.id
}

output "ssm_vpc_endpoint_id" {
  description = "The ID of the SSM VPC endpoint"
  value       = aws_vpc_endpoint.ssm.id
}

output "ec2messages_vpc_endpoint_id" {
  description = "The ID of the EC2 Messages VPC endpoint"
  value       = aws_vpc_endpoint.ec2messages.id
}

output "ssmmessages_vpc_endpoint_id" {
  description = "The ID of the SSM Messages VPC endpoint"
  value       = aws_vpc_endpoint.ssmmessages.id
}

output "ec2_vpc_endpoint_id" {
  description = "The ID of the EC2 VPC endpoint"
  value       = aws_vpc_endpoint.ec2.id
}

output "sts_vpc_endpoint_id" {
  description = "The ID of the STS VPC endpoint"
  value       = aws_vpc_endpoint.sts.id
}

output "logs_vpc_endpoint_id" {
  description = "The ID of the CloudWatch Logs VPC endpoint"
  value       = aws_vpc_endpoint.logs.id
}

output "monitoring_vpc_endpoint_id" {
  description = "The ID of the CloudWatch Monitoring VPC endpoint"
  value       = aws_vpc_endpoint.monitoring.id
}

output "all_vpc_endpoint_ids" {
  description = "Map of all VPC endpoint IDs"
  value = {
    s3          = aws_vpc_endpoint.s3.id
    ecr_api     = aws_vpc_endpoint.ecr_api.id
    ecr_dkr     = aws_vpc_endpoint.ecr_dkr.id
    ssm         = aws_vpc_endpoint.ssm.id
    ec2messages = aws_vpc_endpoint.ec2messages.id
    ssmmessages = aws_vpc_endpoint.ssmmessages.id
    ec2         = aws_vpc_endpoint.ec2.id
    sts         = aws_vpc_endpoint.sts.id
    logs        = aws_vpc_endpoint.logs.id
    monitoring  = aws_vpc_endpoint.monitoring.id
  }
}
