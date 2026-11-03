# A VPC fiap-lab da Quantum Commerce ja existe (criada na demo 01.2) e e
# persistente: os proximos modulos tambem a usam. Aqui ela so e LIDA por data
# source, entao o destroy desta demo apaga a EC2 de teste e nunca a rede.
data "aws_vpc" "vpc" {
  tags = {
    Name = "fiap-lab"
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "tag:Tier"
    values = ["Public"]
  }
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.vpc.id]
  }
}

data "aws_subnet" "public" {
  for_each = toset(data.aws_subnets.public.ids)
  id       = each.value
}

# Nem toda AZ oferta t3.micro (us-east-1e nao oferta). Filtramos as subnets para
# as AZs que ofertam o tipo, evitando erro de "Unsupported instance type".
data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = ["t3.micro"]
  }
  location_type = "availability-zone"
}

locals {
  eligible_subnet_ids = sort([
    for s in data.aws_subnet.public : s.id
    if contains(toset(data.aws_ec2_instance_type_offerings.supported.locations), s.availability_zone)
  ])
}

resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = local.eligible_subnet_ids[0]

  tags = {
    Name        = "quantum-state-demo"
    Responsavel = var.responsavel
  }
}
