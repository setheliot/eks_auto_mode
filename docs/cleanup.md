# Tear-down (clean up) all the resources created - explained


We enforce the following specific order of destruction:
* `Deployment` → `PersistentVolumeClaim` → EKS Cluster

`terraform destroy` requires this order for a clean removal, as the cluster controllers handle necessary cleanup operations.
1. Remove the Deployment first to allow cluster controllers to properly delete the pods.
   - Pods must be deleted before the `PersistentVolumeClaim`; otherwise, the deletion process will hang.
1. Remove the `PersistentVolumeClaim` while the cluster is still active to ensure controllers properly detach and delete the EBS volume.
1. Then delete everything else.

To tear-down all resources and clean up your environment, run these commands

```bash
terraform init

terraform workspace select <env_name>

terraform state rm kubernetes_persistent_volume_claim_v1.ebs_pvc

terraform destroy  -var-file=environment/<selected tfvars file>
```

---
## What is going on here?

When a single `terraform destroy` command is used to destroy everything, it appears that deletion of some _other_ resource that occurs before the destruction of `Deployment` (possibly a component of the VPC) prevents the cluster controller from deleting the pods after the `Deployment` and `ReplicaSet` are deleted.

This in turn prevents the `PersistentVolumeClaim` from deleting, because it is being used by the pods.

It is possible that a critical VPC component impacts communication between the Kubernetes control plane and the AWS control plane, or something similar.

This problem with `terraform destroy` can be solved by adding the following to the `module "eks"` block:

```
  depends_on = [ module.vpc ]
```

### But... this introduced new problems

* It takes much longer to deploy resources with `apply`

* Deploying resources with `apply` becomes unreliable. 

  The change in dependency and timing introduces a new issue where Terraform attempts to create Kubernetes resources _before_ the proper RBAC configurations are applied (e.g., ClusterRoles, RoleBindings). These resources then fail with errors like

    ```
    Error: serviceaccounts is forbidden: User "arn:aws:sts::12345678912:assumed-role/MyAdmin" cannot create resource "serviceaccounts" in API group "" in the namespace "default"
    ```

  After the `apply` failure, running the same exact `apply` command then succeeds, because by that time the RBAC have propagated. 

* Time to tear-down resources with `destroy` also seems longer

### The goal of this repository is to show how to create these resources

For this repo, the focus is on education and simplicity in creating these resources; therefore, it will not use the `depends_on` fix.

Also this repo aims to show best practices, and in general it is a best practice to let Terraform determine dependency relationships.

### How else might we handle this?

Another approach, which may be better for production deployments (and cleanup), is to separate Terraform into two distinct configurations:

1. **Infrastructure Configuration:** Deploys AWS resources such as the VPC, EKS cluster, and DynamoDB table.  
2. **Kubernetes Configuration:** Deploys Kubernetes resources, including application code as part of the Deployment.

This separation ensures that Kubernetes resources can be cleaned up properly while the cluster and VPC remain intact.

For this repo the focus is on education and simplicity to _create_ these resources; therefore, it retains the _single_ Terraform configuration approach.