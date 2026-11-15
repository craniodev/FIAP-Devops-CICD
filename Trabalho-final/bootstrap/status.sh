#!/usr/bin/env bash
# make status: o que está de pé do Trabalho Final. Runner online no GitLab?, URL
# do projeto, status do último pipeline e DNS do ALB de dev e prod (se houver state).
# Só leitura: não cria nem altera nada.
set -euo pipefail
# shellcheck source=lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

need_cmd aws terraform jq curl
load_env
require_repo
require_token
gitlab_whoami
resolve_project_path

# Alinha pelo número de caracteres (o printf %-Ns conta bytes e desalinha o "Ú").
linha() { printf '  %s%*s %s\n' "$1" $((16 - ${#1})) '' "$2"; }

printf 'Trabalho Final - status\n'
if ! gitlab_find_project; then
  linha "Projeto" "$PROJECT_WEB_URL (não existe; rode make bootstrap)"
  exit 0
fi
linha "Projeto" "$PROJECT_WEB_URL (id $PROJECT_ID)"

gitlab_api GET "/projects/$PROJECT_ID/runners?type=project_type&per_page=100"
runner="$(printf '%s' "$GL_BODY" | jq -r --arg d "$RUNNER_NAME" \
  '[.[] | select(.description == $d)] | first | if . == null then "" else "\(.id) \(.status)" end' 2>/dev/null || true)"
if [ -n "$runner" ]; then
  linha "Runner" "$RUNNER_NAME (id ${runner%% *}): ${runner#* }"
else
  linha "Runner" "$RUNNER_NAME não existe no projeto (rode make bootstrap)"
fi

gitlab_api GET "/projects/$PROJECT_ID/pipelines?per_page=1"
pipe="$(printf '%s' "$GL_BODY" | jq -r 'first | if . == null then "" else "#\(.id) \(.status) (\(.ref), \(.created_at[0:16] | sub("T"; " "))) \(.web_url)" end' 2>/dev/null || true)"
linha "Último pipeline" "${pipe:-nenhum pipeline ainda (faça o primeiro push com o .gitlab-ci.yml)}"

# ALB vem do state remoto do aluno; consultar não exige credencial além da AWS.
if aws sts get-caller-identity >/dev/null 2>&1; then
  bucket="$(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null | tr '\t' '\n' | grep '^base-config' | head -1 || true)"
  for env in dev prod; do
    dns=""
    if [ -n "$bucket" ]; then
      dns="$(aws s3 cp "s3://$bucket/env:/$env/$STATE_KEY_ALUNO" - 2>/dev/null | \
        jq -r '.outputs.alb_dns.value // empty' 2>/dev/null || true)"
    fi
    if [ -n "$dns" ]; then
      linha "ALB $env" "http://$dns"
    else
      linha "ALB $env" "sem state ou sem output alb_dns (o deploy-$env ainda não rodou)"
    fi
  done
else
  linha "ALB dev/prod" "credenciais AWS inválidas ou expiradas (aws sts get-caller-identity)"
fi
