
#
# EBS Persistent volume
# (This creates the PVC - the volume gets created when the pod attempts to mount it)


resource "kubernetes_storage_class" "ebs" {
  metadata {
    name = "ebs-storage-class"
  }

  storage_provisioner = "ebs.csi.aws.com"
  reclaim_policy      = "Retain"
  volume_binding_mode = "WaitForFirstConsumer"
  parameters = {
    type   = "gp3"
    fsType = "ext4"
  }
}

resource "kubernetes_persistent_volume_claim_v1" "ebs_pvc" {
  metadata {
    name = "ebs-volume-claim"
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