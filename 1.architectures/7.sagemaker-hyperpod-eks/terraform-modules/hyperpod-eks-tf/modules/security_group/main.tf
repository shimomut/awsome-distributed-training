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
  
  # Check for broad VPC egress rules (generalized for all VPC CIDRs)
  # This prevents duplicate rule creation by detecting if existing security group
  # already has the VPC CIDR egress rules we want to create
  has_vpc_egress_rules = var.create_new_sg ? false : (
    # Count existing rules that match our VPC CIDR criteria
    length([
      for r in local.rules : r
      if r.rule.is_egress &&                    # Only outbound rules
         r.rule.ip_protocol == "-1" &&          # All protocols
         r.rule.from_port == -1 &&              # All ports (from)
         r.rule.to_port == -1 &&                # All ports (to)
         # Check if rule's CIDR matches any of our VPC CIDRs
         contains(
           # Create list of all VPC CIDRs (primary + additional)
           concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block), 
           r.rule.cidr_ipv4
         )
    ]) >= 
    # Compare against total number of VPC CIDRs
    # If we have rules for ALL VPC CIDRs, return true (rules exist)
    length(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block))
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

# Generalized VPC egress rules for all VPC CIDR blocks
# Creates one egress rule per VPC CIDR block (primary + additional CIDRs)
# Only creates rules if: creating new SG OR existing SG doesn't have these rules
resource "aws_vpc_security_group_egress_rule" "vpc_cidrs" {
  # Dynamic for_each: creates rules for all VPC CIDRs or empty set if rules exist
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? 
    # Create list of all VPC CIDRs (primary + additional)
    toset(concat([data.aws_vpc.selected.cidr_block], data.aws_vpc.selected.cidr_block_associations[*].cidr_block)) : 
    # Empty set - don't create any rules (they already exist)
    toset([])
  
  description       = "Allow all egress traffic to VPC CIDR ${each.value}"
  from_port         = -1          # All ports
  to_port           = -1          # All ports  
  ip_protocol       = "-1"        # All protocols
  cidr_ipv4         = each.value  # Current VPC CIDR from for_each
  security_group_id = local.security_group_id
}

# AWS S3 service egress rules for ECR image layers
# ECR stores container image layers in S3, so pods need HTTPS access to S3 IP ranges
# This resolves ImagePullBackOff errors in closed network environments
resource "aws_vpc_security_group_egress_rule" "s3_https" {
  # Create rules for all S3 IP ranges in current region, or empty set if VPC rules exist
  for_each = var.create_new_sg || !local.has_vpc_egress_rules ? 
    toset(data.aws_ip_ranges.s3.cidr_blocks) : 
    toset([])
  
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
