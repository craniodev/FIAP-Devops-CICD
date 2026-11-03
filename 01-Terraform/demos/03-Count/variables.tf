variable "aws_region" {
  description = "Regiao AWS. O Learner Lab so permite us-east-1 ou us-west-2."
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O AWS Academy Learner Lab so permite us-east-1 ou us-west-2."
  }
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

variable "instance_type" {
  description = "Tipo de instancia EC2 da frota web. Usado tambem para descobrir as AZs que o ofertam."
  default     = "t3.micro"

  # O Learner Lab so permite os tamanhos nano/micro/small/medium/large. Validar
  # aqui evita um erro tardio de "instance type not authorized" durante o apply.
  validation {
    condition     = can(regex("\\.(nano|micro|small|medium|large)$", var.instance_type))
    error_message = "O Learner Lab so permite tamanhos nano, micro, small, medium ou large."
  }
}
