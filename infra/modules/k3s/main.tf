# K3s on EC2 - Free Tier Alternative to EKS
resource "aws_security_group" "k3s" {
  name_prefix = "${var.name_prefix}-k3s-"
  vpc_id      = var.vpc_id

  # SSH access - restricted to VPC
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "SSH access from VPC only"
  }

  # K3s API server - Allow GitHub Actions access
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "K3s API server access"
  }
  
  # K3s API server - Allow VPC internal access (GitHub runners)
  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
    description = "K3s API server access from VPC (GitHub runners)"
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
  
  lifecycle {
    ignore_changes = [ingress]
  }
}

# Security group rules for runner access (conditional)
resource "aws_security_group_rule" "k3s_ssh_from_runner" {
  count = var.runner_security_group_id != "" ? 1 : 0
  
  type                     = "ingress"
  from_port                = 22
  to_port                  = 22
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = var.runner_security_group_id
  description              = "SSH from GitHub runner"
}

resource "aws_security_group_rule" "k3s_api_from_runner" {
  count = var.runner_security_group_id != "" ? 1 : 0
  
  type                     = "ingress"
  from_port                = 6443
  to_port                  = 6443
  protocol                 = "tcp"
  security_group_id        = aws_security_group.k3s.id
  source_security_group_id = var.runner_security_group_id
  description              = "K3s API from GitHub runner"
}

# Key pair for SSH access
resource "aws_key_pair" "main" {
  key_name   = "${var.name_prefix}-key"
  public_key = var.ssh_public_key
  tags       = var.tags
}

# IAM role for K3s with Session Manager and S3 access
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
  
  lifecycle {
    create_before_destroy = true
  }
}

# Attach AWS managed policy for Session Manager
resource "aws_iam_role_policy_attachment" "k3s_ssm_policy" {
  role       = aws_iam_role.k3s_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  
  lifecycle {
    create_before_destroy = true
  }
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
        Resource = [
          "arn:aws:s3:::${var.s3_bucket}/kubeconfig/*",
          "arn:aws:s3:::${var.s3_bucket}/kubeconfig"
        ]
      }
    ]
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

# IAM policy for Parameter Store access
resource "aws_iam_role_policy" "k3s_parameter_store_policy" {
  name = "${var.name_prefix}-k3s-parameter-store-policy"
  role = aws_iam_role.k3s_role.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:PutParameter",
          "ssm:GetParameter",
          "ssm:GetParameters"
        ]
        Resource = [
          "arn:aws:ssm:*:*:parameter/${var.environment}/health-app/*"
        ]
      }
    ]
  })
  
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_iam_instance_profile" "k3s_profile" {
  name = "${var.name_prefix}-k3s-profile"
  role = aws_iam_role.k3s_role.name
  
  lifecycle {
    create_before_destroy = true
  }
}

# Data source for latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical
  
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
  
  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# K3s master node
resource "aws_instance" "k3s" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = var.k3s_instance_type
  key_name              = aws_key_pair.main.key_name
  vpc_security_group_ids = [aws_security_group.k3s.id]
  subnet_id             = var.subnet_id
  iam_instance_profile   = aws_iam_instance_profile.k3s_profile.name

  user_data = <<-EOF
#!/bin/bash

# Set variables from Terraform
ENVIRONMENT="${var.environment}"
S3_BUCKET="${var.s3_bucket}"

apt-get update
apt-get install -y curl docker.io mysql-client awscli

# Install AWS Systems Manager Agent with error handling
echo "Installing SSM Agent..."
cd /tmp
wget -q https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/debian_amd64/amazon-ssm-agent.deb
if [ $? -eq 0 ]; then
  dpkg -i amazon-ssm-agent.deb
  systemctl enable amazon-ssm-agent
  systemctl start amazon-ssm-agent
  systemctl status amazon-ssm-agent --no-pager
  echo "SSM Agent installation completed"
else
  echo "SSM Agent download failed, trying snap installation..."
  snap install amazon-ssm-agent --classic
  systemctl enable snap.amazon-ssm-agent.amazon-ssm-agent.service
  systemctl start snap.amazon-ssm-agent.amazon-ssm-agent.service
fi

# Install K3s with write permissions and bind to all interfaces
PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
echo "Installing K3s with public IP: $PUBLIC_IP"
curl -sfL https://get.k3s.io | sh -s - --write-kubeconfig-mode 644 --bind-address=0.0.0.0 --advertise-address=$PUBLIC_IP

# Setup Docker
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Install kubectl
curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl /usr/local/bin/

# Wait for K3s to be ready
sleep 60
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

# Create namespace and service account
echo "Creating namespace and service account..."
kubectl create namespace gha-access || true
kubectl create serviceaccount gha-deployer -n gha-access

# Create role with deployment permissions
echo "Creating role with deployment permissions..."
kubectl create role gha-role --verb=get,list,watch,create,update,patch,delete --resource=pods,services,deployments,namespaces -n gha-access
kubectl create rolebinding gha-rolebinding --role=gha-role --serviceaccount=gha-access:gha-deployer -n gha-access

# Generate dynamic token
echo "Generating dynamic token..."
TOKEN=$$(kubectl create token gha-deployer -n gha-access --duration=24h)

if [[ -n "$$TOKEN" ]]; then
  PUBLIC_IP=$$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
  
  # Store kubeconfig data in Parameter Store
  echo "Storing kubeconfig data in Parameter Store..."
  aws ssm put-parameter \
    --name "/$$ENVIRONMENT/health-app/kubeconfig/server" \
    --value "https://$$PUBLIC_IP:6443" \
    --type "String" \
    --overwrite \
    --region ap-south-1
  
  aws ssm put-parameter \
    --name "/$$ENVIRONMENT/health-app/kubeconfig/token" \
    --value "$$TOKEN" \
    --type "SecureString" \
    --overwrite \
    --region ap-south-1
  
  # Store cluster name for reference
  aws ssm put-parameter \
    --name "/$$ENVIRONMENT/health-app/kubeconfig/cluster-name" \
    --value "k3s-cluster" \
    --type "String" \
    --overwrite \
    --region ap-south-1
  
  echo "SUCCESS: Kubeconfig data stored in Parameter Store"
  
  # Create kubeconfig with dynamic token
  cat > /tmp/gha-kubeconfig.yaml << KUBE_EOF
apiVersion: v1
kind: Config
clusters:
- cluster:
    insecure-skip-tls-verify: true
    server: https://$$PUBLIC_IP:6443
  name: k3s-cluster
contexts:
- context:
    cluster: k3s-cluster
    namespace: gha-access
    user: gha-deployer
  name: gha-context
current-context: gha-context
users:
- name: gha-deployer
  user:
    token: $$TOKEN
KUBE_EOF
  
  # Upload to S3 (backup)
  if [[ -n "$$S3_BUCKET" ]]; then
    echo "Uploading kubeconfig to S3..."
    aws s3 cp /tmp/gha-kubeconfig.yaml s3://$$S3_BUCKET/kubeconfig/$$ENVIRONMENT-gha.yaml
    echo "SUCCESS: Service account kubeconfig uploaded to S3"
  fi
else
  echo "ERROR: Failed to generate token"
fi

# Local access
mkdir -p /home/ubuntu/.kube
cp /etc/rancher/k3s/k3s.yaml /home/ubuntu/.kube/config
chown ubuntu:ubuntu /home/ubuntu/.kube/config

echo "K3s cluster ready for $$ENVIRONMENT environment!"
EOF

  tags = merge(var.tags, { Name = "${var.name_prefix}-k3s-node-v2" })
}

