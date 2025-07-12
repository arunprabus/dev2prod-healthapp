# IAM resources for GitHub runner
resource "aws_iam_role" "runner_role" {
  name = "health-app-runner-role-${var.network_tier}"
  
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
  
  tags = {
    Name = "health-app-runner-role-${var.network_tier}"
    Environment = var.network_tier
    Project = "health-app"
  }
}

# Session Manager policy
resource "aws_iam_role_policy_attachment" "runner_ssm_policy" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Custom policy for runner operations
resource "aws_iam_role_policy" "runner_policy" {
  name = "health-app-runner-policy-${var.network_tier}"
  role = aws_iam_role.runner_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject", 
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}",
          "arn:aws:s3:::${var.s3_bucket}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:*:*"
      }
    ]
  })
}

# Instance profile
resource "aws_iam_instance_profile" "runner_profile" {
  name = "health-app-runner-profile-${var.network_tier}"
  role = aws_iam_role.runner_role.name
  
  tags = {
    Name = "health-app-runner-profile-${var.network_tier}"
    Environment = var.network_tier
    Project = "health-app"
  }
}