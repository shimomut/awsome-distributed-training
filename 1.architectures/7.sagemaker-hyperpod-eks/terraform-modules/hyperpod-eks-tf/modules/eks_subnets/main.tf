data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

data "aws_vpc" "selected" {
  id = var.vpc_id
}

data "aws_availability_zones" "available" {
  state = "available"
}

# Convert availability zone IDs to names for subnet creation
data "aws_availability_zone" "selected" {
  count   = length(var.availability_zones) > 0 ? length(var.availability_zones) : length(var.private_subnet_cidrs)
  zone_id = length(var.availability_zones) > 0 ? var.availability_zones[count.index] : null
  name    = length(var.availability_zones) == 0 ? data.aws_availability_zones.available.names[count.index] : null
}

# EKS control plane subnets
resource "aws_subnet" "private" {
  count             = length(var.private_subnet_cidrs)
  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = length(var.availability_zones) > 0 ? data.aws_availability_zone.selected[count.index].name : data.aws_availability_zones.available.names[count.index]

  tags = {
    Name = "${var.resource_name_prefix}-private-subnet-${count.index + 1}"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# EKS node group subnet
resource "aws_subnet" "private_node" {
  vpc_id            = data.aws_vpc.selected.id
  cidr_block        = var.private_node_subnet_cidr
  availability_zone = length(var.availability_zones) > 0 ? data.aws_availability_zone.selected[0].name : data.aws_availability_zones.available.names[0]
  
  tags = {
    Name = "${var.resource_name_prefix}-private-nodes-subnet-1"
    "kubernetes.io/role/internal-elb" = "1"
    "kubernetes.io/cluster/${var.eks_cluster_name}" = "shared"
  }
}

# Route table for node group subnets
resource "aws_route_table" "private_node" {
  vpc_id = data.aws_vpc.selected.id

  tags = {
    Name = "${var.resource_name_prefix}-private-nodes-rt"
  }
}

# Route to NAT gateway (only if not in closed network mode and NAT gateway is provided)
resource "aws_route" "private_node_nat" {
  count                  = var.closed_network ? 0 : 1
  route_table_id         = aws_route_table.private_node.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = var.nat_gateway_id
}

# Associate route table with node subnet
resource "aws_route_table_association" "private_node" { 
  subnet_id      = aws_subnet.private_node.id
  route_table_id = aws_route_table.private_node.id
}