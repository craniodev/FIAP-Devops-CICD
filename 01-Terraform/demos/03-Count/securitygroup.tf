# Security group da frota: libera apenas HTTP (porta 80) de entrada. Nao ha mais
# regra de SSH (porta 22) — o provisionamento agora e via SSM, que nao usa portas
# de entrada (o SSM Agent fala de dentro para fora com o servico).
resource "aws_security_group" "web" {
  vpc_id = data.aws_vpc.vpc.id
  name   = "quantum-ai-http"

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "quantum-ai-http"
  }
}
