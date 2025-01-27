# AWS EKS Auto Mode does not seem to help with any of this
# (unless I am missing something)


#
# Use IRSA to give pods the necesssary permissions
#

#
# Create trust policy to be used by Service Account role

locals {
  ddb_serviceaccount = "ddb-${local.prefix_env}-serviceaccount"
  oidc               = module.eks.oidc_provider
}


data "aws_iam_policy_document" "service_account_trust_policy" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = ["arn:aws:iam::${local.aws_account}:oidc-provider/${local.oidc}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:sub"
      values   = ["system:serviceaccount:default:${local.ddb_serviceaccount}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${local.oidc}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}


resource "aws_iam_role" "ddb_access_role" {
  name = "ddb-${local.prefix_env}-${var.aws_region}-role"

  assume_role_policy = data.aws_iam_policy_document.service_account_trust_policy.json

  description = "Role used by Service Account to access DynamoDB"

  tags = {
    Name = "IRSA role used by DDB"
  }
}

resource "aws_iam_role_policy_attachment" "ddb_access_attachment" {
  role       = aws_iam_role.ddb_access_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
}


#
# Create service account
resource "kubernetes_service_account" "ddb_serviceaccount" {
  metadata {
    name      = local.ddb_serviceaccount
    namespace = "default"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.ddb_access_role.arn
    }
  }
}

