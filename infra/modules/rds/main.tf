# RDS Module - Minimal Implementation
resource "aws_db_subnet_group" "health_db" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  lifecycle {
    ignore_changes = [name, subnet_ids]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_security_group" "db" {
  name_prefix = "${var.identifier}-db-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = var.engine == "postgres" ? 5432 : 3306
    to_port     = var.engine == "postgres" ? 5432 : 3306
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
    description = "Database access from VPC"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.identifier}-db-sg"
  })
  
  lifecycle {
    ignore_changes = [ingress]
  }
}

resource "aws_db_parameter_group" "health_db" {
  family = var.engine == "postgres" ? "postgres15" : "mysql8.0"
  name   = "${var.identifier}-params"

  lifecycle {
    ignore_changes = [name]
  }

  tags = var.tags
}

resource "aws_db_instance" "health_db" {
  identifier     = var.identifier
  engine         = var.engine
  engine_version = var.engine_version
  instance_class = var.instance_class
  
  allocated_storage     = var.allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = false  # Free tier doesn't support encryption
  
  # Restore from snapshot only if explicitly enabled
  snapshot_identifier = var.restore_from_snapshot ? var.snapshot_identifier : null
  
  # Only set these if NOT restoring from snapshot
  db_name  = var.restore_from_snapshot && var.snapshot_identifier != null ? null : var.db_name
  username = var.restore_from_snapshot && var.snapshot_identifier != null ? null : var.username
  password = var.restore_from_snapshot && var.snapshot_identifier != null ? null : "changeme123!"
  
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.health_db.name
  parameter_group_name   = aws_db_parameter_group.health_db.name
  port                   = var.engine == "postgres" ? 5432 : 3306
  
  backup_retention_period = var.backup_retention_period
  multi_az               = var.multi_az
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = merge(var.tags, {
    Name = var.identifier
  })
}