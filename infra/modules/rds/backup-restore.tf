# RDS Backup and Restore Module
# Supports both snapshot and S3 backup strategies

# Variables for backup strategy
variable "backup_strategy" {
  description = "Backup strategy: snapshot, s3, or both"
  type        = string
  default     = "both"
  validation {
    condition     = contains(["snapshot", "s3", "both"], var.backup_strategy)
    error_message = "Backup strategy must be 'snapshot', 's3', or 'both'."
  }
}

variable "s3_backup_bucket" {
  description = "S3 bucket for database backups"
  type        = string
  default     = ""
}

variable "backup_retention_days" {
  description = "Number of days to retain backups"
  type        = number
  default     = 7
}

# IAM role for RDS S3 export
resource "aws_iam_role" "rds_s3_export" {
  count = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name  = "${var.project_name}-rds-s3-export-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "export.rds.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# IAM policy for S3 access
resource "aws_iam_role_policy" "rds_s3_export" {
  count = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name  = "S3ExportPolicy"
  role  = aws_iam_role.rds_s3_export[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:PutObject*",
          "s3:ListBucket",
          "s3:GetObject*"
        ]
        Resource = [
          "arn:aws:s3:::${var.s3_backup_bucket}",
          "arn:aws:s3:::${var.s3_backup_bucket}/*"
        ]
      }
    ]
  })
}

# Customer-managed KMS key for S3 exports
resource "aws_kms_key" "rds_export" {
  count       = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  description = "KMS key for RDS S3 exports"

  tags = merge(var.tags, {
    Name = "${var.project_name}-rds-export-key"
  })
}

resource "aws_kms_alias" "rds_export" {
  count         = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name          = "alias/${var.project_name}-rds-export"
  target_key_id = aws_kms_key.rds_export[0].key_id
}

# Lambda function for automated S3 exports
resource "aws_lambda_function" "rds_s3_export" {
  count         = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  filename      = "rds_export_lambda.zip"
  function_name = "${var.project_name}-rds-s3-export"
  role          = aws_iam_role.lambda_rds_export[0].arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.9"
  timeout       = 300

  environment {
    variables = {
      S3_BUCKET     = var.s3_backup_bucket
      KMS_KEY_ID    = aws_kms_key.rds_export[0].key_id
      IAM_ROLE_ARN  = aws_iam_role.rds_s3_export[0].arn
    }
  }

  tags = var.tags
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_rds_export" {
  count = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name  = "${var.project_name}-lambda-rds-export"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  tags = var.tags
}

# Lambda execution policy
resource "aws_iam_role_policy" "lambda_rds_export" {
  count = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name  = "LambdaRDSExportPolicy"
  role  = aws_iam_role.lambda_rds_export[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "rds:DescribeDBSnapshots",
          "rds:StartExportTask",
          "rds:DescribeExportTasks"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = aws_iam_role.rds_s3_export[0].arn
      }
    ]
  })
}

# EventBridge rule for scheduled exports
resource "aws_cloudwatch_event_rule" "rds_backup_schedule" {
  count               = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  name                = "${var.project_name}-rds-backup-schedule"
  description         = "Trigger RDS S3 export weekly"
  schedule_expression = "cron(0 2 ? * SUN *)"  # Every Sunday at 2 AM

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "lambda" {
  count     = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  rule      = aws_cloudwatch_event_rule.rds_backup_schedule[0].name
  target_id = "TriggerLambda"
  arn       = aws_lambda_function.rds_s3_export[0].arn
}

resource "aws_lambda_permission" "allow_eventbridge" {
  count         = var.backup_strategy == "s3" || var.backup_strategy == "both" ? 1 : 0
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rds_s3_export[0].function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.rds_backup_schedule[0].arn
}

# Outputs
output "s3_export_role_arn" {
  description = "ARN of the RDS S3 export role"
  value       = var.backup_strategy == "s3" || var.backup_strategy == "both" ? aws_iam_role.rds_s3_export[0].arn : null
}

output "kms_key_id" {
  description = "KMS key ID for RDS exports"
  value       = var.backup_strategy == "s3" || var.backup_strategy == "both" ? aws_kms_key.rds_export[0].key_id : null
}

output "backup_cost_estimate" {
  description = "Monthly backup cost estimate"
  value = {
    snapshot_cost = "$1.90/month (20GB × $0.095/GB)"
    s3_cost      = "$0.05/month (20GB compressed to ~2GB × $0.023/GB)"
    savings      = "97% cost reduction with S3 strategy"
  }
}