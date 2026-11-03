output "address" {
  description = "Mapa id-da-instancia => DNS publico de cada servidor da frota."
  value = {
    for instance in aws_instance.web :
    instance.id => "http://${instance.public_dns}"
  }
}

output "alb_public" {
  description = "DNS publico do Application Load Balancer (ponto de entrada da frota)."
  value       = aws_lb.web.dns_name
}
