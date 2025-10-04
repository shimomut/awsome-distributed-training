output "vpc_id" {
  description = "The ID of the VPC"
  value       = aws_vpc.main.id
}

output "vpc_cidr" {
  description = "The CIDR block of the VPC"
  value       = aws_vpc.main.cidr_block
}

output "public_subnet_1_id" {
  description = "The ID of the first public subnet"
  value       = length(aws_subnet.public_1) > 0 ? aws_subnet.public_1[0].id : null
}

output "public_subnet_2_id" {
  description = "The ID of the second public subnet"
  value       = length(aws_subnet.public_2) > 0 ? aws_subnet.public_2[0].id : null
}

output "nat_gateway_1_id" {
  description = "The ID of the first NAT Gateway"
  value       = length(aws_nat_gateway.nat_1) > 0 ? aws_nat_gateway.nat_1[0].id : null
}

output "nat_gateway_2_id" {
  description = "The ID of the second NAT Gateway"
  value       = length(aws_nat_gateway.nat_2) > 0 ? aws_nat_gateway.nat_2[0].id : null
}

output "internet_gateway_id" {
  description = "The ID of the Internet Gateway"
  value       = length(aws_internet_gateway.main) > 0 ? aws_internet_gateway.main[0].id : null
}

output "public_route_table_id" {
  description = "The ID of the public route table"
  value       = length(aws_route_table.public) > 0 ? aws_route_table.public[0].id : null
}

output "nat_gateway_1_eip" {
  description = "The Elastic IP address of the first NAT Gateway"
  value       = length(aws_eip.nat_1) > 0 ? aws_eip.nat_1[0].public_ip : null
}

output "nat_gateway_2_eip" {
  description = "The Elastic IP address of the second NAT Gateway"
  value       = length(aws_eip.nat_2) > 0 ? aws_eip.nat_2[0].public_ip : null
}

output "availability_zones" {
  description = "List of availability zones used in the VPC"
  value       = length(aws_subnet.public_1) > 0 && length(aws_subnet.public_2) > 0 ? [aws_subnet.public_1[0].availability_zone, aws_subnet.public_2[0].availability_zone] : data.aws_availability_zones.available.names
}
