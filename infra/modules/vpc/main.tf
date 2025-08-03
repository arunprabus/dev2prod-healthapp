# Custom VPC Module for Network Isolation
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-vpc"
  })
}

# Internet Gateway
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-igw"
  })
}

# Public Subnets (2 AZs for HA)
resource "aws_subnet" "public" {
  count = length(var.availability_zones)

  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  availability_zone       = var.availability_zones[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-${count.index + 1}"
    Type = "Public"
  })
}

# Route Table for Public Subnets
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-public-rt"
  })
}

# Associate Public Subnets with Route Table
resource "aws_route_table_association" "public" {
  count = length(aws_subnet.public)

  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# VPC Peering to Monitoring VPC
resource "aws_vpc_peering_connection" "to_monitoring" {
  count = var.peer_vpc_id != null ? 1 : 0

  vpc_id      = aws_vpc.main.id
  peer_vpc_id = var.peer_vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-to-monitoring"
  })
}

# Route for Monitoring Access
resource "aws_route" "to_monitoring" {
  count = var.peer_vpc_id != null ? 1 : 0

  route_table_id            = aws_route_table.public.id
  destination_cidr_block    = var.monitoring_vpc_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.to_monitoring[0].id
}