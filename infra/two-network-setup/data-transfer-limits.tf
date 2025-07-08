# Data Transfer Optimization Configuration
# Minimize data transfer to stay within 1GB free tier limit

# CloudWatch alarm for data transfer usage
resource "aws_cloudwatch_metric_alarm" "data_transfer_alarm" {
  alarm_name          = "health-app-data-transfer-${var.network_tier}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"  # 24 hours
  statistic           = "Maximum"
  threshold           = "0.01"   # $0.01 threshold
  alarm_description   = "Data transfer approaching free tier limit"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonEC2"
  }

  tags = local.common_tags
}

# SNS topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "health-app-alerts-${var.network_tier}"
  tags = local.common_tags
}

# Lambda function for auto-optimization
resource "aws_lambda_function" "data_optimizer" {
  filename         = "data-optimizer.zip"
  function_name    = "health-app-data-optimizer-${var.network_tier}"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 300

  environment {
    variables = {
      REGION = var.aws_region
      ENVIRONMENT = var.environment
    }
  }

  tags = local.common_tags
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "health-app-lambda-role-${var.network_tier}"

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

  tags = local.common_tags
}

# Lambda policy for EC2 and RDS management
resource "aws_iam_role_policy" "lambda_policy" {
  name = "health-app-lambda-policy-${var.network_tier}"
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
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "ec2:UnmonitorInstances",
          "rds:DescribeDBInstances",
          "rds:StopDBInstance",
          "cloudwatch:GetMetricStatistics"
        ]
        Resource = "*"
      }
    ]
  })
}

# EventBridge rule for scheduled optimization
resource "aws_cloudwatch_event_rule" "optimize_schedule" {
  name                = "health-app-optimize-${var.network_tier}"
  description         = "Trigger data transfer optimization"
  schedule_expression = "rate(6 hours)"
  tags               = local.common_tags
}

# EventBridge target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.optimize_schedule.name
  target_id = "OptimizeLambdaTarget"
  arn       = aws_lambda_function.data_optimizer.arn
}

# Lambda permission for EventBridge
resource "aws_lambda_permission" "allow_eventbridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.data_optimizer.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.optimize_schedule.arn
}