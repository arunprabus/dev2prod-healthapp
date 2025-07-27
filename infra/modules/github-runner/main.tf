# Create key pair if it doesn't exist
resource "aws_key_pair" "github_runner" {
  key_name   = "health-app-${var.network_tier}-key"
  public_key = var.ssh_public_key
  
  lifecycle {
    ignore_changes = [public_key]
  }
}

# EBS volume for runner logs
resource "aws_ebs_volume" "runner_logs" {
  availability_zone = data.aws_subnet.runner_subnet.availability_zone
  size              = 10  # 10GB for logs (FREE TIER)
  type              = "gp2"
  encrypted         = false
  
  tags = {
    Name = "health-app-runner-logs-${var.network_tier}"
    Purpose = "Runner logs storage"
    Environment = var.network_tier
    Project = "health-app"
  }
}

data "aws_subnet" "runner_subnet" {
  id = var.subnet_id
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type              = "t2.micro"
  key_name                   = aws_key_pair.github_runner.key_name
  vpc_security_group_ids     = [aws_security_group.runner.id]
  subnet_id                  = var.subnet_id
  associate_public_ip_address = true  # Ensure public IP for internet access
  iam_instance_profile       = aws_iam_instance_profile.runner_profile.name
  
  user_data_replace_on_change = true
  user_data = base64encode(templatefile("${path.module}/user_data_simple.sh", {
    github_token = var.repo_pat
    github_repo  = var.repo_name
    network_tier = var.network_tier
  }))
  
  tags = {
    Name = "health-app-runner-${var.network_tier}"
    Type = "github-runner"
    NetworkTier = var.network_tier
    Environment = var.network_tier
    Project = "health-app"
  }
}

# Attach EBS volume to runner
resource "aws_volume_attachment" "runner_logs" {
  device_name = "/dev/sdf"
  volume_id   = aws_ebs_volume.runner_logs.id
  instance_id = aws_instance.github_runner.id
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

resource "aws_security_group" "runner" {
  name_prefix = "github-runner-sg-${var.network_tier}-"
  vpc_id = var.vpc_id
  
  # Allow all outbound traffic (needed for github.com, package downloads, etc.)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "All outbound traffic for GitHub API and package downloads"
  }
  
  # SSH access from VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access from VPC"
  }
  

  
  # HTTPS outbound specifically for GitHub (redundant but explicit)
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS for GitHub API access"
  }
  
  tags = {
    Name = "health-app-runner-sg-${var.network_tier}"
    Purpose = "GitHub runner internet access"
    Environment = var.network_tier
    Project = "health-app"
  }
}



