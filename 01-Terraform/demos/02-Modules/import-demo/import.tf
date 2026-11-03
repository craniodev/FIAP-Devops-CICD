terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ID do Security Group criado "na mao" no passo 11. Voce passa este valor na linha
# de comando (-var "sg_id=$SG_ID"), entao NAO precisa editar este arquivo.
variable "sg_id" {
  description = "ID do Security Group existente a ser adotado pelo Terraform."
  type        = string
}

# A VPC da Quantum Commerce e descoberta por tag (igual as outras demos), entao nao e
# preciso colar o id da VPC em lugar nenhum.
data "aws_vpc" "vpc" {
  tags = {
    Name = "fiap-lab"
  }
}

# O import block diz: "este recurso ja existe na AWS com este id; passe a
# gerencia-lo com este endereco no Terraform". Declarativo e versionavel.
import {
  to = aws_security_group.legado
  id = var.sg_id
}

resource "aws_security_group" "legado" {
  name        = "quantum-legado-sg"
  description = "SG criado na mao para demo de import"
  vpc_id      = data.aws_vpc.vpc.id
}
