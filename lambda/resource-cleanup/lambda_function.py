import json
import boto3
import os

def lambda_handler(event, context):
    """Resource cleanup Lambda - stops/terminates expensive resources"""
    
    ec2 = boto3.client('ec2')
    rds = boto3.client('rds')
    
    environment = os.environ.get('ENVIRONMENT', 'dev')
    
    try:
        results = []
        
        # Stop RDS instances (except prod)
        if environment != 'prod':
            rds_instances = rds.describe_db_instances()
            for db in rds_instances['DBInstances']:
                if db['DBInstanceStatus'] == 'available' and environment in db['DBInstanceIdentifier']:
                    rds.stop_db_instance(DBInstanceIdentifier=db['DBInstanceIdentifier'])
                    results.append(f"Stopped RDS: {db['DBInstanceIdentifier']}")
        
        # Stop EC2 instances with AutoShutdown tag
        instances = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:AutoShutdown', 'Values': ['enabled']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in instances['Reservations']:
            for instance in reservation['Instances']:
                ec2.stop_instances(InstanceIds=[instance['InstanceId']])
                results.append(f"Stopped EC2: {instance['InstanceId']}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cleanup completed',
                'actions': results
            })
        }
        
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}