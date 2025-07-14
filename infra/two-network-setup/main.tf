terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
  
  backend "s3" {
    # Backend configuration provided via -backend-config flags
    # bucket = "health-app-terraform-state"
    # key    = "health-app-{env}.tfstate"
    # region = "ap-south-1"
  }
}

provider "aws" {
  region = var.aws_region
}

# Get or create default VPC
resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}

data "aws_vpc" "first" {
  id = aws_default_vpc.default.id
}



# Get existing subnets
data "aws_subnets" "existing" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.first.id]
  }
}

data "aws_subnet" "public" {
  id = tolist(data.aws_subnets.existing.ids)[0]
}

data "aws_subnet" "db" {
  id = length(data.aws_subnets.existing.ids) > 1 ? tolist(data.aws_subnets.existing.ids)[1] : tolist(data.aws_subnets.existing.ids)[0]
}

# Security group for K3s cluster
resource "aws_security_group" "k3s" {
  name_prefix = "${local.name_prefix}-k3s-"
  vpc_id      = data.aws_vpc.first.id
  
  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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

# Key pair for SSH - use existing
data "aws_key_pair" "main" {
  key_name = "${local.name_prefix}-key"
}

# Use existing IAM role for K3s instance (SSM access)
data "aws_iam_role" "k3s_role" {
  name = "${local.name_prefix}-k3s-role"
}

# Use existing instance profile for K3s
data "aws_iam_instance_profile" "k3s_profile" {
  name = "${local.name_prefix}-k3s-profile"
}

# EC2 instance for K3s cluster
resource "aws_instance" "k3s" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  key_name              = data.aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = data.aws_subnet.public.id
  iam_instance_profile   = data.aws_iam_instance_profile.k3s_profile.name
  
  lifecycle {
    ignore_changes = [ami]
  }

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl docker.io mysql-client
    
    # Install and configure SSM Agent
    snap install amazon-ssm-agent --classic
    systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
    systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
    
    # Install K3s
    curl -sfL https://get.k3s.io | sh -
    
    # Setup Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    
    # Make kubeconfig accessible
    chmod 644 /etc/rancher/k3s/k3s.yaml
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
  EOF

  tags = merge(local.tags, { Name = "${local.name_prefix}-k3s-node" })
}

# GitHub Runner
module "github_runner" {
  source = "../modules/github-runner"
  
  network_tier     = var.network_tier
  vpc_id           = data.aws_vpc.first.id
  subnet_id        = data.aws_subnet.public.id
  ssh_public_key   = var.ssh_public_key
  repo_pat         = var.repo_pat
  repo_name        = var.repo_name
  s3_bucket        = "health-app-terraform-state"
  aws_region       = var.aws_region
}

# RDS Subnet Group - use existing
data "aws_db_subnet_group" "main" {
  name = "${local.name_prefix}-db-subnet-group"
}

# Security group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${local.name_prefix}-rds-"
  vpc_id      = data.aws_vpc.first.id
  
  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port       = var.restore_from_snapshot ? 5432 : 3306
    to_port         = var.restore_from_snapshot ? 5432 : 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.k3s.id]
  }

  tags = merge(local.tags, { Name = "${local.name_prefix}-rds-sg" })
}

# RDS Database (MySQL or PostgreSQL based on snapshot)
resource "aws_db_instance" "main" {
  identifier     = "${local.name_prefix}-db"
  engine         = var.restore_from_snapshot ? "postgres" : "mysql"
  engine_version = var.restore_from_snapshot ? "17.4" : "8.0"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 20
  storage_type          = "gp2"
  storage_encrypted     = false
  
  # Restore from snapshot if specified
  snapshot_identifier = var.restore_from_snapshot ? var.snapshot_identifier : null
  
  # Only set these if NOT restoring from snapshot
  db_name  = var.restore_from_snapshot ? null : "healthapp"
  username = var.restore_from_snapshot ? null : "admin"
  password = var.restore_from_snapshot ? null : "${var.environment}Password123!"
  
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = data.aws_db_subnet_group.main.name
  
  backup_retention_period = 0
  skip_final_snapshot     = true
  deletion_protection     = false
  
  lifecycle {
    # Prevent accidental deletion
    prevent_destroy = false
    # Ignore changes to password after creation
    ignore_changes = [password]
    # Create before destroy to handle conflicts
    create_before_destroy = false
  }
  
  tags = merge(local.tags, { Name = "${local.name_prefix}-rds" })
}