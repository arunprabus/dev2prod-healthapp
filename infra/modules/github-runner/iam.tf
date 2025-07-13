# Create IAM role for GitHub runner
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
}

# Create instance profile
resource "aws_iam_instance_profile" "runner_profile" {
  name = "health-app-runner-profile-${var.network_tier}"
  role = aws_iam_role.runner_role.name
}

# Add Session Manager policy
resource "aws_iam_role_policy_attachment" "runner_ssm_policy" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}