output "vpc_id" {
  description = "ID of the project VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "ID of the public subnet"
  value       = aws_subnet.public.id
}

output "availability_zone" {
  description = "Availability zone used by the public subnet"
  value       = aws_subnet.public.availability_zone
}
