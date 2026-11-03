# Tabela que guarda o status de cada pedido da Quantum Commerce. On-demand (PAY_PER_REQUEST):
# sem capacidade provisionada, custo proporcional ao uso e dentro do free-tier.
resource "aws_dynamodb_table" "pedidos" {
  name         = "${var.project}-pedidos"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "pedido_id"

  attribute {
    name = "pedido_id"
    type = "S"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled = true
  }
}
