resource_name_prefix = "sagemaker-hpeks-closed-8"
aws_region           = "us-east-2"

# Closed Network Configuration
# Set to true to deploy in closed network mode (no internet gateway, NAT gateways, or EIPs)
# This is suitable for air-gapped environments or networks with strict security requirements
closed_network = true

# Infrastructure created by hpeks-closed-network/existing-vpc-tf
# Module control - use existing infrastructure
create_vpc_module = false
create_private_subnet_module = false
create_eks_subnets_module = false
create_security_group_module = true

# Existing infrastructure IDs
existing_vpc_id = "vpc-001f1cd16e12cb23d"
existing_private_subnet_id = "subnet-06f938e3482ecaef8"
existing_private_route_table_id = "rtb-0c0261bc276c1168d"
existing_eks_private_subnet_ids = ["subnet-043d1a117b656ac07","subnet-0a3969a3bd276f240"]
existing_eks_private_node_subnet_id = "subnet-0c548ce7d4b423b86"
existing_eks_private_node_route_table_id = "rtb-00dd9df68238a03d6"
existing_security_group_id = ""

# Availability zone configuration
availability_zone_id = "us-east-2b"

# EKS Cluster Module Variables
create_eks_module            = true
kubernetes_version           = "1.32"
eks_cluster_name             = "eks-closed-8"

# EKS Availability Zones and Subnets Configuration
# Specify the exact availability zones for EKS cluster subnets
eks_availability_zones       = ["use2-az1", "use2-az2"]
# Specify the CIDR blocks for EKS private subnets (must match number of AZs)
eks_private_subnet_cidrs     = ["10.192.7.0/24", "10.192.8.0/24"]
eks_private_node_subnet_cidr = "10.192.9.0/24"

existing_eks_cluster_name              = ""

# S3 Bucket Module Variables
create_s3_bucket_module = true
existing_s3_bucket_name = ""

# VPC Endpoints Module Variables
create_vpc_endpoints_module     = true

# Lifecycle Script Module Variables
create_lifecycle_script_module = true

# SageMaker IAM Role Module Variables
create_sagemaker_iam_role_module = true
existing_sagemaker_iam_role_name = ""

# Helm Chart Module Variables
create_helm_chart_module = true
helm_repo_base_path      = "../../../../../sagemaker-hyperpod-cli"
helm_repo_path           = "helm_chart/HyperPodHelmChart"
namespace                = "kube-system"
helm_release_name        = "hyperpod-dependencies"

# HyperPod Cluster Module Variables
create_hyperpod_module = true
hyperpod_cluster_name  = "hpeks-closed-8"
node_recovery          = "Automatic"
node_provisioning_mode = "Continuous"

# For the instance_groups variable, you'll need to define specific groups. Here's an example:
instance_groups = {
  instance-group-1 = {
    instance_type             = "ml.g5.8xlarge"
    instance_count            = 2
    ebs_volume_size_in_gb     = 100
    threads_per_core          = 2
    enable_stress_check       = false
    enable_connectivity_check = false
    lifecycle_script          = "on_create.sh"
  }
}
