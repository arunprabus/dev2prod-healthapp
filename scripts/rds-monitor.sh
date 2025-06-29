#!/bin/bash

DB_INSTANCE="healthapidb"
MAX_HOURS=120
LOG_FILE="rds-runtime.log"

# Get current status and launch time
STATUS=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE --query "DBInstances[0].DBInstanceStatus" --output text)
LAUNCH_TIME=$(aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE --query "DBInstances[0].InstanceCreateTime" --output text)

if [ "$STATUS" = "available" ]; then
    # Calculate runtime hours
    CURRENT_TIME=$(date -u +%s)
    LAUNCH_TIMESTAMP=$(date -d "$LAUNCH_TIME" +%s)
    RUNTIME_SECONDS=$((CURRENT_TIME - LAUNCH_TIMESTAMP))
    RUNTIME_HOURS=$((RUNTIME_SECONDS / 3600))
    
    echo "$(date): RDS Runtime: ${RUNTIME_HOURS}h/${MAX_HOURS}h" | tee -a $LOG_FILE
    
    if [ $RUNTIME_HOURS -ge $MAX_HOURS ]; then
        echo "$(date): Stopping RDS instance - reached ${MAX_HOURS}h limit" | tee -a $LOG_FILE
        aws rds stop-db-instance --db-instance-identifier $DB_INSTANCE
        echo "$(date): RDS stopped for dev purposes" | tee -a $LOG_FILE
    fi
else
    echo "$(date): RDS Status: $STATUS" | tee -a $LOG_FILE
fi