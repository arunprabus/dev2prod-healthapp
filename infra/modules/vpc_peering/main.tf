# VPC Peering module to connect environments

variable "requestor_vpc_id" {
  description = "VPC ID of the requestor"
  type        = string
}

variable "acceptor_vpc_id" {
  description = "VPC ID of the acceptor"
  type        = string
}

variable "requestor_route_table_ids" {
  description = "Route table IDs of the requestor VPC"
  type        = list(string)
}

variable "acceptor_route_table_ids" {
  description = "Route table IDs of the acceptor VPC"
  type        = list(string)
}

variable "requestor_cidr" {
  description = "CIDR block of the requestor VPC"
  type        = string
}

variable "acceptor_cidr" {
  description = "CIDR block of the acceptor VPC"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Create VPC peering connection
resource "aws_vpc_peering_connection" "peering" {
  vpc_id        = var.requestor_vpc_id
  peer_vpc_id   = var.acceptor_vpc_id
  auto_accept   = true

  accepter {
    allow_remote_vpc_dns_resolution = true
  }

  requester {
    allow_remote_vpc_dns_resolution = true
  }

  tags = merge(var.tags, {
    Name = "${var.requestor_vpc_id}-to-${var.acceptor_vpc_id}-peering"
  })
}

# Add routes to requestor route tables
resource "aws_route" "requestor_to_acceptor" {
  count = length(var.requestor_route_table_ids)

  route_table_id            = var.requestor_route_table_ids[count.index]
  destination_cidr_block    = var.acceptor_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}

# Add routes to acceptor route tables
resource "aws_route" "acceptor_to_requestor" {
  count = length(var.acceptor_route_table_ids)

  route_table_id            = var.acceptor_route_table_ids[count.index]
  destination_cidr_block    = var.requestor_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.peering.id
}

output "peering_connection_id" {
  value       = aws_vpc_peering_connection.peering.id
  description = "ID of the VPC peering connection"
}
