output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.manager.id
}

output "public_ip" {
  description = "Public IP address of the Docker infrastructure host"
  value       = aws_instance.manager.public_ip
}

output "public_dns" {
  description = "Public DNS name of the Docker infrastructure host"
  value       = aws_instance.manager.public_dns
}

output "security_group_id" {
  description = "Security group ID attached to the manager"
  value       = aws_security_group.manager.id
}
