#!/bin/bash
# Fix RDS database conflict
# Usage: ./fix-rds-conflict.sh <environment>

ENVIRONMENT="${1:-lower}"

echo "🔧 Fixing RDS conflict for $ENVIRONMENT environment"

cd infra/two-network-setup

# Try to import existing database
DB_IDENTIFIER="health-app-$ENVIRONMENT-db"
echo "📥 Attempting to import existing database: $DB_IDENTIFIER"

if terraform import aws_db_instance.main $DB_IDENTIFIER; then
  echo "✅ Database imported successfully"
else
  echo "❌ Import failed - database may not exist or have different name"
  
  # List existing databases
  echo "📋 Existing RDS instances:"
  aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output table
fi