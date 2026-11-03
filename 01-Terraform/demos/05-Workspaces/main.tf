provider "aws" {
  region = "us-east-1"

  # default_tags: tags de governanca aplicadas a todos os recursos do provider.
  default_tags {
    tags = {
      Project   = "quantum-commerce"
      ManagedBy = "terraform"
      Lab       = "01-terraform"
    }
  }
}

module "servidor" {
  source  = "./modules/file"
  project = "quantum-ai"
}
