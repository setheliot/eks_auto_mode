###############
#
# Resources in the Kubernetes Cluster such as StorageClass
#
# Logical order: 02 
##### "Logical order" refers to the order a human would think of these executions
##### (although Terraform will determine actual order executed)
#

# *** EKS Auto mode has its own EBS CSI driver ***
# There is no need to install one

# *** EKS Auto Mode takes care of IAM permissions ***
# There is no need to attach AmazonEBSCSIDriverPolicy to the EKS Node IAM Role

#
# EBS Storage Class

resource "kubernetes_storage_class" "ebs" {
  metadata {
    name = "ebs-storage-class"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  # *** This setting specifies the EKS Auto Mode provisioner ***
  storage_provisioner = "ebs.csi.eks.amazonaws.com"

  # The reclaim policy for a PersistentVolume tells the cluster 
  # what to do with the volume after it has been released of its claim
  reclaim_policy = "Delete"

  # Delay the binding and provisioning of a PersistentVolume until a Pod 
  # using the PersistentVolumeClaim is created 
  volume_binding_mode = "WaitForFirstConsumer"

  # see StorageClass Parameters Reference here:
  # https://docs.aws.amazon.com/eks/latest/userguide/create-storage-class.html
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }

  # Give time for the cluster to complete (controllers, RBAC and IAM propagation)
  # See https://github.com/setheliot/eks_auto_mode/blob/main/docs/separate_configs.md
  depends_on = [module.eks]
}


#
# EBS Persistent Volume Claim

resource "kubernetes_persistent_volume_claim_v1" "ebs_pvc" {
  metadata {
    name = local.ebs_claim_name
  }

  spec {
    # Volume can be mounted as read-write by a single node
    #
    # ReadWriteOnce access mode should enable multiple pods to 
    # access it when the pods are running on the same node.
    #
    # Using EKS Auto Mode it appears to only allow one pod to access it
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "ebs-storage-class"

  }

  # Setting this allows `Terraform apply` to continue
  # Otherwise it would hang here waiting for claim to bind to a pod
  wait_until_bound = false

  # Give time for the cluster to complete (controllers, RBAC and IAM propagation)
  # See https://github.com/setheliot/eks_auto_mode/blob/main/docs/separate_configs.md
  depends_on = [module.eks]
}

# This will create the PVC, which will wait until a pod needs it, and then create a PersistentVolume