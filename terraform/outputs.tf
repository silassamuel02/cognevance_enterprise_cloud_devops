output "vpc_id" {
  description = "ID of the project VPC"
  value       = module.network.vpc_id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = module.network.public_subnet_id
}

output "ec2_instance_id" {
  description = "ID of the Docker infrastructure host"
  value       = module.compute.instance_id
}

output "ec2_public_ip" {
  description = "Public IP of the Docker infrastructure host"
  value       = module.compute.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS name of the Docker infrastructure host"
  value       = module.compute.public_dns
}

output "security_group_id" {
  description = "Security group attached to the infrastructure host"
  value       = module.compute.security_group_id
}
