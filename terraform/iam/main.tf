terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Data source for EKS cluster OIDC issuer
data "aws_eks_cluster" "cluster" {
  name = var.cluster_name
}

data "tls_certificate" "cluster" {
  url = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# OIDC Identity Provider for EKS
resource "aws_iam_openid_connect_provider" "eks" {
  count = var.create_oidc_provider ? 1 : 0

  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.cluster.certificates[0].sha1_fingerprint]
  url             = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer

  tags = var.common_tags
}

# IAM Role for Health API Service Account
resource "aws_iam_role" "health_api_role" {
  name = "${var.cluster_name}-health-api-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = var.create_oidc_provider ? aws_iam_openid_connect_provider.eks[0].arn : var.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:sub" = "system:serviceaccount:${var.namespace}:${var.service_account_name}"
            "${replace(data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = merge(var.common_tags, {
    Name = "${var.cluster_name}-health-api-role"
  })
}

# IAM Policy for DynamoDB access
resource "aws_iam_policy" "dynamodb_policy" {
  name        = "${var.cluster_name}-health-api-dynamodb-policy"
  description = "Policy for Health API to access DynamoDB tables"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
          "dynamodb:BatchGetItem",
          "dynamodb:BatchWriteItem"
        ]
        Resource = [
          var.health_profiles_table_arn,
          "${var.health_profiles_table_arn}/index/*",
          var.file_uploads_table_arn,
          "${var.file_uploads_table_arn}/index/*"
        ]
      }
    ]
  })

  tags = var.common_tags
}

# IAM Policy for S3 access (for file uploads)
resource "aws_iam_policy" "s3_policy" {
  name        = "${var.cluster_name}-health-api-s3-policy"
  description = "Policy for Health API to access S3 bucket"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          var.s3_bucket_arn,
          "${var.s3_bucket_arn}/*"
        ]
      }
    ]
  })

  tags = var.common_tags
}

# Attach DynamoDB policy to role
resource "aws_iam_role_policy_attachment" "dynamodb_policy_attachment" {
  role       = aws_iam_role.health_api_role.name
  policy_arn = aws_iam_policy.dynamodb_policy.arn
}

# Attach S3 policy to role
resource "aws_iam_role_policy_attachment" "s3_policy_attachment" {
  role       = aws_iam_role.health_api_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}