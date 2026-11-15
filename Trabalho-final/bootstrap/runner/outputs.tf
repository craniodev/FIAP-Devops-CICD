output "instance_id" {
  description = "ID da instancia do runner. O make bootstrap usa no inventario do Ansible (conexao via SSM)."
  value       = aws_instance.runner.id
}
