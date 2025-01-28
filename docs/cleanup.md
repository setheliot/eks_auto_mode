# Tear-down (clean up) all the resources created

To tear-down all resources and clean up your environment, run these commands

```bash
terraform init

terraform workspace select <env_name>

terraform state rm kubernetes_persistent_volume_claim_v1.ebs_pvc

terraform destroy  -var-file=environment/<selected tfvars file>
```

Normally, tear-down would be as simple as a `terraform destroy` command. However, in this case the `PersistentVolumeController` (PVC) cannot be deleted using that command.  Here is why.

With `terraform apply`, the following occurs:
* The Terraform configuration creates a `Deployment` kubernetes resource. 
* The Kubernetes cluster will then proceed to create a `ReplicaSet` which in turn will deploy pods.
* The Terraform configuration creates a `PersistentVolumeController` (PVC) kubernetes resource.
* Based on the Terraform configuration of the `Deployment`, the pods reference the `PersistentVolumeController` to create an EBS-backed Persistent Volume.

Then with `terraform destroy` we encounter the following:
* Terraform deletes `Deployment`. The deletion completes quickly. The `ReplicaSet` is also deleted.
* However, it is observed sometimes that the pods are _not_ deleted. I do not know why, and this is worth further investigation.
* Terraform attempts to delete the `PersistentVolumeController`, but must wait because it is referenced by the pods, which are still running. It eventually times out and fails

The solution using `terraform state rm` works as follows
* Terraform does not attempt to delete the `PersistentVolumeController`
* The `PersistentVolumeController` will get destroyed anyway when the cluster is destroyed

Side-effects
* The EBS-backed Persistent Volume is orphaned
* You can delete it manually

If you forget and run `terraform destroy` without first running `terraform state rm`, then no problem:
* It might actually just work.
* But if it fails with an error trying to delete `kubernetes_persistent_volume_claim_v1.ebs_pvc`, then just run the two commands at the top of this page and it will work fine.

---
## What is going on here?

It appears that deletion of some component of the VPC prevents the cluster controller from deleting the pods after the `Deployment` and `ReplicaSet` are deleted.

This in turn prevents the `PersistentVolumeClaim` for deleting, because it is being used by the pods.

It is possible the critical VPC component impacts communication between the Kubernetes control plane and the AWS control plane, or something similar.


The problem with `terraform destroy` can be solved by adding the following to the `module "eks"` block:

```
  depends_on = [ module.vpc ]
```

### But.... this introduced new problems

* It takes much longer to deploy resources with `apply`

* Deploying resources with `apply` becomes unreliable. 

  The change in dependency and timing introduces a new issue where Terraform attempts to create Kubernetes resources _before_ the proper RBAC configurations are applied (e.g., ClusterRoles, RoleBindings). These resources then fail with errors like

    ```
    Error: serviceaccounts is forbidden: User "arn:aws:sts::12345678912:assumed-role/MyAdmin" cannot create resource "serviceaccounts" in API group "" in the namespace "default"
    ```

  After the `apply` failure, running the same exact `apply` command then succeeds, because by that time the RBAC have propagated. 

* Time to tear-down resources with `destroy` also seems longer

### The goal of this repository is to show how to create these resources

Since creation is more important than deletion, here, this repo will not use the `depends_on` _fix_.

Also this repo aims to show best practices, and in general is is a best practice to let Terraform determine dependency relationships.