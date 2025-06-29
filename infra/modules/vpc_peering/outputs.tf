output "vpc_peering_connection_id" {
  description = "ID of the VPC peering connection"
  value       = aws_vpc_peering_connection.main.id
}

output "vpc_peering_connection_status" {
  description = "Status of the VPC peering connection"
  value       = aws_vpc_peering_connection.main.accept_status
}

output "vpc_peering_connection_accepter_vpc_id" {
  description = "ID of the accepter VPC"
  value       = aws_vpc_peering_connection.main.peer_vpc_id
}

output "vpc_peering_connection_requester_vpc_id" {
  description = "ID of the requester VPC"
  value       = aws_vpc_peering_connection.main.vpc_id
}

output "route_table_ids_requester" {
  description = "IDs of the requester route tables"
  value       = aws_route.requester_to_accepter[*].route_table_id
}

output "route_table_ids_accepter" {
  description = "IDs of the accepter route tables"
  value       = aws_route.accepter_to_requester[*].route_table_id
}