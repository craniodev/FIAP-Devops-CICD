#!/usr/bin/env bash
# make validar: roda no clone do aluno, sem apply, as mesmas verificações do
# pipeline (fmt, validate, terraform test no workspace dev, plan dev e prod +
# test_contrato.py). Serve para achar o erro antes do push.
#
# make smoke: roda test_smoke.py contra dev e prod que já estão no ar (depois do
# deploy do pipeline). AMBIENTE=dev ou AMBIENTE=prod limita a um ambiente.
#
# Ambos usam o venv ~/.venv-trabalho-final (pytest + boto3 + pyyaml), criado sob demanda:
# o /opt/venv do pipeline só existe no runner.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

RESULTADOS=()
FALHAS=0

registrar() {
  local etapa="$1" rc="$2"
  if [ "$rc" = 0 ]; then
    RESULTADOS+=("ok     $etapa")
  else
    RESULTADOS+=("FALHOU $etapa")
    FALHAS=$((FALHAS + 1))
  fi
}

# O plan/test trocam o workspace selecionado; ao sair, volta o que o aluno usava.
WS_ORIGINAL=""
restaurar_workspace() {
  if [ -n "$WS_ORIGINAL" ] && [ -n "${CLONE:-}" ]; then
    terraform -chdir="$CLONE" workspace select "$WS_ORIGINAL" >/dev/null 2>&1 || true
  fi
}

selecionar_ws() {
  terraform -chdir="$CLONE" workspace select -or-create=true "$1" >/dev/null
}

resumo_e_saida() {
  local titulo="$1" proximo="$2" linha
  printf '\n%s em %s\n' "$titulo" "$CLONE"
  for linha in "${RESULTADOS[@]}"; do printf '  %s\n' "$linha"; done
  if [ "$FALHAS" -gt 0 ]; then
    printf '\n%s etapa(s) falharam. A mensagem de cada teste acima diz o que corrigir e qual Requisito do README revisar.\n' "$FALHAS"
    exit 1
  fi
  printf '\nTudo verde. %s\n' "$proximo"
}

preparar() {
  need_cmd terraform aws python3
  load_env
  CLONE="$(clone_dir_offline)"
  require_clone "$CLONE"
  require_kit_no_clone "$CLONE"
  aws_check >/dev/null
  ensure_venv_testes
  WS_ORIGINAL="$(terraform -chdir="$CLONE" workspace show 2>/dev/null || true)"
  trap restaurar_workspace EXIT
}

pytest_kit() {
  ( cd "$CLONE" && "$VENV_TESTES/bin/pytest" "$@" >&2 )
}

cmd_validar() {
  local rc env
  preparar
  log "Validando o seu Terraform em $CLONE (sem apply)..."

  log "fmt: terraform fmt -check -recursive"
  rc=0
  terraform -chdir="$CLONE" fmt -check -recursive >&2 || rc=$?
  [ "$rc" = 0 ] || log "   os arquivos acima estão fora do padrão; corrija com: terraform -chdir=$CLONE fmt -recursive"
  registrar "terraform fmt -check -recursive" "$rc"

  tf_init_clone "$CLONE"
  registrar "terraform init" 0

  log "validate: terraform validate"
  rc=0
  terraform -chdir="$CLONE" validate >&2 || rc=$?
  registrar "terraform validate" "$rc"
  [ "$rc" = 0 ] || resumo_e_saida "Validação interrompida (sem validate não há plan)" ""

  log "test: terraform test no workspace dev (tests/modulo.tftest.hcl)"
  rc=0
  selecionar_ws dev
  terraform -chdir="$CLONE" test >&2 || rc=$?
  registrar "terraform test (workspace dev)" "$rc"

  for env in dev prod; do
    log "plan $env: terraform plan -out=plan-$env.tfplan (workspace $env)"
    selecionar_ws "$env"
    rc=0
    # -lock=false: plan não grava state; sem isto, um deploy do pipeline em
    # andamento travaria o make validar com erro de lock.
    terraform -chdir="$CLONE" plan -input=false -lock=false -out="plan-$env.tfplan" >&2 || rc=$?
    registrar "terraform plan ($env)" "$rc"
    if [ "$rc" != 0 ]; then
      registrar "test_contrato.py --ambiente $env (pulado: sem plan)" 1
      continue
    fi
    terraform -chdir="$CLONE" show -json "plan-$env.tfplan" > "$CLONE/plan-$env.json"
    log "contrato $env: pytest validacao/test_contrato.py --ambiente $env --plan plan-$env.json"
    rc=0
    pytest_kit validacao/test_contrato.py --ambiente "$env" --plan "plan-$env.json" || rc=$?
    registrar "test_contrato.py --ambiente $env" "$rc"
  done

  # Sem pipeline, o push não roda nada no GitLab: o próximo passo é escrevê-lo.
  if [ -f "$CLONE/.gitlab-ci.yml" ]; then
    resumo_e_saida "Resultado do make validar" "Pode fazer o push: git -C $CLONE push"
  else
    resumo_e_saida "Resultado do make validar" \
      "O Terraform está pronto. Próximo passo: escrever o .gitlab-ci.yml em $CLONE (Requisito 7) e depois fazer o push."
  fi
}

cmd_smoke() {
  local env rc dns ambientes
  ambientes="${AMBIENTE:-dev prod}"
  for env in $ambientes; do
    case "$env" in dev|prod) ;; *) die "AMBIENTE='$env' inválido." "Use: make smoke AMBIENTE=dev  ou  make smoke AMBIENTE=prod" ;; esac
  done
  preparar
  need_cmd jq
  tf_init_clone "$CLONE"
  for env in $ambientes; do
    if ! tf_workspace_exists "$CLONE" "$env"; then
      log "smoke $env: o workspace $env não existe; o pipeline ainda não fez o deploy-$env."
      registrar "test_smoke.py --ambiente $env (sem workspace $env)" 1
      continue
    fi
    terraform -chdir="$CLONE" workspace select "$env" >/dev/null
    # Por JSON: sem o output, o 'output -raw' imprime o aviso no stdout e o smoke
    # receberia lixo como DNS.
    dns="$(terraform -chdir="$CLONE" output -json 2>/dev/null | jq -r '.alb_dns.value // empty' 2>/dev/null || true)"
    if [ -z "$dns" ]; then
      log "smoke $env: sem output alb_dns no state de $env; o deploy-$env já rodou? (Requisito 2: output alb_dns no raiz)"
      registrar "test_smoke.py --ambiente $env (sem alb_dns)" 1
      continue
    fi
    log "smoke $env: pytest validacao/test_smoke.py --ambiente $env --alb-dns $dns"
    rc=0
    pytest_kit validacao/test_smoke.py --ambiente "$env" --alb-dns "$dns" || rc=$?
    registrar "test_smoke.py --ambiente $env" "$rc"
  done
  resumo_e_saida "Resultado do make smoke" "Tire os prints da entrega e, no fim, rode: make destroy"
}

case "${1:-validar}" in
  validar) cmd_validar ;;
  smoke)   cmd_smoke ;;
  *) die "uso: validar.sh [validar|smoke]" ;;
esac
