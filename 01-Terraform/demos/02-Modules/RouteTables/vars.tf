variable "project" {
  default = "fiap-lab"
}

data "aws_vpc" "vpc" {
  tags = {
    Name = var.project
  }
}

data "aws_internet_gateway" "igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

variable "env" {
  description = "Ambiente logico."
  default     = "prod"

  validation {
    condition     = contains(["dev", "homol", "prod"], var.env)
    error_message = "env deve ser um de: dev, homol, prod."
  }
}

output "vpc_id" {
  value = data.aws_vpc.vpc.id
}

variable "aws_region" {
  description = "Regiao AWS. O Learner Lab so permite us-east-1 ou us-west-2."
  default     = "us-east-1"

  validation {
    condition     = contains(["us-east-1", "us-west-2"], var.aws_region)
    error_message = "O AWS Academy Learner Lab so permite us-east-1 ou us-west-2."
  }
}
