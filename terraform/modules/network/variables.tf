variable "project_name" {
  description = "Project identifier used for resource names"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR range for the project VPC"
  type        = string
}

variable "public_subnet_cidr" {
  description = "CIDR range for the public subnet"
  type        = string
}
