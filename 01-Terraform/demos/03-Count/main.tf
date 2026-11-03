# Provider declarado uma vez na raiz desta demo.
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

variable "project" {
  default = "fiap-lab"
}

# A rede (VPC + subnets publicas + rotas) ja foi criada na demo 02-Modules e e
# compartilhada pelo curso inteiro. Aqui apenas LEMOS esses recursos por tag (data
# sources): esta demo nao cria, nao altera e nao destroi nada da rede.
data "aws_vpc" "vpc" {
  tags = {
    Name = var.project
  }
}

data "aws_subnets" "all" {
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
  for_each = toset(data.aws_subnets.all.ids)
  id       = each.value
}

# Nem toda Availability Zone oferta todos os tipos de instancia. Em us-east-1, por
# exemplo, a AZ us-east-1e NAO oferta t3.micro. Descobrimos dinamicamente em quais
# AZs o tipo escolhido existe e usamos apenas as subnets dessas AZs.
data "aws_ec2_instance_type_offerings" "supported" {
  filter {
    name   = "instance-type"
    values = [var.instance_type]
  }
  location_type = "availability-zone"
}

locals {
  # Subnets publicas em AZs que ofertam o tipo de instancia escolhido, ordenadas
  # para um resultado deterministico (todo aluno obtem a mesma distribuicao).
  eligible_subnet_ids = sort([
    for s in data.aws_subnet.public : s.id
    if contains(toset(data.aws_ec2_instance_type_offerings.supported.locations), s.availability_zone)
  ])
}

# Application Load Balancer (aws_lb). Diferente do Classic ELB, o ALB opera na
# camada 7 (HTTP) e EXIGE subnets em pelo menos 2 Availability Zones — por isso
# entregamos a ele todas as subnets elegiveis, nao apenas uma.
resource "aws_lb" "web" {
  name               = "quantum-ai-alb"
  load_balancer_type = "application"
  subnets            = local.eligible_subnet_ids
  security_groups    = [aws_security_group.web.id]
}

# O target group agrupa os alvos (as EC2) e define como verificar a saude deles.
resource "aws_lb_target_group" "web" {
  name     = "quantum-ai-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.vpc.id

  # O padrao da AWS espera 300 s antes de soltar um alvo removido. Em aula, 30 s
  # deixam a reducao da frota visivel no console sem esperar 5 minutos.
  deregistration_delay = 30

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 6
  }
}

# O listener recebe o trafego HTTP na porta 80 e encaminha para o target group.
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# A frota de servidores. count = 2 cria duas EC2 identicas; alterar esse numero
# escala a frota para cima ou para baixo num unico apply. As instancias sao
# distribuidas entre as subnets elegiveis (AZs distintas) com element().
resource "aws_instance" "web" {
  count = 2

  instance_type          = var.instance_type
  ami                    = data.aws_ami.amazon_linux.id
  subnet_id              = element(local.eligible_subnet_ids, count.index)
  vpc_security_group_ids = [aws_security_group.web.id]
  iam_instance_profile   = "LabInstanceProfile"

  tags = {
    Name = format("nginx-%03d", count.index + 1)
  }
}

# Provisiona cada servidor da frota via SSM (sem SSH, sem chave). Um terraform_data
# por instancia: envia o script.sh + a pagina, espera terminar e ABORTA o apply se
# falhar — mesma garantia do provisioner SSH. Exige aws CLI + jq (ver pre-requisitos).
resource "terraform_data" "provisiona" {
  count = length(aws_instance.web)

  # fleet_size entra nos gatilhos porque a pagina diz "Instancia N de M": ao mudar o
  # count, TODAS as maquinas sao reprovisionadas (sem recriar a EC2) para que o M
  # continue verdadeiro. site_hash reenvia a pagina se o index.html mudar.
  triggers_replace = {
    instance_id = aws_instance.web[count.index].id
    script_hash = filesha256("${path.module}/script.sh")
    site_hash   = filesha256("${path.module}/site/index.html")
    fleet_size  = length(aws_instance.web)
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      ID="${aws_instance.web[count.index].id}"
      REGION="${var.aws_region}"

      echo "Aguardando a instancia $ID ficar online no SSM..."
      for i in $(seq 1 30); do
        PING=$(aws ssm describe-instance-information \
          --filters "Key=InstanceIds,Values=$ID" --region "$REGION" \
          --query 'InstanceInformationList[0].PingStatus' --output text 2>/dev/null || true)
        [ "$PING" = "Online" ] && break
        sleep 10
      done
      if [ "$PING" != "Online" ]; then
        echo "ERRO: a instancia $ID nao ficou online no SSM a tempo." >&2
        exit 1
      fi

      echo "Provisionando $ID via SSM..."
      # 'commands' do AWS-RunShellScript e uma LISTA de linhas (jq -R le cada linha,
      # jq -s junta num array). As tres primeiras linhas injetam a pagina em base64
      # (acentos, aspas e < > chegam intactos) e a posicao desta maquina na frota.
      # --parameters recebe JSON completo ({"commands": [...]}): a sintaxe abreviada
      # "commands=..." da AWS CLI rejeita linhas que terminam em '\'.
      SITE_B64=$(base64 < "${path.module}/site/index.html" | tr -d '\n')
      PARAMS=$({
        printf 'SITE_B64=%s\n' "$SITE_B64"
        printf 'QC_INDEX=%s\n' "${count.index + 1}"
        printf 'QC_TOTAL=%s\n' "${length(aws_instance.web)}"
        cat "${path.module}/script.sh"
      } | jq -R . | jq -s '{commands: .}')
      CMD=$(aws ssm send-command \
        --instance-ids "$ID" \
        --document-name "AWS-RunShellScript" \
        --comment "Provisionamento Quantum Commerce (01.3)" \
        --parameters "$PARAMS" \
        --region "$REGION" \
        --query 'Command.CommandId' --output text)

      aws ssm wait command-executed --command-id "$CMD" --instance-id "$ID" --region "$REGION" || true

      echo "----- log de $ID -----"
      aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
        --region "$REGION" --query 'StandardOutputContent' --output text
      echo "----------------------"

      STATUS=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --region "$REGION" --query 'Status' --output text)
      echo "Status=$STATUS"
      if [ "$STATUS" != "Success" ]; then
        echo "ERRO: provisionamento de $ID falhou (Status=$STATUS)." >&2
        aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
          --region "$REGION" --query 'StandardErrorContent' --output text >&2
        exit 1
      fi
    EOT
  }
}

# Registra cada instancia da frota no target group do ALB.
resource "aws_lb_target_group_attachment" "web" {
  count            = length(aws_instance.web)
  target_group_arn = aws_lb_target_group.web.arn
  target_id        = aws_instance.web[count.index].id
  port             = 80
}
