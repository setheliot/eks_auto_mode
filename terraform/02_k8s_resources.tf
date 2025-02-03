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

  reclaim_policy      = "Delete"
  volume_binding_mode = "WaitForFirstConsumer"
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
    access_modes = ["ReadWriteOnce"]

    resources {
      requests = {
        storage = "1Gi"
      }
    }

    storage_class_name = "ebs-storage-class"
  
  }
  wait_until_bound = false

  # Give time for the cluster to complete (controllers, RBAC and IAM propagation)
  # See https://github.com/setheliot/eks_auto_mode/blob/main/docs/separate_configs.md
  depends_on = [module.eks] 
}

# This will create the PVC, which will wait until a pod needs it, and then create a PersistentVolume