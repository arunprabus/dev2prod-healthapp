variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for VPC"
  type        = string
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-south-1a", "ap-south-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  type        = list(string)
}

variable "peer_vpc_id" {
  description = "VPC ID to peer with (monitoring VPC)"
  type        = string
  default     = null
}

variable "monitoring_vpc_cidr" {
  description = "CIDR block of monitoring VPC for routing"
  type        = string
  default     = "10.30.0.0/16"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}