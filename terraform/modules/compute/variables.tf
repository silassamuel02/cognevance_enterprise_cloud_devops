variable "project_name" {
  description = "Project identifier"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the compute instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID for the compute instance"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "admin_cidr" {
  description = "Approved administrator IP range for SSH, or null to disable SSH"
  type        = string
  default     = null
  nullable    = true
}

variable "key_name" {
  description = "Existing EC2 key pair name, or null if not configured"
  type        = string
  default     = null
  nullable    = true
}
