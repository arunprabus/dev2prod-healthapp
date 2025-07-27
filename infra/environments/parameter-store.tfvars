# Parameter Store Configuration for Health App
app_parameters = {
  "database/host" = {
    type        = "String"
    value       = "health-app-db.cluster-xyz.ap-south-1.rds.amazonaws.com"
    description = "Database host endpoint"
  }
  
  "database/port" = {
    type        = "String"
    value       = "5432"
    description = "Database port"
  }
  
  "database/name" = {
    type        = "String"
    value       = "healthapp"
    description = "Database name"
  }
  
  "database/username" = {
    type        = "String"
    value       = "healthapp_user"
    description = "Database username"
  }
  
  "database/password" = {
    type        = "SecureString"
    value       = "change-me-in-production"
    description = "Database password (encrypted)"
  }
  
  "api/jwt_secret" = {
    type        = "SecureString"
    value       = "your-jwt-secret-key-here"
    description = "JWT secret for API authentication"
  }
  
  "api/port" = {
    type        = "String"
    value       = "3000"
    description = "API server port"
  }
  
  "monitoring/enabled" = {
    type        = "String"
    value       = "true"
    description = "Enable monitoring features"
  }
}