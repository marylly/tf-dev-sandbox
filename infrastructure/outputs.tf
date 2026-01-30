output "ec2_id" {
  description = "ID da instância EC2"
  value       = aws_instance.dev.id
}

output "ec2_ip" {
  description = "IP público da instância EC2"
  value       = aws_instance.dev.public_ip
}

output "ec2_private_ip" {
  description = "IP privado da instância EC2"
  value       = aws_instance.dev.private_ip
}

output "ssh_command" {
  description = "Comando SSH para conectar ao EC2"
  value       = "ssh -i ${replace(var.ssh_public_key_path, ".pub", "")} ec2-user@${aws_instance.dev.public_ip}"
}

output "vpc_id" {
  description = "ID da VPC"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "ID da subnet pública"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "ID do security group"
  value       = aws_security_group.ec2.id
}
