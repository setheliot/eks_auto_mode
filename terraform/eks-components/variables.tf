# Define environment stage name
# Also used as Terraform workspace
variable "env_name" {
  description = "Unique identifier for tfvars configuration used. Should match other deployments for same env"
  type        = string
}