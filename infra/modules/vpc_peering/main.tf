# VPC Peering Module - Minimal Implementation
resource "aws_vpc_peering_connection" "main" {
  vpc_id      = var.requestor_vpc_id
  peer_vpc_id = var.acceptor_vpc_id
  auto_accept = true

  tags = merge(var.tags, {
    Name = "vpc-peering-${var.requestor_vpc_id}-${var.acceptor_vpc_id}"
  })
}

resource "aws_route" "requester_to_accepter" {
  count                     = length(var.requestor_route_table_ids)
  route_table_id            = var.requestor_route_table_ids[count.index]
  destination_cidr_block    = var.acceptor_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}

resource "aws_route" "accepter_to_requester" {
  count                     = length(var.acceptor_route_table_ids)
  route_table_id            = var.acceptor_route_table_ids[count.index]
  destination_cidr_block    = var.requestor_cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.main.id
}