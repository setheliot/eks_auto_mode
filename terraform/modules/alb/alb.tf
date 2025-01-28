# *** EKS Auto mode has its own load balancer driver ***
# So there is no need to configure AWS Load Balancer Controller

# *** EKS Auto Mode takes care of IAM permissions ***
# There is no need to attach AWSLoadBalancerControllerIAMPolicy to the EKS Node IAM Role

# Kubernetes Ingress Resource for ALB via AWS Load Balancer Controller
resource "kubernetes_ingress_v1" "ingress_alb" {
  metadata {
    name      = "${var.prefix_env}-ingress-alb"
    namespace = "default"
    annotations = {
      "alb.ingress.kubernetes.io/scheme" = "internet-facing"
      "alb.ingress.kubernetes.io/tags"   = "Terraform=true,Environment=${var.prefix_env}"
    }
  }

  spec {
    # this matches the name of IngressClass.
    # this can be omitted if you have a default ingressClass in cluster: the one with ingressclass.kubernetes.io/is-default-class: "true"  annotation
    ingress_class_name = "${var.prefix_env}-ingressclass-alb"

    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service_v1.service_alb.metadata[0].name
              port {
                number = 8080
              }
            }
          }
        }
      }
    }
  }
}

# Kubernetes Service for the App
resource "kubernetes_service_v1" "service_alb" {
  metadata {
    name      = "${var.prefix_env}-service-alb"
    namespace = "default"
    labels = {
      app = var.app_name
    }
  }

  spec {
    selector = {
      app = var.app_name
    }

    port {
      port        = 8080
      target_port = 8080
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_ingress_class_v1" "ingressclass_alb" {
  depends_on   = [null_resource.apply_ingressclassparams_manifest]
  metadata {
    name = "${var.prefix_env}-ingressclass-alb"

    # Use this annotation to set an IngressClass as Default
    # If an Ingress doesn't specify a class, it will use the Default
    annotations = {
      "ingressclass.kubernetes.io/is-default-class" = "true"
    }
  }

  spec {
    # Configures the IngressClass to use EKS Auto Mode
    controller = "eks.amazonaws.com/alb"
    parameters {
      api_group = "eks.amazonaws.com"
      kind      = "IngressClassParams"
      # Use the name of the IngressClassParams
      name = "${var.prefix_env}-ingressclassparams-alb"
    }
  }
}


#
# Here is an example of where *** AWS EKS Auto Mode *** makes things _more_ complicated when using Terraform.
# The IngressClassParams resources is _not_ a standard Kubernetes resource, therefore it gets created as a
# custom resource in Kubernetes.
#
# There is no Terraform resource in the Kubernetes provider to create it
#
# A cleaner, more Terraform-native solution is to use the `kubernetes_manifest` resource (see commented out block
# below) to create the IngressClassParams resource. However, this resource just assumes the EKS cluster already exists
# and fails with error during `terraform plan`.
#
# Therefore we go with the less elegant solution below
# *** This requires the aws cli is installed
#
# The "good solution" would be for an IngressClassParams resource be added to the aws provider in Terraform.

resource "null_resource" "apply_ingressclassparams_manifest" {
  provisioner "local-exec" {
    command = <<EOT
    aws eks --region ${var.aws_region} update-kubeconfig --name ${var.cluster_name}
    kubectl apply -f - <<EOF
apiVersion: eks.amazonaws.com/v1
kind: IngressClassParams
metadata:
  name: "${var.prefix_env}-ingressclassparams-alb"
spec:
  scheme: internet-facing
EOF
    EOT
  }
}

/*
resource "kubernetes_manifest" "ingress_class_params" {
  manifest = {
    "apiVersion" = "eks.amazonaws.com/v1"
    "kind"       = "IngressClassParams"
    "metadata" = {
      "name" = "${var.prefix_env}-ingressclassparams-alb"
    }
    "spec" = {
      "scheme" = "internet-facing"
    }
  }
}
*/