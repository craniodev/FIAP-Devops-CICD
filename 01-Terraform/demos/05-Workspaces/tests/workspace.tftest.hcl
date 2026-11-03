# Teste nativo do Terraform (arquivo .tftest.hcl, TF 1.6+). Roda com 'terraform test'.
# Aqui validamos, SEM criar infra de verdade (command = plan), que o mapa de
# contexto entrega o tipo de instancia correto para o workspace atual.
#
# O 'terraform test' avalia terraform.workspace com o workspace SELECIONADO no
# terminal. O lab roda este teste no workspace dev, cujo mapa define t3.micro.
# Em prod (t3.small) a assercao falha de proposito: prova que o teste enxerga o
# ambiente atual. Tambem falha se alguem trocar o tipo de dev no mapa de
# contexto (ex: tipo invalido no Learner Lab). Remover a entrada dev NAO quebra
# o teste: o lookup cai no default, que tambem e t3.micro.

run "dev_usa_t3_micro" {
  command = plan

  assert {
    condition     = output.instance_type == "t3.micro"
    error_message = "No workspace dev, o instance_type deveria ser t3.micro. Confira o workspace atual com: terraform workspace show"
  }
}
