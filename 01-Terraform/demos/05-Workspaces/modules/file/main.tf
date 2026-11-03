locals {
  env = terraform.workspace

  # Cada workspace tem seu proprio "tamanho" de servidor. Em dev, uma maquina
  # pequena e barata; em prod, uma maior. O mesmo codigo, parametrizado pelo
  # workspace atual — sem duplicar arquivos.
  context = {
    default = { instance_type = "t3.micro" }
    dev     = { instance_type = "t3.micro" }
    homol   = { instance_type = "t3.small" }
    prod    = { instance_type = "t3.small" }
  }

  # lookup com fallback para 'default' caso o workspace nao esteja no mapa.
  context_variables = lookup(local.context, local.env, local.context["default"])
}

# A VPC compartilhada fiap-lab (criada na demo 01.2) e so LIDA aqui, por data
# source: dev e prod nascem na MESMA rede, e o destroy desta demo nunca a apaga.
# Descobrimos uma subnet publica em AZ que oferta o tipo de instancia escolhido,
# mesmo padrao das demos 01.3 e 01.4.
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

data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = [local.context_variables.instance_type]
  }
  location_type = "availability-zone"
}

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

locals {
  eligible_subnet_ids = sort([
    for s in data.aws_subnet.public : s.id
    if contains(toset(data.aws_ec2_instance_type_offerings.supported.locations), s.availability_zone)
  ])
}

# Um servidor por ambiente. O tipo vem do mapa acima conforme o workspace, e o
# nome carrega o ambiente — todo recurso fica rastreavel por workspace.
resource "aws_instance" "server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = local.context_variables.instance_type
  subnet_id     = local.eligible_subnet_ids[0]

  tags = {
    Name = "${var.project}-${local.env}"
    Env  = local.env
  }
}
