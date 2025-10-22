# Get VPC information including all CIDR blocks (primary + additional)
data "aws_vpc" "selected" {
  id = var.vpc_id
}

# Get current AWS region for IP range lookups
data "aws_region" "current" {}

# Get AWS IP ranges for S3 service (needed for ECR image layers)
# ECR stores container image layers in S3, so pods need access to S3 IP ranges
# This data source provides current S3 IP ranges for the region
data "aws_ip_ranges" "s3" {
  regions  = [data.aws_region.current.name]  # Current region only
  services = ["s3"]                          # S3 service IP ranges
}

data "aws_vpc_security_group_rules" "existing" {
  count = var.create_new_sg ? 0 : 1
  filter {
    name   = "group-id"
    values = [var.existing_security_group_id]
  }
}

# Get details for each individual rule
data "aws_vpc_security_group_rule" "rule" {
  for_each = var.create_new_sg ? toset([]) : toset(try(data.aws_vpc_security_group_rules.existing[0].ids, []))
  security_group_rule_id = each.key
}

locals {
  security_group_id = var.create_new_sg ? aws_security_group.no_ingress[0].id : var.existing_security_group_id

  # Get all rule IDs for the security group
  rule_ids = var.create_new_sg ? [] : data.aws_vpc_security_group_rules.existing[0].ids
  
  # Get individual rules
  rules = var.create_new_sg ? [] : [
    for id in local.rule_ids : {
      id = id
      rule = data.aws_vpc_security_group_rule.rule[id]
    }
  ]
  
  # Check for specific rules
  has_intra_sg_ingress = var.create_new_sg ? false : (
    length([
      for r in local.rules : r
      if !r.rule.is_egress && 
         r.rule.ip_protocol == "-1" && 
         r.rule.from_port == -1 &&
         r.rule.to_port == -1 &&
         r.rule.referenced_security_group_id == var.existing_security_group_id
    ]) > 0
  )
  
  has_fsx_lustre_ingress_988 = var.create_new_sg ? false : (
    length([
      for r in local.rules : r
      if !r.rule.is_egress && 
         r.rule.ip_protocol == "tcp" && 
         r.rule.from_port == 988 && 
         r.rule.to_port == 988 && 
         r.rule.referenced_security_group_id == var.existing_security_group_id
    ]) > 0
  )
  
  has_fsx_lustre_ingress_1018_1023 = var.create_new_sg ? false : (
    length([
      for r in local.rules : r
      if !r.rule.is_egress && 
         r.rule.ip_protocol == "tcp" && 
         r.rule.from_port == 1018 && 
         r.rule.to_port == 1023 && 
         r.rule.referenced_security_group_id == var.existing_security_group_id
    ]) > 0
  )
  
  has_intra_sg_egress = var.create_new_sg ? false : (
    length([
      for r in local.rules : r
      if r.rule.is_egress && 
         r.rule.ip_protocol == "-1" && 
         r.rule.from_port == -1 && 
         r.rule.to_port == -1 && 
         r.rule.referenced_security_group_id == var.existing_security_group_id
    ]) > 0
  )
  
  has_internet_egress = var.create_new_sg ? false : (
    length([
      for r in local.rules : r
      if r.rule.is_egress && 
         r.rule.ip_protocol == "-1" && 
         r.rule.from_port == -1 && 
         r.rule.to_port == -1 && 
         r.rule.cidr_ipv4 == "0.0.0.0/0"
    ]) > 0
  )
  
  # Check for specific VPC egress rules (HTTPS, DNS, NTP, kubelet)
  # This prevents duplicate rule creation by detecting if existing security group
  # already has the specific protocol/port VPC CIDR egress rules we want to create
  has_vpc_egress_rules = var.create_new_sg ? false : (
    # Count existing rules that match our specific protocol/port criteria for each VPC CIDR
    length([
      for r in local.rules : r
      if r.rule.is_egress &&                    # Only outbound rules
         # Check for specific protocols and ports we need
         (
           (r.rule.ip_protocol == "tcp" && r.rule.from_port == 443 && r.rule.to_port == 443) ||   # HTTPS
           (r.rule.ip_protocol == "tcp" && r.rule.from_port == 53 && r.rule.to_port == 53) ||     # DNS TCP
           (r.rule.ip_protocol == "udp" && r.rule.from_port == 53 && r.rule.to_port == 53) ||     # DNS UDP
           (r.rule.ip_protocol == "udp" && r.rule.from_port == 123 && r.rule.to_port == 123) ||   # NTP
           (r.rule.ip_protocol == "tcp" && r.rule.from_port == 10250 && r.rule.to_port == 10250)  # kubelet
         ) &&
         # Check if rule's CIDR matches any of our VPC CIDRs
         contains(
           # Create list of all VPC CIDRs (primary + additional)
           concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block), 
           r.rule.cidr_ipv4
         )
    ]) >= 
    # We need 5 rules per VPC CIDR (HTTPS, DNS TCP, DNS UDP, NTP, kubelet)
    (5 * length(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)))
  )
}

resource "aws_security_group" "no_ingress" {
  count = var.create_new_sg ? 1 : 0

  name        = "${var.resource_name_prefix}-no-ingress-sg"
  description = "Security group with no ingress rule"
  vpc_id      = var.vpc_id

  tags = merge(
    {
      Name = "${var.resource_name_prefix}-no-ingress-sg"
    },
    var.tags
  )
}

resource "aws_vpc_security_group_ingress_rule" "intra_sg_ingress" {
  count = var.create_new_sg || !local.has_intra_sg_ingress ? 1 : 0
  
  description                  = "Allow traffic within the security group"
  from_port                    = -1
  to_port                      = -1
  ip_protocol                  = "-1"
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
}

resource "aws_vpc_security_group_egress_rule" "intra_sg_egress" {
  count = var.create_new_sg || !local.has_intra_sg_egress ? 1 : 0
  
  description                  = "Allow traffic within the security group"
  from_port                    = -1
  to_port                      = -1
  ip_protocol                  = "-1"
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
}

# Specific VPC egress rules for EKS required protocols and ports
# Creates targeted rules instead of broad "allow all" for better security

# HTTPS egress to VPC CIDRs (for EKS API, VPC endpoints)
resource "aws_vpc_security_group_egress_rule" "vpc_https" {
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : toset([])
  
  description       = "Allow HTTPS egress to VPC CIDR ${each.value}"
  from_port         = 443         # HTTPS
  to_port           = 443         # HTTPS
  ip_protocol       = "tcp"       # TCP protocol
  cidr_ipv4         = each.value  # Current VPC CIDR
  security_group_id = local.security_group_id
}

# DNS TCP egress to VPC CIDRs (for name resolution)
resource "aws_vpc_security_group_egress_rule" "vpc_dns_tcp" {
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : toset([])
  
  description       = "Allow DNS TCP egress to VPC CIDR ${each.value}"
  from_port         = 53          # DNS
  to_port           = 53          # DNS
  ip_protocol       = "tcp"       # TCP protocol
  cidr_ipv4         = each.value  # Current VPC CIDR
  security_group_id = local.security_group_id
}

# DNS UDP egress to VPC CIDRs (for name resolution)
resource "aws_vpc_security_group_egress_rule" "vpc_dns_udp" {
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : toset([])
  
  description       = "Allow DNS UDP egress to VPC CIDR ${each.value}"
  from_port         = 53          # DNS
  to_port           = 53          # DNS
  ip_protocol       = "udp"       # UDP protocol
  cidr_ipv4         = each.value  # Current VPC CIDR
  security_group_id = local.security_group_id
}

# NTP egress to VPC CIDRs (for time synchronization)
resource "aws_vpc_security_group_egress_rule" "vpc_ntp" {
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : toset([])
  
  description       = "Allow NTP egress to VPC CIDR ${each.value}"
  from_port         = 123         # NTP
  to_port           = 123         # NTP
  ip_protocol       = "udp"       # UDP protocol
  cidr_ipv4         = each.value  # Current VPC CIDR
  security_group_id = local.security_group_id
}

# Kubelet API egress to VPC CIDRs (for EKS node communication)
resource "aws_vpc_security_group_egress_rule" "vpc_kubelet" {
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : toset([])
  
  description       = "Allow kubelet API egress to VPC CIDR ${each.value}"
  from_port         = 10250       # kubelet API
  to_port           = 10250       # kubelet API
  ip_protocol       = "tcp"       # TCP protocol
  cidr_ipv4         = each.value  # Current VPC CIDR
  security_group_id = local.security_group_id
}

# AWS S3 service egress rules for ECR image layers
# ECR stores container image layers in S3, so pods need HTTPS access to S3 IP ranges
# This resolves ImagePullBackOff errors in closed network environments
resource "aws_vpc_security_group_egress_rule" "s3_https" {
  # Create rules for all S3 IP ranges in current region, or empty set if VPC rules exist
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? toset(data.aws_ip_ranges.s3.cidr_blocks) : toset([])
  
  description       = "Allow HTTPS traffic to S3 for ECR image layers"
  from_port         = 443         # HTTPS only
  to_port           = 443         # HTTPS only
  ip_protocol       = "tcp"       # TCP protocol
  cidr_ipv4         = each.value  # Current S3 IP range from AWS IP ranges
  security_group_id = local.security_group_id
}



resource "aws_vpc_security_group_ingress_rule" "fsx_lustre_ingress_988" {
  count = var.create_new_sg || !local.has_fsx_lustre_ingress_988 ? 1 : 0
  
  description                  = "Allows Lustre traffic between FSx for Lustre file servers and Lustre clients"
  from_port                    = 988
  to_port                      = 988
  ip_protocol                  = "tcp"
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
}

resource "aws_vpc_security_group_ingress_rule" "fsx_lustre_ingress_1018_1023" {
  count = var.create_new_sg || !local.has_fsx_lustre_ingress_1018_1023 ? 1 : 0
  
  description                  = "Allows Lustre traffic between FSx for Lustre file servers and Lustre clients"
  from_port                    = 1018
  to_port                      = 1023
  ip_protocol                  = "tcp"
  security_group_id            = local.security_group_id
  referenced_security_group_id = local.security_group_id
}
