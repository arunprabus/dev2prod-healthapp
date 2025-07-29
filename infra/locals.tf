# Common tags and naming conventions
locals {
  # Project information
  project_name = "health-app"
  
  # Common tags applied to all resources
  common_tags = {
    # Required tags (Mandatory)
    Project         = local.project_name
    Environment     = var.network_tier
    ManagedBy      = "terraform"
    Owner          = var.team_name
    CostCenter     = var.cost_center
    Application    = "health-api"
    BackupRequired = var.backup_required
    
    # Business tags
    BusinessUnit       = "healthcare"
    Department         = "engineering"
    DataClassification = var.data_classification
    ComplianceScope    = var.compliance_scope
    
    # Technical tags
    GitRepo           = "dev2prod-healthapp"
    CreatedDate       = formatdate("YYYY-MM-DD", timestamp())
    TerraformVersion  = "1.6.0"
    
    # Operational tags
    Schedule          = var.network_tier == "higher" ? "24x7" : "business-hours"
    AutoShutdown      = var.network_tier == "higher" ? "disabled" : "enabled"
    MonitoringLevel   = var.network_tier == "higher" ? "high" : "medium"
    AlertingLevel     = var.network_tier == "higher" ? "critical" : "medium"
  }
  
  # Naming conventions
  name_prefix = "${local.project_name}-${var.network_tier}"
  
  # Resource names
  vpc_name              = "${local.name_prefix}-vpc"
  public_subnet_name    = "${local.name_prefix}-subnet-public"
  private_subnet_name   = "${local.name_prefix}-subnet-private"
  igw_name             = "${local.name_prefix}-igw"
  route_table_name     = "${local.name_prefix}-rt"
  security_group_name  = "${local.name_prefix}-sg"
  ec2_name             = "${local.name_prefix}-k8s-master"
  rds_name             = "${local.name_prefix}-db"
  s3_bucket_name       = "${local.name_prefix}-terraform-state"
  
  # Kubernetes labels
  k8s_labels = {
    "app.kubernetes.io/name"       = "health-api"
    "app.kubernetes.io/instance"   = "${local.project_name}-${var.network_tier}"
    "app.kubernetes.io/component"  = "backend"
    "app.kubernetes.io/part-of"    = local.project_name
    "app.kubernetes.io/managed-by" = "terraform"
    "environment"                  = var.network_tier
    "project"                      = local.project_name
    "team"                         = var.team_name
    "cost-center"                  = var.cost_center
  }
}