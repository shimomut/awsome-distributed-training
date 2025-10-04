output "private_subnet_ids" {
  description = "IDs of the private subnets for EKS control plane"
  value       = aws_subnet.private[*].id
}

output "private_node_subnet_id" {
  description = "ID of the private subnet for EKS node groups"
  value       = aws_subnet.private_node.id
}

output "private_node_route_table_id" {
  description = "ID of the route table for EKS node subnets"
  value       = aws_route_table.private_node.id
}

output "all_private_subnet_ids" {
  description = "All private subnet IDs (control plane + node subnets)"
  value       = concat(aws_subnet.private[*].id, [aws_subnet.private_node.id])
}