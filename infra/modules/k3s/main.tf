# K3s on EC2 - Free Tier Alternative to EKS
resource "aws_security_group" "k3s" {
  name_prefix = "${var.name_prefix}-k3s-"
  vpc_id      = var.vpc_id

  # SSH access from management subnets and public (for initial setup)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = concat(["0.0.0.0/0"], var.management_subnet_cidrs)
    description = "SSH access for management and setup"
  }

  # K3s API server - Allow GitHub Actions access from management subnets
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = concat(["0.0.0.0/0"], var.management_subnet_cidrs)  # Allow public + management subnet access
    description = "K3s API server access"
  }

  # HTTP/HTTPS for applications
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

  # NodePort range
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

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-sg"
  })
}

# Key pair for SSH access
resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
  tags = merge(var.tags, {
    Name = "${var.name_prefix}-k3s-key"
    Purpose = "K3s cluster SSH access"
  })
}

# IAM role for S3 access
resource "aws_iam_role" "k3s_role" {
  name = "${var.name_prefix}-k3s-role"
  
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

resource "aws_iam_role_policy" "k3s_s3_policy" {
  name = "${var.name_prefix}-k3s-s3-policy"
  role = aws_iam_role.k3s_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject",
          "s3:PutObjectAcl",
          "s3:GetObject"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/kubeconfig/*",
          "arn:aws:s3:::${var.s3_bucket}/kubeconfig"
        ]
      }
    ]
  })
}

# Attach additional policies for enhanced functionality
resource "aws_iam_role_policy_attachment" "k3s_ssm" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "k3s_cloudwatch" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${var.name_prefix}-k3s-profile"
  role = aws_iam_role.k3s_role.name
}

# K3s master node
resource "aws_instance" "k3s" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type              = var.k3s_instance_type
  key_name                   = aws_key_pair.main.key_name
  vpc_security_group_ids     = [aws_security_group.k3s.id]
  subnet_id                  = var.subnet_id
  iam_instance_profile       = aws_iam_instance_profile.k3s_profile.name
  associate_public_ip_address = true
  
  user_data_replace_on_change = true
  user_data = base64encode(templatefile("${path.module}/user_data_k3s.sh", {
    environment   = var.environment
    cluster_name  = var.cluster_name
    db_endpoint   = var.db_endpoint
    s3_bucket     = var.s3_bucket
    network_tier  = var.network_tier
  }))

  tags = merge(var.tags, { 
    Name = "${var.name_prefix}-k3s-master"
    Type = "k3s-cluster"
    NetworkTier = var.network_tier
  })
}

# Get Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

