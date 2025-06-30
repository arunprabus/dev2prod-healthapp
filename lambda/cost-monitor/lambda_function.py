import json
import boto3
import os
from datetime import datetime, timedelta

def lambda_handler(event, context):
    """Cost monitoring Lambda - checks AWS costs and sends alerts"""
    
    ce_client = boto3.client('ce')
    sns_client = boto3.client('sns')
    
    threshold = float(os.environ.get('COST_THRESHOLD', '1.0'))
    sns_topic = os.environ.get('SNS_TOPIC_ARN', '')
    
    try:
        # Get cost for last 7 days
        end_date = datetime.now().date()
        start_date = end_date - timedelta(days=7)
        
        response = ce_client.get_cost_and_usage(
            TimePeriod={
                'Start': start_date.strftime('%Y-%m-%d'),
                'End': end_date.strftime('%Y-%m-%d')
            },
            Granularity='DAILY',
            Metrics=['BlendedCost']
        )
        
        total_cost = sum(
            float(result['Total']['BlendedCost']['Amount'])
            for result in response['ResultsByTime']
        )
        
        result = {
            'total_cost': round(total_cost, 2),
            'threshold': threshold,
            'alert_triggered': total_cost > threshold
        }
        
        # Send alert if needed
        if total_cost > threshold and sns_topic:
            sns_client.publish(
                TopicArn=sns_topic,
                Subject='AWS Cost Alert',
                Message=f'Cost: ${total_cost:.2f} exceeds threshold: ${threshold:.2f}'
            )
        
        return {'statusCode': 200, 'body': json.dumps(result)}
        
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}