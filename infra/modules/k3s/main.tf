# K3s on EC2 - Free Tier Alternative to EKS
resource "aws_security_group" "k3s" {
  name_prefix = "${var.name_prefix}-k3s-"
  vpc_id      = var.vpc_id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # K3s API server - Allow GitHub Actions access
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
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
  tags       = var.tags
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
          "s3:PutObjectAcl"
        ]
        Resource = "arn:aws:s3:::${var.s3_bucket}/kubeconfig/*"
      }
    ]
  })
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${var.name_prefix}-k3s-profile"
  role = aws_iam_role.k3s_role.name
}

# K3s master node
resource "aws_instance" "k3s" {
  ami                    = "ami-0f58b397bc5c1f2e8" # Ubuntu 22.04 LTS
  instance_type          = var.k3s_instance_type
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y curl docker.io mysql-client
    
    # Install AWS CLI
    apt-get install -y awscli
    
    # Install K3s
    curl -sfL https://get.k3s.io | sh -
    
    # Setup Docker
    systemctl enable docker
    systemctl start docker
    usermod -aG docker ubuntu
    
    # Install kubectl
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    chmod +x kubectl
    mv kubectl /usr/local/bin/
    
    # Wait for K3s to be ready
    sleep 60
    
    # Generate and upload kubeconfig to S3
    echo "Starting kubeconfig generation and S3 upload..."
    echo "S3 bucket: ${var.s3_bucket}"
    echo "Environment: ${var.environment}"
    
    if [[ -n "${var.s3_bucket}" ]]; then
      # Get public IP
      PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
      echo "Public IP: $PUBLIC_IP"
      
      # Check if K3s kubeconfig exists
      if [[ -f /etc/rancher/k3s/k3s.yaml ]]; then
        echo "K3s kubeconfig found, processing..."
        
        # Copy and modify kubeconfig
        cp /etc/rancher/k3s/k3s.yaml /tmp/kubeconfig.yaml
        sed -i "s|127.0.0.1:6443|$PUBLIC_IP:6443|g" /tmp/kubeconfig.yaml
        
        echo "Modified kubeconfig content:"
        cat /tmp/kubeconfig.yaml
        
        # Test AWS CLI
        echo "Testing AWS CLI access..."
        aws sts get-caller-identity || echo "AWS CLI test failed"
        
        # Upload to S3
        echo "Uploading to S3..."
        if aws s3 cp /tmp/kubeconfig.yaml s3://${var.s3_bucket}/kubeconfig/${var.environment}-kubeconfig.yaml; then
          echo "SUCCESS: Kubeconfig uploaded to S3"
        else
          echo "ERROR: Failed to upload kubeconfig to S3"
        fi
        
        # List S3 contents to verify
        aws s3 ls s3://${var.s3_bucket}/kubeconfig/ || echo "Failed to list S3 contents"
      else
        echo "ERROR: K3s kubeconfig not found at /etc/rancher/k3s/k3s.yaml"
      fi
    else
      echo "ERROR: S3 bucket not specified"
    fi
    
    # Make kubeconfig accessible locally
    mkdir -p /home/ubuntu/.kube
    cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
    chown ubuntu:ubuntu /home/ubuntu/.kube/config
    
    echo "K3s cluster ready for ${var.environment} environment!"
  EOF

  tags = merge(var.tags, { Name = "${var.name_prefix}-k3s-node" })
}

