output "cost_monitor_function_name" {
  description = "Name of cost monitor Lambda function"
  value       = aws_lambda_function.cost_monitor.function_name
}

output "cleanup_function_name" {
  description = "Name of cleanup Lambda function"
  value       = aws_lambda_function.resource_cleanup.function_name
}

output "sns_topic_arn" {
  description = "SNS topic ARN for alerts"
  value       = aws_sns_topic.alerts.arn
}