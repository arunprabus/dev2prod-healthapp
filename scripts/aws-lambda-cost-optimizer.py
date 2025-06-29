import boto3
import json
from datetime import datetime, timezone
import logging

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    """
    AWS Lambda function for cost optimization
    Automatically stops dev resources after business hours
    """
    
    try:
        # Initialize AWS clients
        ec2 = boto3.client('ec2')
        rds = boto3.client('rds')
        
        results = {
            'stopped_instances': [],
            'stopped_databases': [],
            'errors': []
        }
        
        # Check if it's after business hours
        if is_after_hours():
            logger.info("After hours detected - starting cost optimization")
            
            # Stop EC2 instances
            stopped_instances = stop_dev_instances(ec2)
            results['stopped_instances'] = stopped_instances
            
            # Stop RDS instances
            stopped_databases = stop_dev_databases(rds)
            results['stopped_databases'] = stopped_databases
            
        else:
            logger.info("During business hours - skipping cost optimization")
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Cost optimization completed successfully',
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Error in cost optimization: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Cost optimization failed',
                'error': str(e)
            })
        }

def is_after_hours():
    """
    Check if current time is after business hours
    Business hours: 9 AM - 6 PM UTC
    """
    now = datetime.now(timezone.utc)
    return now.hour >= 18 or now.hour < 9

def stop_dev_instances(ec2):
    """Stop development EC2 instances with AutoShutdown enabled"""
    stopped_instances = []
    
    try:
        # Find running dev instances with AutoShutdown enabled
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Environment', 'Values': ['dev']},
                {'Name': 'tag:AutoShutdown', 'Values': ['enabled']},
                {'Name': 'instance-state-name', 'Values': ['running']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                
                # Get instance name from tags
                instance_name = 'Unknown'
                for tag in instance.get('Tags', []):
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
                        break
                
                # Stop the instance
                ec2.stop_instances(InstanceIds=[instance_id])
                
                stopped_instances.append({
                    'instance_id': instance_id,
                    'name': instance_name,
                    'type': instance['InstanceType']
                })
                
                logger.info(f"Stopped EC2 instance: {instance_name} ({instance_id})")
                
    except Exception as e:
        logger.error(f"Error stopping EC2 instances: {str(e)}")
        
    return stopped_instances

def stop_dev_databases(rds):
    """Stop development RDS instances with AutoShutdown enabled"""
    stopped_databases = []
    
    try:
        # Get all RDS instances
        response = rds.describe_db_instances()
        
        for db_instance in response['DBInstances']:
            db_identifier = db_instance['DBInstanceIdentifier']
            db_status = db_instance['DBInstanceStatus']
            
            # Skip if not available
            if db_status != 'available':
                continue
                
            # Get tags for the database
            try:
                tags_response = rds.list_tags_for_resource(
                    ResourceName=db_instance['DBInstanceArn']
                )
                tags = tags_response['TagList']
                
                # Check if it's a dev database with AutoShutdown enabled
                is_dev = False
                auto_shutdown = False
                
                for tag in tags:
                    if tag['Key'] == 'Environment' and tag['Value'] == 'dev':
                        is_dev = True
                    if tag['Key'] == 'AutoShutdown' and tag['Value'] == 'enabled':
                        auto_shutdown = True
                
                # Stop if conditions are met
                if is_dev and auto_shutdown:
                    rds.stop_db_instance(DBInstanceIdentifier=db_identifier)
                    
                    stopped_databases.append({
                        'db_identifier': db_identifier,
                        'engine': db_instance['Engine'],
                        'instance_class': db_instance['DBInstanceClass']
                    })
                    
                    logger.info(f"Stopped RDS instance: {db_identifier}")
                    
            except Exception as e:
                logger.error(f"Error processing database {db_identifier}: {str(e)}")
                continue
                
    except Exception as e:
        logger.error(f"Error stopping RDS instances: {str(e)}")
        
    return stopped_databases

def start_dev_resources(event, context):
    """
    Separate function to start dev resources during business hours
    Can be triggered by CloudWatch Events
    """
    
    try:
        ec2 = boto3.client('ec2')
        rds = boto3.client('rds')
        
        results = {
            'started_instances': [],
            'started_databases': []
        }
        
        # Check if it's business hours
        if is_business_hours():
            logger.info("Business hours detected - starting dev resources")
            
            # Start EC2 instances
            started_instances = start_dev_instances(ec2)
            results['started_instances'] = started_instances
            
            # Start RDS instances
            started_databases = start_dev_databases(rds)
            results['started_databases'] = started_databases
            
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Resource startup completed',
                'results': results
            })
        }
        
    except Exception as e:
        logger.error(f"Error starting resources: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Resource startup failed',
                'error': str(e)
            })
        }

def is_business_hours():
    """Check if current time is during business hours"""
    now = datetime.now(timezone.utc)
    return 9 <= now.hour < 18

def start_dev_instances(ec2):
    """Start stopped development EC2 instances"""
    started_instances = []
    
    try:
        response = ec2.describe_instances(
            Filters=[
                {'Name': 'tag:Environment', 'Values': ['dev']},
                {'Name': 'tag:AutoShutdown', 'Values': ['enabled']},
                {'Name': 'instance-state-name', 'Values': ['stopped']}
            ]
        )
        
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                instance_id = instance['InstanceId']
                
                # Get instance name
                instance_name = 'Unknown'
                for tag in instance.get('Tags', []):
                    if tag['Key'] == 'Name':
                        instance_name = tag['Value']
                        break
                
                # Start the instance
                ec2.start_instances(InstanceIds=[instance_id])
                
                started_instances.append({
                    'instance_id': instance_id,
                    'name': instance_name
                })
                
                logger.info(f"Started EC2 instance: {instance_name} ({instance_id})")
                
    except Exception as e:
        logger.error(f"Error starting EC2 instances: {str(e)}")
        
    return started_instances

def start_dev_databases(rds):
    """Start stopped development RDS instances"""
    started_databases = []
    
    try:
        response = rds.describe_db_instances()
        
        for db_instance in response['DBInstances']:
            db_identifier = db_instance['DBInstanceIdentifier']
            db_status = db_instance['DBInstanceStatus']
            
            # Skip if not stopped
            if db_status != 'stopped':
                continue
                
            # Get tags
            try:
                tags_response = rds.list_tags_for_resource(
                    ResourceName=db_instance['DBInstanceArn']
                )
                tags = tags_response['TagList']
                
                # Check conditions
                is_dev = False
                auto_shutdown = False
                
                for tag in tags:
                    if tag['Key'] == 'Environment' and tag['Value'] == 'dev':
                        is_dev = True
                    if tag['Key'] == 'AutoShutdown' and tag['Value'] == 'enabled':
                        auto_shutdown = True
                
                # Start if conditions are met
                if is_dev and auto_shutdown:
                    rds.start_db_instance(DBInstanceIdentifier=db_identifier)
                    
                    started_databases.append({
                        'db_identifier': db_identifier,
                        'engine': db_instance['Engine']
                    })
                    
                    logger.info(f"Started RDS instance: {db_identifier}")
                    
            except Exception as e:
                logger.error(f"Error processing database {db_identifier}: {str(e)}")
                continue
                
    except Exception as e:
        logger.error(f"Error starting RDS instances: {str(e)}")
        
    return started_databases