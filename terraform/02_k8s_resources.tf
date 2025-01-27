###############
#
# Resources in the Kubernetes Cluster such as StorageClass
#
# Logical order: 01 
##### "Logical order" refers to the order a human would think of these executions
##### (although Terraform will determine actual order executed)
#


#
# Setup the Kubernetes provider
# Can only be configured after the EKS cluster is created

# Data provider for cluster auth
data "aws_eks_cluster_auth" "cluster_auth" {
  name = module.eks.cluster_name
}

# Kubernetes provider
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cluster_auth.token
}


# EKS Auto mode has its own EBS CSI driver
# So there is not need to install one

# EKS Auto Mode takes care of IAM permissions
# There is not need to attach AmazonEBSCSIDriverPolicy to the EKS Node IAM Role

#
# EBS Persistent volume
# (This creates the PVC - the volume gets created when the pod attempts to mount it)

resource "kubernetes_storage_class" "ebs" {
  metadata {
    name = "ebs-storage-class"
    annotations = {
      "storageclass.kubernetes.io/is-default-class" = "true"
    }
  }

  storage_provisioner = "ebs.csi.eks.amazonaws.com" # This the setting for EKS Auto Mode
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type      = "gp3"
    encrypted = "true"
  }
}

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
}

# This will wait until a pod needs it, and then create a PersistentVolume