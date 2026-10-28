variable "aws_region" {
  description = "AWS region for the project"
  type        = string
  default     = "ap-south-1"
}

variable "project_name" {
  description = "Project identifier used for resource names and tags"
  type        = string
  default     = "cognevance-enterprise-devops"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR range for the project VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "CIDR range for the demonstration public subnet"
  type        = string
  default     = "10.20.1.0/24"
}

variable "instance_type" {
  description = "EC2 instance type for the initial demonstration"
  type        = string
  default     = "t3.micro"
}

variable "admin_cidr" {
  description = "Your trusted public IP in CIDR notation, for example 203.0.113.10/32"
  type        = string
  default     = null
  nullable    = true

  validation {
    condition     = var.admin_cidr == null || can(cidrnetmask(var.admin_cidr))
    error_message = "admin_cidr must be a valid CIDR range or null."
  }
}

variable "key_name" {
  description = "Existing EC2 key pair name, or null if not configured"
  type        = string
  default     = null
  nullable    = true
}
