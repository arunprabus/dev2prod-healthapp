terraform {
  backend "s3" {
    # Backend configuration provided via -backend-config flags
    # bucket = "health-app-terraform-state"
    # key    = "health-app-{env}.tfstate"
    # region = "ap-south-1"
  }
}