
# Remote backend for storing Terraform state for this deployment (the LBC)
# This is redundant with the definition in ../eks-cluster/providers.tf
terraform {
  backend "s3" {
    bucket         = "seliot-terraform-state-bucket-arpio1"
    key            = "eks-auto-mode/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    region         = "us-east-1"
    encrypt        = true
  }
}

locals {
  prefix     = "eks-auto-mode"
  prefix_env = "${local.prefix}-${var.env_name}"
}

# Infrastructure remote backend - created by the terraform in ../eks-cluster
# We use the remote backend state to retrieve the infrastructure outputs created by eks-cluster
# We must pull from the appropriate workspace that corresponds to the environment stage we are deploying
# Terraform is weird and won't accept a `workspace` value in config, so instead we use it to form the S3 key
data "terraform_remote_state" "infra" {
  backend = "s3"
  config = {
    bucket = "seliot-terraform-state-bucket-arpio1"
    key    = "env:/${var.env_name}/${prefix}/terraform.tfstate"
    region = "us-east-1"
  }
}

#
# Get the AWS Region and cluster info from the infrastructure remote backend state
locals {
  region                 = data.terraform_remote_state.infra.outputs.aws_region
  cluster_name           = data.terraform_remote_state.infra.outputs.eks_cluster_name
  cluster_endpoint       = data.terraform_remote_state.infra.outputs.eks_cluster_endpoint
}

provider "aws" {
  region = local.region
}

# EKS Cluster Data Source
data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.infra.outputs.eks_cluster_name
}

locals {
  cluster_certificate_authority_data = data.aws_eks_cluster.cluster.certificate_authority[0].data
}

#
# Data provider for cluster auth
data "aws_eks_cluster_auth" "cluster_auth" {
  name = local.cluster_name
}

#
# Kubernetes provider
provider "kubernetes" {
  host                   = local.cluster_endpoint
  cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}

#
# Helm provider for the cluster
# Generate Authentication Token for the Cluster
provider "helm" {
  kubernetes {
    host                   = local.cluster_endpoint
    cluster_ca_certificate = base64decode(local.cluster_certificate_authority_data)
    token                  = data.aws_eks_cluster_auth.cluster_auth.token
  }
}