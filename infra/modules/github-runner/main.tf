# Create key pair for GitHub runner
resource "aws_key_pair" "github_runner" {
  key_name   = "health-app-runner-${var.network_tier}"
  public_key = var.ssh_public_key
  
  tags = {
    Name = "health-app-runner-${var.network_tier}"
    Environment = var.network_tier
    Project = "health-app"
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
  vpc_security_group_ids     = [aws_security_group.runner.id, aws_security_group.k3s_access.id]
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
  
  # SSH access from VPC (management subnet)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "SSH access from VPC"
  }
  
  tags = {
    Name = "health-app-runner-sg-${var.network_tier}"
    Purpose = "GitHub runner with K3s access"
    Environment = var.network_tier
    Project = "health-app"
  }
}

# Security group for K3s cluster access
resource "aws_security_group" "k3s_access" {
  name_prefix = "health-app-k3s-access-sg-${var.network_tier}-"
  vpc_id = var.vpc_id
  
  # K3s API server access from runner subnet
  egress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = var.k3s_subnet_cidrs
    description = "K3s API server access to clusters"
  }
  
  # SSH access to K3s nodes for kubeconfig retrieval
  egress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.k3s_subnet_cidrs
    description = "SSH access to K3s nodes"
  }
  
  tags = {
    Name = "health-app-k3s-access-sg-${var.network_tier}"
    Purpose = "K3s cluster access from runners"
    Environment = var.network_tier
    Project = "health-app"
  }
}



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
  
  tags = {
    Name = "health-app-runner-role-${var.network_tier}"
    Environment = var.network_tier
    Project = "health-app"
  }
}

# Attach policies to runner role
resource "aws_iam_role_policy_attachment" "runner_ssm" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "runner_s3" {
  role       = aws_iam_role.runner_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"
}

# Create IAM instance profile
resource "aws_iam_instance_profile" "runner_profile" {
  name = "health-app-runner-profile-${var.network_tier}"
  role = aws_iam_role.runner_role.name
  
  tags = {
    Name = "health-app-runner-profile-${var.network_tier}"
    Environment = var.network_tier
    Project = "health-app"
  }
}