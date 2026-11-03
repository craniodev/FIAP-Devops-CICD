# A instancia NAO tem mais key_name, nem provisioner/connection SSH. O acesso
# para rodar o script de provisionamento e feito via AWS Systems Manager (SSM),
# usando o instance profile LabInstanceProfile (que ja carrega a permissao
# AmazonSSMManagedInstanceCore na LabRole do Learner Lab). Sem chave privada,
# sem porta 22 aberta.
resource "aws_instance" "example" {
  ami                  = data.aws_ami.amazon_linux.id
  instance_type        = "t3.micro"
  iam_instance_profile = "LabInstanceProfile"

  tags = {
    Name = "quantum-ai-web"
  }
}

# Provisionamento via SSM: envia o script.sh para a instancia, ESPERA terminar e
# ABORTA o apply se o script falhar — mesma garantia de um provisioner SSH, mas
# sem chave e com o log completo capturado. Exige aws CLI + jq (ver pre-requisitos
# do lab; o devcontainer ja instala ambos).
resource "terraform_data" "provisiona" {
  # Reexecuta se a instancia for recriada, se o script mudar ou se a pagina mudar.
  triggers_replace = {
    instance_id = aws_instance.example.id
    script_hash = filesha256("${path.module}/script.sh")
    site_hash   = filesha256("${path.module}/site/index.html")
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -euo pipefail
      ID="${aws_instance.example.id}"
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
        echo "ERRO: a instancia nao ficou online no SSM a tempo." >&2
        exit 1
      fi

      echo "Enviando o script de provisionamento via SSM..."
      # O parametro 'commands' do AWS-RunShellScript e uma LISTA de linhas. Montamos
      # com jq (-R le cada linha como string, -s junta tudo num array). Passar o
      # script como uma unica string quebra a execucao ("required file not found").
      # A primeira linha injeta a pagina em base64 (sem quebras), para que acentos,
      # aspas, $, < e > cheguem intactos sem SSH nem S3. --parameters recebe JSON
      # completo ({"commands": [...]}), nao a sintaxe abreviada "commands=...": o
      # parser abreviado da AWS CLI rejeita linhas que terminam em '\'.
      SITE_B64=$(base64 < "${path.module}/site/index.html" | tr -d '\n')
      PARAMS=$({ printf 'SITE_B64=%s\n' "$SITE_B64"; cat "${path.module}/script.sh"; } | jq -R . | jq -s '{commands: .}')
      CMD=$(aws ssm send-command \
        --instance-ids "$ID" \
        --document-name "AWS-RunShellScript" \
        --comment "Provisionamento Quantum Commerce (01.1)" \
        --parameters "$PARAMS" \
        --region "$REGION" \
        --query 'Command.CommandId' --output text)

      echo "Comando enviado ($CMD). Aguardando a execucao terminar..."
      aws ssm wait command-executed --command-id "$CMD" --instance-id "$ID" --region "$REGION" || true

      echo "----- log do provisionamento -----"
      aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
        --region "$REGION" --query 'StandardOutputContent' --output text
      echo "----------------------------------"

      STATUS=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --region "$REGION" --query 'Status' --output text)
      RC=$(aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" --region "$REGION" --query 'ResponseCode' --output text)
      echo "Status=$STATUS ResponseCode=$RC"

      if [ "$STATUS" != "Success" ]; then
        echo "ERRO: o provisionamento via SSM falhou (Status=$STATUS)." >&2
        aws ssm get-command-invocation --command-id "$CMD" --instance-id "$ID" \
          --region "$REGION" --query 'StandardErrorContent' --output text >&2
        exit 1
      fi
    EOT
  }
}
