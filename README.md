# AWS EKS **Auto Mode** Terraform demo

This repo provides the Terraform configuration to deploy a demo app running on an AWS EKS Cluster with **Auto Mode** _enabled_, using best practices. This was created as an _educational_ tool to learn about EKS **Auto Mode** and Terraform. It is _not_ recommended that this configuration be used in production without further assessment to ensure it meets organization requirements.

To learn more about AWS EKS **Auto Mode**, see the [AWS Documentation](https://docs.aws.amazon.com/eks/latest/userguide/automode.html). EKS **Auto Mode** automates:
* **Compute**: It creates new nodes when pods can't fit onto existing ones, and identifies low utilization nodes for deletion.
* **Networking**: It configures AWS Load Balancers for Kubernetes Service and Ingress resources, to expose cluster apps to the internet.
* **Storage**: It creates EBS Volumes to back Kubernetes storage resources.

In these Terraform files, comments describe how AWS EKS **Auto Mode** simplifies and changes deployment. You can search for "_**EKS Auto Mode**_" to find these comments.

## Blog post
There is a blog post that complements this repo:

**[Amazon EKS Auto Mode ENABLED - Build your super-powered cluster](https://community.aws/content/2sV2SNSoVeq23OvlyHN2eS6lJfa/amazon-eks-auto-mode-enabled-build-your-super-powered-cluster)**

This blog posts goes into detail on the changes introduced by EKS Auto Mode, and what Auto Mode can (and cannot) do

## Deployed resources

This Terraform configuration deploys the following resources:
* AWS EKS Cluster with **Auto Mode** _enabled_, using Amazon EC2 nodes
* Amazon DynamoDB table
* Amazon Elastic Block Store (EBS) volume used as attached storage for the Kubernetes cluster (a `PersistentVolume`)
* Demo "guestbook" application, deployed via containers
* Application Load Balancer (ALB) to access the app

Plus several other supporting resources, as shown in the following diagram:

![architecture](images/architecture.jpg)

## How to use

Run all commands from an environment that has
* Terraform installed
* AWS CLI installed
* AWS credentials configured for the target account

### Option 1. For those familiar with using Terraform
1. Update the S3 bucket and DynamoDB table used for Terraform backend state here: [backend.tf](terraform/backend.tf). Instructions are in the comments in that file.
1. Choose one of the `tfvars` configuration files in the [terraform/environment](terraform/environment) directory, or create a new one. The environment name `env_name` should be unique to each `tfvars` configuration file. You can also set the AWS Region in the configuration file.
1. `cd` into the `terraform` directory
1. Initialize Terraform
    ```bash
    terraform init
    ```

1. Set the terraform workspace to the same value as the environment name `env_name` for the `tfvars` configuration file you are using.
   * If this is your first time running then use 
     ```bash
     terraform workspace new <env_name>
     ```
   * On subsequent uses, use
     ```bash
     terraform workspace select <env_name>
     ```
1. Generate the plan and review it
   ```bash
   terraform plan -var-file=environment/<selected tfvars file>
   ```

1. Deploy the resources
   ```bash
   terraform apply -var-file=environment/<selected tfvars file> -auto-approve
   ```

Under **Outputs** there may be a value for `alb_dns_name`. If not, then 
* you can wait a few seconds and re-run the `terraform apply` command, or
* you can look up the value in your EKS cluster by examining the `Ingress` Kubernetes resource

Use this DNS name to access the app.  Use `http://` (do _not_ use https). It may take about a minute after initial deployment for the application to start working.

If you want to experiment and make changes to the Terraform, you should be able to start at step 3.

### Option 2. Automatic configuration and execution

1. Update the S3 bucket and DynamoDB table used for Terraform backend state here: [backend.tf](terraform/backend.tf). Instructions are in the comments in that file.
1. Choose one of the `tfvars` configuration files in the [terraform/environment](terraform/environment) directory, or create a new one. The environment name `env_name` should be unique to each `tfvars` configuration file. You can also set the AWS Region in the configuration file.
1. Run the following commands:
```bash
cd scripts

./ex_cluster_deploy.sh
```


### Tear-down (clean up) all the resources created

#### Scripted

```bash
cd scripts

./cleanup_cluster.sh \
    -var-file=environment/<selected tfvars file>
```

#### Do it yourself

```bash
terraform init
terraform workspace select <env_name>
```

```bash
terraform destroy \
    -auto-approve \
    -target=kubernetes_deployment_v1.guestbook_app_deployment \
    -var-file=environment/<selected tfvars file>

terraform destroy \
    -auto-approve \
    -target=kubernetes_persistent_volume_claim_v1.ebs_pvc \
    -var-file=environment/<selected tfvars file>

terraform destroy \
    -auto-approve \
    -var-file=environment/<selected tfvars file>
```

To understand why this requires three separate `destroy` operations, [see this](docs/cleanup.md#tear-down-clean-up-all-the-resources-created). 

### Known issues
* [Known issues](docs/known_issues.md)
---
I welcome feedback or bug reports (use GitHub issues) and Pull Requests.

[MIT License](LICENSE)