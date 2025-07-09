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

data "aws_vpc" "default" {
  default = true
}

resource "aws_security_group" "simple" {
  name   = "simple-ec2-sg-${random_id.suffix.hex}"
  vpc_id = data.aws_vpc.default.id
  
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
  ami                    = "ami-0ad21ae1d0696ad58"  # Ubuntu 22.04 LTS
  instance_type          = "t2.micro"              # FREE TIER
  key_name              = aws_key_pair.simple.key_name
  vpc_security_group_ids = [aws_security_group.simple.id]
  
  tags = {
    Name = "simple-ec2-free-${random_id.suffix.hex}"
    Tier = "free"
  }
}

output "instance_ip" {
  value = aws_instance.simple.public_ip
}

variable "ssh_public_key" {
  type = string
}