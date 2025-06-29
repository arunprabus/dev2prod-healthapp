variable "requestor_vpc_id" {
  description = "Requestor VPC ID"
  type        = string
}

variable "acceptor_vpc_id" {
  description = "Acceptor VPC ID"
  type        = string
}

variable "requestor_route_table_ids" {
  description = "Requestor route table IDs"
  type        = list(string)
}

variable "acceptor_route_table_ids" {
  description = "Acceptor route table IDs"
  type        = list(string)
}

variable "requestor_cidr" {
  description = "Requestor VPC CIDR"
  type        = string
}

variable "acceptor_cidr" {
  description = "Acceptor VPC CIDR"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}