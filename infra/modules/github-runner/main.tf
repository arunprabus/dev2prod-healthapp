# Create key pair from GitHub secrets
resource "random_id" "key_suffix" {
  byte_length = 4
}

resource "aws_key_pair" "github_runner" {
  key_name   = "health-app-key-${var.network_tier}-${random_id.key_suffix.hex}"
  public_key = var.ssh_public_key

  tags = {
    Name = "health-app-key-${var.network_tier}"
    Purpose = "GitHub runner SSH access"
  }
}

resource "aws_instance" "github_runner" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type              = "t2.micro"
  key_name                   = aws_key_pair.github_runner.key_name
  vpc_security_group_ids     = [aws_security_group.runner.id]
  subnet_id                  = var.subnet_id
  associate_public_ip_address = true  # Ensure public IP for internet access
  
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    github_token = var.repo_pat
    github_repo  = var.repo_name
    network_tier = var.network_tier
  }))
  
  tags = {
    Name = "github-runner-${var.network_tier}"
    Type = "github-runner"
    NetworkTier = var.network_tier
  }
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
    Name = "github-runner-sg-${var.network_tier}"
    Purpose = "GitHub runner internet access"
  }
}

output "runner_ip" {
  value = aws_instance.github_runner.private_ip
}

output "runner_public_ip" {
  value = aws_instance.github_runner.public_ip
}