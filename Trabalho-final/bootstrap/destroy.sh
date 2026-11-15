#!/usr/bin/env bash
# make destroy / destroy-ambientes / destroy-runner.
#
#   ambientes: no clone do aluno, terraform destroy nos workspaces dev e prod.
#   runner:    terraform destroy da EC2 do runner (bootstrap/runner), apaga o runner
#              no GitLab e o parâmetro SSM com o token.
#   tudo:      ambientes e depois runner.
#
# Só destrói o que o próprio make criou. A rede fiap-lab (vpc-call / RT-call), o
# projeto GitLab, a chave SSH e o clone ficam intactos.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

destroy_ambientes() {
  local clone env
  need_cmd terraform aws
  load_env
  clone="$(clone_dir_offline)"
  require_clone "$clone"
  aws_check >/dev/null
  log "Destruindo os ambientes dev e prod do seu projeto ($clone)..."
  tf_init_clone "$clone"
  for env in dev prod; do
    if ! tf_workspace_exists "$clone" "$env"; then
      ok "workspace $env não existe; nada a destruir"
      continue
    fi
    log "terraform destroy no workspace $env..."
    terraform -chdir="$clone" workspace select "$env" >/dev/null
    terraform -chdir="$clone" destroy -auto-approve -input=false >&2 || \
      die "o terraform destroy do workspace $env falhou." \
        "Veja o erro acima e rode de novo: make destroy-ambientes" \
        "(se for lock preso de um pipeline cancelado: terraform -chdir=$clone force-unlock <LOCK_ID>)"
    ok "$env destruído"
  done
  terraform -chdir="$clone" workspace select default >/dev/null 2>&1 || true
}

destroy_runner() {
  local bucket desc runner_id instance_id
  need_cmd terraform aws jq curl
  load_env
  aws_check >/dev/null
  bucket="$(find_bucket)"

  log "Destruindo a EC2 do runner $RUNNER_NAME (bootstrap/runner, state s3://$bucket/trabalho-final/runner.tfstate)..."
  runner_tf_init "$bucket"
  instance_id="$(runner_instance_id)"
  # Pelo state, e não só pelo instance_id: um apply que falhou no meio pode ter
  # deixado só o Security Group.
  if [ "$(runner_state_count)" -gt 0 ]; then
    terraform -chdir="$RUNNER_TF_DIR" destroy -auto-approve -input=false >&2 || \
      die "o terraform destroy da EC2 do runner falhou." "Veja o erro acima e rode de novo: make destroy-runner"
    ok "EC2 ${instance_id:-(não havia)} e Security Group $RUNNER_NAME destruídos"
  else
    ok "state do runner vazio; nada a destruir na AWS"
  fi

  # O runner no GitLab: id guardado na descrição do parâmetro SSM; sem ele, busca
  # pela descrição no projeto (precisa do token do GitLab).
  desc="$(ssm_token_description)"
  runner_id="$(printf '%s' "$desc" | sed -n 's/.*runner_id=\([0-9][0-9]*\).*/\1/p')"
  if [ -n "$GITLAB_TOKEN" ]; then
    if [ -z "$runner_id" ] && [ -n "$REPO" ]; then
      gitlab_whoami
      resolve_project_path
      if gitlab_find_project; then
        runner_id="$(gitlab_find_runner)"
      fi
    fi
    if [ -n "$runner_id" ]; then
      gitlab_api DELETE "/runners/$runner_id"
      case "$GL_STATUS" in
        204) ok "runner $runner_id apagado no GitLab" ;;
        404) ok "runner $runner_id já não existia no GitLab" ;;
        *) warn "não consegui apagar o runner $runner_id no GitLab (HTTP $GL_STATUS): $(gl_err). Apague na UI: Settings > CI/CD > Runners." ;;
      esac
    else
      ok "nenhum runner $RUNNER_NAME no GitLab"
    fi
  else
    warn "sem token do GitLab salvo: o runner ${runner_id:-$RUNNER_NAME} não foi apagado no GitLab. Apague na UI: Settings > CI/CD > Runners."
  fi

  if [ -n "$desc" ] || aws ssm get-parameter --name "$RUNNER_TOKEN_SSM" --region "$AWS_REGION" >/dev/null 2>&1; then
    aws ssm delete-parameter --name "$RUNNER_TOKEN_SSM" --region "$AWS_REGION" >/dev/null || \
      die "não consegui apagar o parâmetro SSM $RUNNER_TOKEN_SSM." "Apague com: aws ssm delete-parameter --name $RUNNER_TOKEN_SSM --region $AWS_REGION"
    ok "parâmetro SSM $RUNNER_TOKEN_SSM apagado"
  else
    ok "parâmetro SSM $RUNNER_TOKEN_SSM não existia"
  fi
}

case "${1:-}" in
  ambientes) destroy_ambientes ;;
  runner)    destroy_runner ;;
  tudo)      destroy_ambientes; destroy_runner ;;
  *) die "uso: destroy.sh ambientes|runner|tudo" ;;
esac
log "Pronto. A rede $NET_NAME, o projeto GitLab e o seu clone foram mantidos."
