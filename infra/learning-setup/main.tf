terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Single AZ for cost savings
locals {
  az = "ap-south-1a"
  tags = {
    Project = "Learning"
    Environment = "dev"
  }
}

# VPC with single AZ
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = merge(local.tags, { Name = "learning-vpc" })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags = merge(local.tags, { Name = "learning-igw" })
}

# Public subnet only (no NAT Gateway cost)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "learning-public-subnet" })
}

# Route table for public subnet
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(local.tags, { Name = "learning-public-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Security group for K3s
resource "aws_security_group" "k3s" {
  name_prefix = "learning-k3s-"
  vpc_id      = aws_vpc.main.id

  # SSH
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP/HTTPS
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "learning-k3s-sg" })
}

# Key pair for SSH
resource "aws_key_pair" "learning" {
  key_name   = "learning-key"
  public_key = file("~/.ssh/id_rsa.pub") # Generate with: ssh-keygen -t rsa
  tags       = local.tags
}

# EC2 instance with K3s (FREE TIER)
resource "aws_instance" "k3s" {
  ami                    = "ami-0f58b397bc5c1f2e8" # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"              # FREE TIER
  key_name              = aws_key_pair.learning.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = aws_subnet.public.id

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl
    
    # Install K3s (lightweight Kubernetes)
    curl -sfL https://get.k3s.io | sh -
    
    # Install Docker
    apt-get install -y docker.io
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    
    # Make kubeconfig accessible
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    
    echo "K3s setup complete!"
  EOF

  tags = merge(local.tags, { Name = "learning-k3s-node" })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "learning-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.db.id]
  tags       = merge(local.tags, { Name = "learning-db-subnet-group" })
}

# Additional subnet for RDS (requires 2 AZs)
resource "aws_subnet" "db" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = merge(local.tags, { Name = "learning-db-subnet" })
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "learning-rds-"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s.id]
  }

  tags = merge(local.tags, { Name = "learning-rds-sg" })
}

# RDS MySQL (FREE TIER)
resource "aws_db_instance" "main" {
  identifier     = "learning-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro" # FREE TIER
  
  allocated_storage     = 20 # FREE TIER
  max_allocated_storage = 20
  storage_type          = "gp2"
  storage_encrypted     = false # Encryption costs extra
  
  db_name  = "learningdb"
  username = "admin"
  password = "learning123!" # Use random password in production
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 0    # No backups to save cost
  backup_window          = null
  maintenance_window     = null
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = merge(local.tags, { Name = "learning-rds" })
}

# Outputs
output "k3s_public_ip" {
  value = aws_instance.k3s.public_ip
}

output "ssh_command" {
  value = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.k3s.public_ip}"
}

output "rds_endpoint" {
  value = aws_db_instance.main.endpoint
}

output "estimated_monthly_cost" {
  value = "₹0 (if within free tier limits)"
}