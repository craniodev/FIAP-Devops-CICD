terraform {
  backend "s3" {
    # O bucket (base-config-<RM>) chega pelo make bootstrap via
    # -backend-config="bucket=...": cada aluno tem o seu e este arquivo nao muda.
    # A key e propria do Trabalho Final para nunca ler nem destruir o state do
    # runner do Modulo 02 (key gitlab-runner-fleet), que pode existir na conta.
    key    = "trabalho-final/runner.tfstate"
    region = "us-east-1"
  }
}
