# check block (Terraform 1.5+): valida, como ULTIMO passo do apply, se o ALB
# esta de fato respondendo HTTP 200 — uma verificacao de saude pos-deploy.
# Diferente de um recurso, um check que falha gera um AVISO (warning), nao um
# erro: ele nao bloqueia nem desfaz o apply. Serve para sinalizar "subiu, mas
# ainda nao esta saudavel" sem quebrar o fluxo.
check "alb_esta_no_ar" {
  data "http" "alb" {
    url = "http://${aws_lb.web.dns_name}/"
  }

  assert {
    condition     = data.http.alb.status_code == 200
    error_message = "O ALB ainda nao respondeu 200 (pode estar em warm-up ou as instancias ainda registrando no target group). Rode 'terraform plan' de novo em ~1 min."
  }
}
