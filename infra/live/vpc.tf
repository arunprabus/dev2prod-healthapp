# Network Architecture: 3 Isolated VPCs with Peering

# Monitoring VPC (Central Hub)
module "vpc_monitoring" {
  source = "../modules/vpc"

  name_prefix         = "health-app-monitoring"
  vpc_cidr           = "10.30.0.0/16"
  public_subnet_cidrs = ["10.30.1.0/24", "10.30.2.0/24"]

  tags = {
    Environment = "monitoring"
    NetworkTier = "monitoring"
    Project     = "health-app"
  }
}

# Lower Network VPC (Dev + Test)
module "vpc_lower" {
  source = "../modules/vpc"

  name_prefix         = "health-app-lower"
  vpc_cidr           = "10.10.0.0/16"
  public_subnet_cidrs = ["10.10.1.0/24", "10.10.2.0/24"]
  
  # Peer with monitoring VPC
  peer_vpc_id         = module.vpc_monitoring.vpc_id
  monitoring_vpc_cidr = module.vpc_monitoring.vpc_cidr_block

  tags = {
    Environment = "dev"
    NetworkTier = "lower"
    Project     = "health-app"
  }
}

# Higher Network VPC (Production)
module "vpc_higher" {
  source = "../modules/vpc"

  name_prefix         = "health-app-higher"
  vpc_cidr           = "10.20.0.0/16"
  public_subnet_cidrs = ["10.20.1.0/24", "10.20.2.0/24"]
  
  # Peer with monitoring VPC
  peer_vpc_id         = module.vpc_monitoring.vpc_id
  monitoring_vpc_cidr = module.vpc_monitoring.vpc_cidr_block

  tags = {
    Environment = "prod"
    NetworkTier = "higher"
    Project     = "health-app"
  }
}

# Reverse Peering: Monitoring to Lower
resource "aws_vpc_peering_connection" "monitoring_to_lower" {
  vpc_id      = module.vpc_monitoring.vpc_id
  peer_vpc_id = module.vpc_lower.vpc_id
  auto_accept = true

  tags = {
    Name = "monitoring-to-lower"
  }
}

resource "aws_route" "monitoring_to_lower" {
  route_table_id            = module.vpc_monitoring.route_table_id
  destination_cidr_block    = module.vpc_lower.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.monitoring_to_lower.id
}

# Reverse Peering: Monitoring to Higher
resource "aws_vpc_peering_connection" "monitoring_to_higher" {
  vpc_id      = module.vpc_monitoring.vpc_id
  peer_vpc_id = module.vpc_higher.vpc_id
  auto_accept = true

  tags = {
    Name = "monitoring-to-higher"
  }
}

resource "aws_route" "monitoring_to_higher" {
  route_table_id            = module.vpc_monitoring.route_table_id
  destination_cidr_block    = module.vpc_higher.vpc_cidr_block
  vpc_peering_connection_id = aws_vpc_peering_connection.monitoring_to_higher.id
}