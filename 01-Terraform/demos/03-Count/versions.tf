terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    # Usado pelo check block para validar, pos-deploy, se o ALB responde HTTP 200.
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
  }
}
