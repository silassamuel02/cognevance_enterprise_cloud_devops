variable "project_name" {
  description = "Project identifier"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for the compute cluster"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID used by the cluster nodes"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for cluster nodes"
  type        = string
}

variable "worker_count" {
  description = "Number of Docker Swarm worker nodes"
  type        = number
  default     = 1

  validation {
    condition     = var.worker_count >= 1 && var.worker_count <= 5
    error_message = "worker_count must be between 1 and 5."
  }
}

variable "admin_cidr" {
  description = "Optional restricted administrator IP range for SSH"
  type        = string
  default     = null
  nullable    = true
}

variable "key_name" {
  description = "Optional existing EC2 key pair name"
  type        = string
  default     = null
  nullable    = true
}
