# Placeholder for additional IAM Roles for Service Accounts (IRSA)
# Example: roles for external-dns, cert-manager, or custom apps

data "aws_iam_policy_document" "dummy" {
  statement {
    actions   = ["sts:AssumeRole"]
    resources = ["*"]
  }
}
