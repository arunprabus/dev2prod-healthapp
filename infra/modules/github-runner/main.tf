resource "aws_instance" "github_runner" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro"
  key_name              = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.runner.id]
  subnet_id             = var.subnet_id
  
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
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/8"]
  }
}

output "runner_ip" {
  value = aws_instance.github_runner.private_ip
}