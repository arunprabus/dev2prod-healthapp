# Lambda functions for automation and monitoring

# Cost Monitor Lambda
resource "aws_lambda_function" "cost_monitor" {
  filename         = "cost-monitor.zip"
  function_name    = "${var.name_prefix}-cost-monitor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 60

  environment {
    variables = {
      COST_THRESHOLD = var.cost_threshold
      SNS_TOPIC_ARN  = aws_sns_topic.alerts.arn
    }
  }

  tags = var.tags
}

# Resource Cleanup Lambda
resource "aws_lambda_function" "resource_cleanup" {
  filename         = "resource-cleanup.zip"
  function_name    = "${var.name_prefix}-resource-cleanup"
  role            = aws_iam_role.lambda_role.arn
  handler         = "lambda_function.lambda_handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      ENVIRONMENT = var.environment
    }
  }

  tags = var.tags
}

# IAM Role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "${var.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# IAM Policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "${var.name_prefix}-lambda-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "ce:GetCostAndUsage",
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "rds:DescribeDBInstances",
          "rds:StopDBInstance",
          "rds:CreateDBSnapshot",
          "sns:Publish"
        ]
        Resource = "*"
      }
    ]
  })
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"
  tags = var.tags
}

# EventBridge Rules
resource "aws_cloudwatch_event_rule" "cost_monitor_schedule" {
  name                = "${var.name_prefix}-cost-monitor"
  schedule_expression = "cron(0 9 * * ? *)"
  tags = var.tags
}

resource "aws_cloudwatch_event_rule" "cleanup_schedule" {
  name                = "${var.name_prefix}-cleanup"
  schedule_expression = "cron(0 18 * * ? *)"
  tags = var.tags
}

# EventBridge Targets
resource "aws_cloudwatch_event_target" "cost_monitor_target" {
  rule      = aws_cloudwatch_event_rule.cost_monitor_schedule.name
  target_id = "CostMonitor"
  arn       = aws_lambda_function.cost_monitor.arn
}

resource "aws_cloudwatch_event_target" "cleanup_target" {
  rule      = aws_cloudwatch_event_rule.cleanup_schedule.name
  target_id = "Cleanup"
  arn       = aws_lambda_function.resource_cleanup.arn
}

# Lambda Permissions
resource "aws_lambda_permission" "cost_monitor_permission" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_monitor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cost_monitor_schedule.arn
}

resource "aws_lambda_permission" "cleanup_permission" {
  statement_id  = "AllowEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.resource_cleanup.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.cleanup_schedule.arn
}