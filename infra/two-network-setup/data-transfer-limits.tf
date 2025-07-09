# Simplified data transfer monitoring without SNS/Lambda
# Focus on core infrastructure only

# CloudWatch alarm for basic monitoring
resource "aws_cloudwatch_metric_alarm" "data_transfer_alarm" {
  alarm_name          = "health-app-data-transfer-${var.network_tier}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "EstimatedCharges"
  namespace           = "AWS/Billing"
  period              = "86400"
  statistic           = "Maximum"
  threshold           = "0.01"
  alarm_description   = "Data transfer approaching free tier limit"

  dimensions = {
    Currency    = "USD"
    ServiceName = "AmazonEC2"
  }

  tags = local.tags
}