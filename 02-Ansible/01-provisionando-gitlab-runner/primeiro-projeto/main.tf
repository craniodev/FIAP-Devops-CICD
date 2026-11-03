variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "project" {
  type        = string
  description = "Prefixo dos recursos da API de pedidos da Quantum Commerce."
  default     = "quantum-ai"
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "quantum-commerce"
      ManagedBy = "terraform"
      Lab       = "03-cicd"
    }
  }
}

# Conta atual: usamos o LabRole (unica role utilizavel no Academy) como execution
# role da Lambda, em vez de criar uma role nova (proibido no Learner Lab).
data "aws_caller_identity" "current" {}
