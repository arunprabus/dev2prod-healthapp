terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# DynamoDB Table for Health Profiles
resource "aws_dynamodb_table" "health_profiles" {
  name           = var.table_name
  billing_mode   = "ON_DEMAND"
  hash_key       = "PK"
  range_key      = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Global Secondary Index for querying by email
  dynamic "global_secondary_index" {
    for_each = var.enable_email_gsi ? [1] : []
    content {
      name            = "EmailIndex"
      hash_key        = "email"
      projection_type = "ALL"
    }
  }

  attribute {
    name = "email"
    type = "S"
  }

  # Global Secondary Index for querying by user_id
  dynamic "global_secondary_index" {
    for_each = var.enable_user_gsi ? [1] : []
    content {
      name            = "UserIndex"
      hash_key        = "user_id"
      projection_type = "ALL"
    }
  }

  attribute {
    name = "user_id"
    type = "S"
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Tags
  tags = merge(var.common_tags, {
    Name        = var.table_name
    Environment = var.environment
    Service     = "health-api"
  })
}

# DynamoDB Table for File Uploads
resource "aws_dynamodb_table" "file_uploads" {
  name         = "${var.table_name}-uploads"
  billing_mode = "ON_DEMAND"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  # Global Secondary Index for querying by profile_id
  global_secondary_index {
    name            = "ProfileIndex"
    hash_key        = "profile_id"
    projection_type = "ALL"
  }

  attribute {
    name = "profile_id"
    type = "S"
  }

  # Server-side encryption
  server_side_encryption {
    enabled = true
  }

  # Point-in-time recovery
  point_in_time_recovery {
    enabled = var.enable_point_in_time_recovery
  }

  # Tags
  tags = merge(var.common_tags, {
    Name        = "${var.table_name}-uploads"
    Environment = var.environment
    Service     = "health-api"
  })
}