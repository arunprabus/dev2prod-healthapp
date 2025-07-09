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

resource "aws_vpc" "simple" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  
  tags = {
    Name = "simple-vpc-${random_id.suffix.hex}"
  }
}

resource "aws_internet_gateway" "simple" {
  vpc_id = aws_vpc.simple.id
  
  tags = {
    Name = "simple-igw-${random_id.suffix.hex}"
  }
}

resource "aws_subnet" "simple" {
  vpc_id                  = aws_vpc.simple.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-south-1a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "simple-subnet-${random_id.suffix.hex}"
  }
}

resource "aws_route_table" "simple" {
  vpc_id = aws_vpc.simple.id
  
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.simple.id
  }
  
  tags = {
    Name = "simple-rt-${random_id.suffix.hex}"
  }
}

resource "aws_route_table_association" "simple" {
  subnet_id      = aws_subnet.simple.id
  route_table_id = aws_route_table.simple.id
}

resource "aws_security_group" "simple" {
  name   = "simple-ec2-sg-${random_id.suffix.hex}"
  vpc_id = aws_vpc.simple.id
  
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
  ami                    = "ami-0ad21ae1d0696ad58"
  instance_type          = "t2.micro"
  key_name              = aws_key_pair.simple.key_name
  vpc_security_group_ids = [aws_security_group.simple.id]
  subnet_id             = aws_subnet.simple.id
  
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