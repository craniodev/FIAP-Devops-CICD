provider "aws" {
  region = var.aws_region

  # default_tags aplica estas tags a TODOS os recursos deste provider,
  # eliminando a repeticao de "tags = {...}" recurso a recurso. Padrao de
  # governanca: identifica dono, ambiente e que o recurso e gerido por IaC.
  default_tags {
    tags = {
      Project   = "quantum-commerce"
      ManagedBy = "terraform"
      Lab       = "01-terraform"
    }
  }
}
