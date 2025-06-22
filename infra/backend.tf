# Backend configuration for Terraform state
# Configure via backend config file or CLI parameters

terraform {
  backend "s3" {
    # bucket = "your-terraform-state-bucket"
    # key    = "health-app-{environment}.tfstate"
    # region = "ap-south-1"
    # encrypt = true
    # dynamodb_table = "terraform-state-lock"
  }
}