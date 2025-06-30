# RDS Instance with restore capability
resource "aws_db_instance" "healthapi_restored" {
  identifier = "healthapidb-restored"
  
  # Restore from snapshot
  snapshot_identifier = var.restore_from_snapshot ? var.snapshot_identifier : null
  
  # Standard config
  engine         = "postgres"
  engine_version = "15.4"
  instance_class = "db.t3.micro"
  
  allocated_storage     = 20
  max_allocated_storage = 100
  storage_type         = "gp2"
  storage_encrypted    = true
  
  db_name  = "healthapi"
  username = var.db_username
  password = var.db_password
  
  vpc_security_group_ids = [module.rds.security_group_id]
  db_subnet_group_name   = module.rds.subnet_group_name
  
  backup_retention_period = 7
  backup_window          = "03:00-04:00"
  maintenance_window     = "sun:04:00-sun:05:00"
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = {
    Name = "HealthAPI-DB-Restored"
  }
}

# Variables for restore
variable "restore_from_snapshot" {
  description = "Whether to restore from snapshot"
  type        = bool
  default     = false
}

variable "snapshot_identifier" {
  description = "Snapshot ID to restore from"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
}