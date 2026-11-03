variable "aws_region" {
  description = "Regiao AWS. O Learner Lab so permite us-east-1 ou us-west-2."
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O AWS Academy Learner Lab so permite us-east-1 ou us-west-2."
  }
}

# Na Parte 3, cada engenheiro passa um valor diferente com -var. Isso gera uma
# mudanca in-place pequena, entao o apply para no "Enter a value:" segurando o
# lock, e da para ver o segundo apply ser bloqueado. Sem mudanca pendente, o
# apply terminaria na hora com "No changes" e soltaria o lock antes do teste.
variable "responsavel" {
  description = "Quem fez a ultima mudanca nesta EC2 de teste (tag Responsavel)."
  type        = string
  default     = "time-ia"
}

# Busca dinamica da Amazon Linux 2023 mais recente, evitando AMIs hardcoded que expiram.
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}
