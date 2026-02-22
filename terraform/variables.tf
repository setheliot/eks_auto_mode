# Define environment stage name
variable "env_name" {
  description = "Unique identifier for tfvars configuration used"
  type        = string
}


# Define the instance type for EKS nodes
### Not yet implemented -- Auto Mode manages what instances you get
variable "instance_type" {
  description = "Instance type for EKS worker nodes"
  type        = string
  default     = "t3.micro"
}

# AWS Region to deploy the EKS cluster
variable "aws_region" {
  description = "AWS region to deploy the EKS cluster"
  type        = string
  default     = "us-east-1"
}

# EKS version
variable "eks_cluster_version" {
  description = "EKS version"
  type        = string
  default     = "1.35"
}

# Use ALB - can set this to false for to get NLB
### NLB not yet implemented. If false you get no load balancer
variable "use_alb" {
  description = "When true, uses AWS Auto to create ALB. When false an NLB is created"
  type        = bool
  default     = true
}