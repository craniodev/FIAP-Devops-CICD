# Testes nativos do Terraform para o modulo web-cluster (Requisitos 1, 4 e 5).
# Rodam com 'terraform test' a partir da raiz do repositorio, no workspace dev:
#
#   terraform workspace select dev || terraform workspace new dev
#   terraform test
#
# command = plan: nada e criado na AWS. O plan ainda le a VPC fiap-lab, a AMI e as
# subnets de verdade (data sources), por isso precisa de credenciais AWS validas.
# O terraform test avalia terraform.workspace com o workspace SELECIONADO; os nomes
# esperados abaixo usam terraform.workspace para valer em qualquer ambiente.
#
# expect_failures: o check "alb_esta_no_ar" do modulo (check.tf da demo Count)
# consulta o DNS do ALB, que so existe depois do apply. Em plan ele nao pode ser
# avaliado e o terraform test trataria isso como erro; declarar a falha esperada
# deixa os asserts abaixo decidirem o resultado.

provider "aws" {
  region = "us-east-1"
}

run "um_no" {
  command         = plan
  expect_failures = [check.alb_esta_no_ar] # Se falhar aqui, o check.tf da demo Count sumiu do módulo: revise o Requisito 1.

  module {
    source = "./modules/web-cluster"
  }

  variables {
    node_count = 1
  }

  assert {
    condition     = length(aws_instance.web) == 1
    error_message = "Com node_count = 1 o módulo deveria planejar 1 EC2 (aws_instance.web), mas planejou ${length(aws_instance.web)}. O count de aws_instance.web precisa usar var.node_count. Revise o Requisito 1."
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.web) == 1
    error_message = "Com node_count = 1 deveria existir 1 aws_lb_target_group_attachment.web, mas existem ${length(aws_lb_target_group_attachment.web)}. O count do attachment deve acompanhar a frota: length(aws_instance.web). Revise o Requisito 1."
  }

  assert {
    condition     = length(terraform_data.provisiona) == 1
    error_message = "Com node_count = 1 deveria existir 1 terraform_data.provisiona, mas existem ${length(terraform_data.provisiona)}. O count do provisionamento deve acompanhar a frota: length(aws_instance.web). Revise o Requisito 1."
  }

  assert {
    condition     = aws_instance.web[0].tags["Name"] == "nginx-${terraform.workspace}-001"
    error_message = "A tag Name da EC2 deveria ser nginx-${terraform.workspace}-001, mas é ${aws_instance.web[0].tags["Name"]}. Use format(\"nginx-%s-%03d\", terraform.workspace, count.index + 1). Revise o Requisito 4."
  }
}

run "tres_nos" {
  command         = plan
  expect_failures = [check.alb_esta_no_ar] # Se falhar aqui, o check.tf da demo Count sumiu do módulo: revise o Requisito 1.

  module {
    source = "./modules/web-cluster"
  }

  variables {
    node_count = 3
  }

  assert {
    condition     = length(aws_instance.web) == 3
    error_message = "Com node_count = 3 o módulo deveria planejar 3 EC2 (aws_instance.web), mas planejou ${length(aws_instance.web)}. O count de aws_instance.web precisa usar var.node_count. Revise o Requisito 1."
  }

  assert {
    condition     = length(aws_lb_target_group_attachment.web) == 3
    error_message = "Com node_count = 3 deveriam existir 3 aws_lb_target_group_attachment.web, mas existem ${length(aws_lb_target_group_attachment.web)}. O count do attachment deve acompanhar a frota: length(aws_instance.web). Revise o Requisito 1."
  }

  assert {
    condition     = length(terraform_data.provisiona) == 3
    error_message = "Com node_count = 3 deveriam existir 3 terraform_data.provisiona, mas existem ${length(terraform_data.provisiona)}. O count do provisionamento deve acompanhar a frota: length(aws_instance.web). Revise o Requisito 1."
  }

  assert {
    condition = [for i in aws_instance.web : i.tags["Name"]] == [
      "nginx-${terraform.workspace}-001",
      "nginx-${terraform.workspace}-002",
      "nginx-${terraform.workspace}-003",
    ]
    error_message = "As tags Name das 3 EC2 deveriam ser nginx-${terraform.workspace}-001, nginx-${terraform.workspace}-002 e nginx-${terraform.workspace}-003, mas são ${join(", ", [for i in aws_instance.web : i.tags["Name"]])}. Use format(\"nginx-%s-%03d\", terraform.workspace, count.index + 1). Revise o Requisito 4."
  }

  assert {
    condition     = aws_lb.web.name == "qc-alb-${terraform.workspace}"
    error_message = "O nome do ALB (aws_lb.web) deveria ser qc-alb-${terraform.workspace}, mas é ${aws_lb.web.name}. Use \"qc-alb-$${terraform.workspace}\". Revise o Requisito 5."
  }

  assert {
    condition     = aws_lb_target_group.web.name == "qc-tg-${terraform.workspace}"
    error_message = "O nome do Target Group (aws_lb_target_group.web) deveria ser qc-tg-${terraform.workspace}, mas é ${aws_lb_target_group.web.name}. Use \"qc-tg-$${terraform.workspace}\". Revise o Requisito 5."
  }

  assert {
    condition     = aws_security_group.web.name == "qc-web-${terraform.workspace}"
    error_message = "O nome do Security Group (aws_security_group.web) deveria ser qc-web-${terraform.workspace}, mas é ${aws_security_group.web.name}. Use \"qc-web-$${terraform.workspace}\". Revise o Requisito 5."
  }

  assert {
    condition     = try(aws_security_group.web.tags["Name"], "") == "qc-web-${terraform.workspace}"
    error_message = "A tag Name do Security Group deveria ser qc-web-${terraform.workspace}, mas é \"${try(aws_security_group.web.tags["Name"], "")}\". Revise o Requisito 5."
  }

  assert {
    condition     = !startswith(aws_security_group.web.name, "sg-")
    error_message = "O nome do Security Group (${aws_security_group.web.name}) começa com \"sg-\", prefixo que a AWS reserva para os IDs e recusa no apply. Use qc-web-${terraform.workspace}. Revise o Requisito 5."
  }

  # O DNS do ALB so existe depois do apply: no plan o valor e desconhecido e uma
  # comparacao direta nao pode ser avaliada. Envolver o output numa lista mede
  # "o output existe" sem ler o valor. Se o modulo nao declarar alb_dns, o
  # terraform test para nesta linha com "Reference to undeclared output value".
  assert {
    condition     = length([output.alb_dns]) == 1 # Sem o output alb_dns no módulo (renomeie o alb_public da demo): revise o Requisito 1.
    error_message = "O módulo deveria declarar o output alb_dns com value = aws_lb.web.dns_name. Revise o Requisito 1."
  }
}
