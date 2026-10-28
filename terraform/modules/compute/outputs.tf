output "instance_id" {
  description = "EC2 manager instance ID"
  value       = aws_instance.manager.id
}

output "public_ip" {
  description = "Public IP address of the manager"
  value       = aws_instance.manager.public_ip
}

output "public_dns" {
  description = "Public DNS name of the manager"
  value       = aws_instance.manager.public_dns
}

output "security_group_id" {
  description = "Security group shared by Swarm nodes"
  value       = aws_security_group.manager.id
}

output "worker_ids" {
  description = "EC2 worker instance IDs"
  value       = aws_instance.worker[*].id
}

output "worker_private_ips" {
  description = "Private IP addresses of the worker nodes"
  value       = aws_instance.worker[*].private_ip
}
