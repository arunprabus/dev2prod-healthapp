# RDS Module - Minimal Implementation
resource "aws_db_subnet_group" "health_db" {
  name       = "${var.identifier}-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.identifier}-subnet-group"
  })
}

resource "aws_security_group" "db" {
  name_prefix = "${var.identifier}-db-"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
}

resource "aws_db_parameter_group" "health_db" {
  family = "mysql8.0"
  name   = "${var.identifier}-params"

  tags = var.tags
}

resource "aws_db_instance" "health_db" {
  identifier     = var.identifier
  engine         = "mysql"
  engine_version = "8.0"
  instance_class = var.db_instance_class
  
  allocated_storage     = var.db_allocated_storage
  storage_type          = "gp2"
  storage_encrypted     = false  # Free tier doesn't support encryption
  
  db_name  = "healthapp"
  username = "admin"
  password = "changeme123!" # Use AWS Secrets Manager in production
  
  vpc_security_group_ids = [aws_security_group.db.id]
  db_subnet_group_name   = aws_db_subnet_group.health_db.name
  parameter_group_name   = aws_db_parameter_group.health_db.name
  
  backup_retention_period = 0  # No backups for free tier
  
  skip_final_snapshot = true
  deletion_protection = false
  
  tags = merge(var.tags, {
    Name = var.identifier
  })
}