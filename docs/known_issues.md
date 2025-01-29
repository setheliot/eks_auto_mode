### `terraform apply` fails with authentication errors creating some Kubernetes resources

The following Kubernetes resources fail:
`StorageClass`, `PersistentVolumeClaim`, `ServiceAccount`, `Deployment`

The errors reported for each of these look like this:

```
│ Error: storageclasses.storage.k8s.io is forbidden: User "arn:aws:sts::253490795979:assumed-role/SethAdmin/aws-go-sdk-1738171484847914000" cannot create resource "storageclasses" in API group "storage.k8s.io" at the cluster scope
│
│   with kubernetes_storage_class.ebs,
│   on 02_k8s_resources.tf line 19, in resource "kubernetes_storage_class" "ebs":
│   19: resource "kubernetes_storage_class" "ebs" {
```
#### Cause

Although the EKS Cluster deployment was completed, Terraform attempted to create these resources before all cluster functionality was available. In this case, it could have been due to RBAC Role Bindings not yet being completed.

#### How to fix

Re-run the `terraform apply` command. The cluster has had time to become fully functional and the previously failed resources will succeed.

##### That feels like a workaround. What is the real fix?

* See this note on using [separate distinct Terraform configurations](./separate_configs.md)