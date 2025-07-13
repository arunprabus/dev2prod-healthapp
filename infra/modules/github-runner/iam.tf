# Use existing IAM role
data "aws_iam_role" "runner_role" {
  name = "health-app-runner-role-${var.network_tier}"
}

# Use existing instance profile
data "aws_iam_instance_profile" "runner_profile" {
  name = "health-app-runner-profile-${var.network_tier}"
}