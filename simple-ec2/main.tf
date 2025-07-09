provider "aws" {
  region = "ap-south-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

resource "aws_key_pair" "simple" {
  key_name   = "simple-ec2-key-${random_id.suffix.hex}"
  public_key = var.ssh_public_key
}

data "aws_vpcs" "existing" {}

data "aws_vpc" "first" {
  id = tolist(data.aws_vpcs.existing.ids)[0]
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.first.id]
  }
  filter {
    name   = "map-public-ip-on-launch"
    values = ["true"]
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

resource "aws_security_group" "simple" {
  name   = "simple-ec2-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.first.id
  
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "simple" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = "t2.micro"
  key_name                   = aws_key_pair.simple.key_name
  vpc_security_group_ids     = [aws_security_group.simple.id]
  subnet_id                  = tolist(data.aws_subnets.public.ids)[0]
  associate_public_ip_address = true
  
  user_data = <<-EOF
    #!/bin/bash
    apt-get update
    systemctl enable ssh
    systemctl start ssh
  EOF
  
  tags = {
    Name = "simple-ec2-free-${random_id.suffix.hex}"
    Tier = "free"
  }
}

output "instance_ip" {
  value = aws_instance.simple.public_ip
}

output "instance_id" {
  value = aws_instance.simple.id
}

variable "ssh_public_key" {
  type = string
}