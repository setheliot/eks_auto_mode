#
# VPC and Subnets
data "aws_availability_zones" "available" {
  # Exclude local zones
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

module "vpc" {

  source  = "terraform-aws-modules/vpc/aws"
  version = ">=5.17.0"

  name            = "${local.prefix_env}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = slice(data.aws_availability_zones.available.names, 0, 3)
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "Name" = "${local.prefix_env}-public-subnet"
    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "Name" = "${local.prefix_env}-private-subnet"
    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    Terraform   = "true"
    Environment = local.prefix_env
    always_zero = length(null_resource.check_workspace) # hack to get module to depend on workspace check
  }
}

#
# EKS Cluster using Auto Mode
module "eks" {

  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = local.cluster_name
  cluster_version = local.cluster_version

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_compute_config = {
    enabled    = true
    node_pools = ["general-purpose"]
  }

  # Cluster access entry
  enable_cluster_creator_admin_permissions = true

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
    always_zero = length(null_resource.check_workspace) # hack to get module to depend on workspace check
  }
}

locals {
  node_security_group_id = module.eks.node_security_group_id
}

# Create VPC endpoints (Private Links) for SSM Session Manager access to nodes
resource "aws_security_group" "vpc_endpoint_sg" {
  name   = "vpc-endpoint-sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    description     = "Allow EKS Nodes to access VPC Endpoints"
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [local.node_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}

resource "aws_vpc_endpoint" "private_link_ssm" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssm"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}

resource "aws_vpc_endpoint" "private_link_ssmmessages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ssmmessages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}

resource "aws_vpc_endpoint" "private_link_ec2messages" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ec2messages"
  vpc_endpoint_type   = "Interface"
  security_group_ids  = [aws_security_group.vpc_endpoint_sg.id]
  subnet_ids          = module.vpc.private_subnets
  private_dns_enabled = true

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}

# DynamoDb table
resource "aws_vpc_endpoint" "private_link_dynamodb" {

  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.dynamodb"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}

resource "aws_dynamodb_table" "guestbook" {
  depends_on       = [null_resource.check_workspace]
  name             = "${local.prefix_env}-guestbook"
  billing_mode     = "PROVISIONED"
  read_capacity    = 2
  write_capacity   = 2
  hash_key         = "GuestID"
  range_key        = "Name"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"

  attribute {
    name = "GuestID"
    type = "S"
  }

  attribute {
    name = "Name"
    type = "S"
  }

  tags = {
    Environment = local.prefix_env
    Terraform   = "true"
  }
}
