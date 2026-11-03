terraform {
  backend "s3" {
    # O passo 3 do README troca este placeholder pelo seu base-config-<SEU-RM>.
    # O bucket guarda o state do Terraform (o mapa da infra), nao dados de clientes.
    bucket = "base-config-SEU-RM"
    key    = "demo-state/quantum/terraform.tfstate"
    region = "us-east-1"

    # use_lockfile (Terraform 1.10+): trava o estado usando um objeto .tflock
    # no proprio S3, sem precisar de uma tabela DynamoDB separada. Impede que
    # dois 'apply' simultaneos corrompam o estado, a dor do time da Quantum Commerce.
    use_lockfile = true
  }
}
