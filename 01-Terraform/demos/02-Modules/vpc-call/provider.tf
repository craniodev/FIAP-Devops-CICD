variable "aws_region" {
  description = "Regiao AWS onde a infraestrutura sera criada."
  default     = "us-east-1"
}

provider "aws" {
  region = var.aws_region

  # default_tags: tags de governanca aplicadas a todos os recursos do provider.
  default_tags {
    tags = {
      Project   = "quantum-commerce"
      ManagedBy = "terraform"
      Lab       = "01-terraform"
    }
  }
}
