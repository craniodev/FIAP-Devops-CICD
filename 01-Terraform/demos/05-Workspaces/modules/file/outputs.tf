output "env" {
  value       = local.env
  description = "Workspace (ambiente) atual."
}

output "instance_type" {
  value       = aws_instance.server.instance_type
  description = "Tipo de instancia provisionado para este workspace (dev=t3.micro, prod=t3.small)."
}

output "instance_id" {
  value       = aws_instance.server.id
  description = "ID da instancia criada neste workspace."
}
