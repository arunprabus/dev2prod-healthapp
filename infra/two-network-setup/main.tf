terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Use default VPC to avoid VPC limits
data "aws_vpc" "default" {
  default = true
}

# VPC for the network tier (commented out to use default VPC)
# resource "aws_vpc" "main" {
#   cidr_block           = local.vpc_cidr
#   enable_dns_hostnames = true
#   enable_dns_support   = true
#   tags = merge(local.tags, { Name = "${local.name_prefix}-vpc" })
# }

# Internet Gateway
# Use default internet gateway
data "aws_internet_gateway" "default" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Public subnet (no NAT Gateway cost)
resource "aws_subnet" "public" {
  vpc_id                  = data.aws_vpc.default.id
  cidr_block              = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 1)
  availability_zone       = local.az
  map_public_ip_on_launch = true
  tags = merge(local.tags, { Name = "${local.name_prefix}-public-subnet" })
}

# Additional subnet for RDS (requires 2 AZs)
resource "aws_subnet" "db" {
  vpc_id            = data.aws_vpc.default.id
  cidr_block        = cidrsubnet(data.aws_vpc.default.cidr_block, 8, 2)
  availability_zone = "${var.aws_region}b"
  tags = merge(local.tags, { Name = "${local.name_prefix}-db-subnet" })
}

# Route table for public subnet
# Use default route table
data "aws_route_table" "default" {
  vpc_id = data.aws_vpc.default.id
  filter {
    name   = "association.main"
    values = ["true"]
  }
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = data.aws_route_table.default.id
}

# Security group for K3s cluster
resource "aws_security_group" "k3s" {
  name_prefix = "${local.name_prefix}-k3s-"
  vpc_id      = data.aws_vpc.default.id

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

  # HTTP/HTTPS for apps
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

  # NodePort range for services
  ingress {
    from_port   = 30000
    to_port     = 32767
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-k3s-sg" })
}

# Key pair for SSH
resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = var.ssh_public_key
  tags       = local.tags
}

# EC2 instance for K3s cluster (FREE TIER)
resource "aws_instance" "k3s" {
  ami                    = "ami-0f58b397bc5c1f2e8" # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"              # FREE TIER
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = aws_subnet.public.id

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl docker.io mysql-client
    
    # Install K3s
    curl -sfL https://get.k3s.io | sh -
    
    # Setup Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    
    # Make kubeconfig accessible for download
    chmod 644 /etc/rancher/k3s/k3s.yaml
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    echo "K3s cluster ready! Kubeconfig available at /etc/rancher/k3s/k3s.yaml"
  EOF

  tags = merge(local.tags, { Name = "${local.name_prefix}-k3s-node" })
}

# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name       = "${local.name_prefix}-db-subnet-group"
  subnet_ids = [aws_subnet.public.id, aws_subnet.db.id]
  tags = merge(local.tags, { Name = "${local.name_prefix}-db-subnet-group" })
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s.id]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-rds-sg" })
}

# GitHub Runner
module "github_runner" {
  source = "../modules/github-runner"
  
  environment   = var.environment
  vpc_id        = data.aws_vpc.default.id
  subnet_id     = aws_subnet.public.id
  ssh_key_name  = aws_key_pair.main.key_name
  repo_pat      = var.repo_pat
  repo_name     = var.repo_name
}

# RDS MySQL (FREE TIER)
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = "db.t3.micro" # FREE TIER
  
  allocated_storage     = 20 # FREE TIER
  max_allocated_storage = 20
  storage_type          = "gp2"
  storage_encrypted     = false
  
  db_name  = "healthapp"
  username = "admin"
  password = "${var.environment}Password123!" # AWS requires 8+ characters
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  
  tags = merge(local.tags, { Name = "${local.name_prefix}-rds" })
}