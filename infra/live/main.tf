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

# VPC modules are defined in vpc.tf

# Select VPC based on network tier
locals {
  current_vpc = var.network_tier == "monitoring" ? module.vpc_monitoring : (
    var.network_tier == "lower" ? module.vpc_lower : module.vpc_higher
  )
  current_subnet = local.current_vpc.public_subnet_ids[0]
}

# Security group for K3s cluster
resource "aws_security_group" "k3s" {
  name_prefix = "${local.name_prefix}-k3s-"
  vpc_id      = local.current_vpc.vpc_id
  
  lifecycle {
    create_before_destroy = true
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API server - Direct access (FREE option)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "K3s API server direct access"
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

# Key pair for SSH - create if not exists
resource "aws_key_pair" "main" {
  key_name   = "${local.name_prefix}-key"
  public_key = var.ssh_public_key
  
  tags = merge(local.tags, { Name = "${local.name_prefix}-key" })
}

# IAM role for K3s instance (SSM access)
resource "aws_iam_role" "k3s_role" {
  name = "${local.name_prefix}-k3s-role"
  
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
  
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "k3s_ssm" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM policy for S3 and SSM access
resource "aws_iam_role_policy" "k3s_policy" {
  name = "${local.name_prefix}-k3s-policy"
  role = aws_iam_role.k3s_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject"
        ]
        Resource = [
          "arn:aws:s3:::health-app-terraform-state/kubeconfig/*",
          "arn:aws:s3:::health-app-terraform-state/kubeconfig"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:*:parameter/health-app/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = "arn:aws:kms:${var.aws_region}:*:key/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${local.name_prefix}-k3s-profile"
  role = aws_iam_role.k3s_role.name
  
  tags = local.tags
}

# EC2 instance for K3s cluster
resource "aws_instance" "k3s" {
  ami                    = "ami-0f58b397bc5c1f2e8"
  instance_type          = "t2.micro"
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = local.current_subnet
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name
  
  lifecycle {
    ignore_changes = [ami]
  }

  user_data_replace_on_change = true
  user_data = base64encode(templatefile("../modules/k3s/user_data_k3s.sh", {
    environment   = var.environment
    cluster_name  = "${local.name_prefix}-cluster"
    db_endpoint   = ""
    s3_bucket     = "health-app-terraform-state"
    network_tier  = var.network_tier
  }))

  tags = merge(local.tags, { Name = "${local.name_prefix}-k3s-node" })
}

# Optional: ACM Certificate for K3s API (costs ~$18/month)
module "acm_certificate" {
  count = var.enable_ssl_termination ? 1 : 0
  source = "../modules/acm"
  
  name_prefix   = local.name_prefix
  domain_name   = var.k3s_domain_name
  route53_zone_id = var.route53_zone_id
  
  tags = local.tags
}

# Optional: Network Load Balancer for K3s API with ACM
module "k3s_nlb" {
  count = var.enable_ssl_termination ? 1 : 0
  source = "../modules/k3s-nlb"
  
  name_prefix       = local.name_prefix
  vpc_id            = local.current_vpc.vpc_id
  subnet_ids        = local.current_vpc.public_subnet_ids
  k3s_instance_id   = aws_instance.k3s.id
  certificate_arn   = module.acm_certificate[0].certificate_arn
  
  tags = local.tags
  depends_on = [aws_instance.k3s]
}

# GitHub Runner - Deploy to Monitoring VPC for centralized access
module "github_runner" {
  source = "../modules/github-runner"
  
  network_tier       = var.network_tier
  vpc_id             = module.vpc_monitoring.vpc_id
  subnet_id          = module.vpc_monitoring.public_subnet_ids[0]
  ssh_public_key     = var.ssh_public_key
  repo_pat           = var.repo_pat
  repo_name          = var.repo_name
  s3_bucket          = "health-app-terraform-state"
  aws_region         = var.aws_region
  k3s_subnet_cidrs   = [
    module.vpc_lower.vpc_cidr_block,
    module.vpc_higher.vpc_cidr_block,
    module.vpc_monitoring.vpc_cidr_block
  ]
  
  depends_on = [aws_key_pair.main, module.vpc_monitoring]
}

# RDS Database - Commented out for now
# resource "aws_db_subnet_group" "main" {
#   name       = "${local.name_prefix}-db-subnet-group"
#   subnet_ids = local.current_vpc.public_subnet_ids
#   
#   tags = merge(local.tags, { Name = "${local.name_prefix}-db-subnet-group" })
# }

# resource "aws_security_group" "rds" {
#   name_prefix = "${local.name_prefix}-rds-"
#   vpc_id      = local.current_vpc.vpc_id
#   
#   lifecycle {
#     create_before_destroy = true
#   }

#   ingress {
#     from_port       = var.restore_from_snapshot ? 5432 : 3306
#     to_port         = var.restore_from_snapshot ? 5432 : 3306
#     protocol        = "tcp"
#     security_groups = [aws_security_group.k3s.id]
#   }

#   tags = merge(local.tags, { Name = "${local.name_prefix}-rds-sg" })
# }

# resource "aws_db_instance" "main" {
#   identifier     = "${local.name_prefix}-db"
#   engine         = var.restore_from_snapshot ? "postgres" : "mysql"
#   engine_version = var.restore_from_snapshot ? "17.4" : "8.0"
#   instance_class = "db.t3.micro"
#   
#   allocated_storage     = 20
#   max_allocated_storage = 20
#   storage_type          = "gp2"
#   storage_encrypted     = false
#   
#   # Restore from snapshot if specified
#   snapshot_identifier = var.restore_from_snapshot ? var.snapshot_identifier : null
#   
#   # Only set these if NOT restoring from snapshot
#   db_name  = var.restore_from_snapshot ? null : "healthapp"
#   username = var.restore_from_snapshot ? null : "admin"
#   password = var.restore_from_snapshot ? null : "${var.environment}Password123!"
#   
#   vpc_security_group_ids = [aws_security_group.rds.id]
#   db_subnet_group_name   = aws_db_subnet_group.main.name
#   
#   backup_retention_period = 0
#   skip_final_snapshot     = true
#   deletion_protection     = false
#   
#   tags = merge(local.tags, { Name = "${local.name_prefix}-rds" })
# }