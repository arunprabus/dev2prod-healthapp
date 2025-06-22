terraform {
  backend "s3" {
    # Configure via CLI parameters:
    # -backend-config="bucket=your-terraform-state-bucket"
    # -backend-config="key=health-app-{environment}.tfstate"
    # -backend-config="region=ap-south-1"
  }
}