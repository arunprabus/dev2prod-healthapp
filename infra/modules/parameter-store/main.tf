resource "aws_ssm_parameter" "app_parameters" {
  for_each = var.parameters

  name  = "/${var.environment}/${var.app_name}/${each.key}"
  type  = each.value.type
  value = each.value.value
  description = each.value.description

  tags = var.tags
}

# Store kubeconfig data in Parameter Store
resource "aws_ssm_parameter" "kubeconfig_server" {
  count = var.kubeconfig_server != "" ? 1 : 0
  
  name  = "/${var.environment}/${var.app_name}/kubeconfig/server"
  type  = "String"
  value = var.kubeconfig_server
  description = "Kubernetes API server endpoint"

  tags = var.tags
}

resource "aws_ssm_parameter" "kubeconfig_token" {
  count = var.kubeconfig_token != "" ? 1 : 0
  
  name  = "/${var.environment}/${var.app_name}/kubeconfig/token"
  type  = "SecureString"
  value = var.kubeconfig_token
  description = "Kubernetes service account token"

  tags = var.tags
}

resource "aws_ssm_parameter" "kubeconfig_ca_cert" {
  count = var.kubeconfig_ca_cert != "" ? 1 : 0
  
  name  = "/${var.environment}/${var.app_name}/kubeconfig/ca-cert"
  type  = "String"
  value = var.kubeconfig_ca_cert
  description = "Kubernetes cluster CA certificate"

  tags = var.tags
}

# IAM role for applications to access parameters
resource "aws_iam_role" "parameter_access" {
  name = "${var.app_name}-${var.environment}-parameter-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "parameter_read" {
  name = "${var.app_name}-${var.environment}-parameter-read"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:PutParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/${var.environment}/${var.app_name}/*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "parameter_access" {
  role       = aws_iam_role.parameter_access.name
  policy_arn = aws_iam_policy.parameter_read.arn
}

resource "aws_iam_instance_profile" "parameter_access" {
  name = "${var.app_name}-${var.environment}-parameter-access"
  role = aws_iam_role.parameter_access.name

  tags = var.tags
}