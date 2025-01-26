# Fetch the current workspace name
locals {
  current_workspace = terraform.workspace
}

# Log a failure and quit if the workspace does not match `var.env_name`
resource "null_resource" "check_workspace" {
  count = local.current_workspace != var.env_name ? 1 : 0

  provisioner "local-exec" {
    command = <<EOT
      echo "Error: Current workspace (${local.current_workspace}) does not match expected environment name (${var.env_name}). Exiting...";
      exit 1
    EOT
  }
}
