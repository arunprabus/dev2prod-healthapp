# Auto-stop EC2 instance to save costs
resource "aws_lambda_function" "auto_stop" {
  filename         = "auto_stop.zip"
  function_name    = "learning-auto-stop"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  runtime         = "python3.9"
  timeout         = 60

  source_code_hash = data.archive_file.lambda_zip.output_base64sha256

  tags = local.tags
}

# Lambda code
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "auto_stop.zip"
  source {
    content = <<EOF
import boto3
import json

def handler(event, context):
    ec2 = boto3.client('ec2', region_name='ap-south-1')
    rds = boto3.client('rds', region_name='ap-south-1')
    
    # Stop EC2 instances with Learning tag
    instances = ec2.describe_instances(
        Filters=[
            {'Name': 'tag:Project', 'Values': ['Learning']},
            {'Name': 'instance-state-name', 'Values': ['running']}
        ]
    )
    
    for reservation in instances['Reservations']:
        for instance in reservation['Instances']:
            ec2.stop_instances(InstanceIds=[instance['InstanceId']])
            print(f"Stopped instance: {instance['InstanceId']}")
    
    # Stop RDS instances
    try:
        rds.stop_db_instance(DBInstanceIdentifier='learning-db')
        print("Stopped RDS instance: learning-db")
    except Exception as e:
        print(f"RDS stop error: {e}")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Auto-stop completed')
    }
EOF
    filename = "index.py"
  }
}

# IAM role for Lambda
resource "aws_iam_role" "lambda_role" {
  name = "learning-auto-stop-role"

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

  tags = local.tags
}

# IAM policy for Lambda
resource "aws_iam_role_policy" "lambda_policy" {
  name = "learning-auto-stop-policy"
  role = aws_iam_role.lambda_role.id

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
          "ec2:DescribeInstances",
          "ec2:StopInstances",
          "rds:StopDBInstance",
          "rds:DescribeDBInstances"
        ]
        Resource = "*"
      }
    ]
  })
}

# CloudWatch Event Rule - Stop at 10 PM IST daily
resource "aws_cloudwatch_event_rule" "auto_stop" {
  name                = "learning-auto-stop"
  description         = "Auto stop learning resources at 10 PM IST"
  schedule_expression = "cron(30 16 * * ? *)" # 10:30 PM IST = 4:30 PM UTC

  tags = local.tags
}

# CloudWatch Event Target
resource "aws_cloudwatch_event_target" "lambda_target" {
  rule      = aws_cloudwatch_event_rule.auto_stop.name
  target_id = "LambdaTarget"
  arn       = aws_lambda_function.auto_stop.arn
}

# Lambda permission for CloudWatch Events
resource "aws_lambda_permission" "allow_cloudwatch" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.auto_stop.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.auto_stop.arn
}