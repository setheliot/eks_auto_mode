# AWS Provider configuration
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.8"
    }
  }
}
provider "aws" {
  region = var.aws_region
}

data "aws_caller_identity" "current" {}

locals {
  prefix     = "eks-auto-mode"
  prefix_env = "${local.prefix}-${var.env_name}"

  cluster_name    = "${local.prefix_env}-cluster"
  cluster_version = var.eks_cluster_version

  aws_account = data.aws_caller_identity.current.account_id

  ebs_claim_name = "ebs-volume-pv-claim"
}

# Remote backend for storing Terraform state
terraform {
  backend "s3" {
    bucket         = "seliot-terraform-state-bucket-arpio1"
    key            = "eks-auto-mode-infra/terraform.tfstate"
    dynamodb_table = "terraform-lock"
    region         = "us-east-1"
    encrypt        = false
  }
}

