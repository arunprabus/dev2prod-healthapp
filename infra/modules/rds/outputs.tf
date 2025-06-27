output "db_instance_endpoint" {
  description = "Connection endpoint for the RDS database"
  value       = aws_db_instance.health_db.endpoint
}

output "db_instance_address" {
  description = "The hostname of the RDS instance"
  value       = aws_db_instance.health_db.address
}

output "db_instance_port" {
  description = "The port on which the RDS instance accepts connections"
  value       = aws_db_instance.health_db.port
}

output "db_instance_name" {
  description = "Name of the RDS instance"
  value       = aws_db_instance.health_db.identifier
}

output "db_instance_username" {
  description = "Master username for the RDS instance"
  value       = aws_db_instance.health_db.username
}

output "db_instance_database_name" {
  description = "Name of the initial database"
  value       = aws_db_instance.health_db.db_name
}

output "db_security_group_id" {
  description = "ID of the security group used by the RDS instance"
  value       = aws_security_group.db.id
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.health_db.name
}

output "db_parameter_group_name" {
  description = "Name of the DB parameter group"
  value       = aws_db_parameter_group.health_db.name
}
