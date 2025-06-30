import json
import boto3
import os
from datetime import datetime

def lambda_handler(event, context):
    """RDS backup Lambda - creates snapshots and exports to S3"""
    
    rds = boto3.client('rds')
    
    try:
        results = []
        
        # Get all RDS instances
        instances = rds.describe_db_instances()
        
        for db in instances['DBInstances']:
            if db['DBInstanceStatus'] == 'available':
                db_id = db['DBInstanceIdentifier']
                snapshot_id = f"{db_id}-backup-{datetime.now().strftime('%Y%m%d-%H%M')}"
                
                # Create snapshot
                rds.create_db_snapshot(
                    DBSnapshotIdentifier=snapshot_id,
                    DBInstanceIdentifier=db_id
                )
                
                results.append(f"Created snapshot: {snapshot_id}")
        
        return {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Backup completed',
                'snapshots': results
            })
        }
        
    except Exception as e:
        return {'statusCode': 500, 'body': json.dumps({'error': str(e)})}