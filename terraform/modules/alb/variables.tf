variable "prefix_env" {
  description = "prefix used to name resources"
  type        = string
}

variable "app_name" {
  description = "Application name"
  type        = string
}

# AWS Region where EKS cluster is located
variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
}

variable "cluster_name" {
  description = "Name of EKS Cluster where ALB is to be deployed"
  type        = string
}

