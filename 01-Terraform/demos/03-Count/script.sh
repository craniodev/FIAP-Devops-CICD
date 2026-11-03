#!/bin/bash
# set -e: o script PARA no primeiro erro. Sem isso, o SSM marcaria o comando como
# 'Success' mesmo que um passo falhasse no meio — dando falsa certeza ao apply.
set -euo pipefail

echo "== provisionando servidor web da Quantum Commerce (frota atrás do ALB) =="

# Amazon Linux 2023 usa dnf e entrega nginx direto nos repositorios padrao. -q: o SSM
# so devolve os primeiros 24.000 caracteres do stdout; sem ele o log do dnf empurraria
# as linhas de validacao abaixo para fora do log exibido no apply.
sudo dnf install -y -q nginx

# O local-exec injeta tres linhas antes deste script: SITE_B64 (o site/index.html em
# base64), QC_INDEX (posicao desta maquina na frota) e QC_TOTAL (tamanho da frota).
# Sem qualquer uma delas a pagina mentiria sobre a frota, entao falhamos cedo.
: "${SITE_B64:?SITE_B64 ausente: a pagina deveria chegar no comando SSM}"
: "${QC_INDEX:?QC_INDEX ausente: a posicao da instancia deveria chegar no comando SSM}"
: "${QC_TOTAL:?QC_TOTAL ausente: o tamanho da frota deveria chegar no comando SSM}"
PAGINA=/usr/share/nginx/html/index.html
echo "$SITE_B64" | base64 -d | sudo tee "$PAGINA" > /dev/null

# Troca cada marcador (um por linha) pelo texto da pagina publicada. A pagina e
# regravada do base64 a cada execucao, entao reprovisionar continua idempotente.
# 'env LC_ALL=C' faz o sed tratar acentos e o travessao como bytes, sem depender do
# locale da instancia. O hostname aparece no status e no rodape: e ele que prova, a
# cada recarga, que o ALB entregou a requisicao para uma maquina diferente.
HOST=$(uname -n)
sudo env LC_ALL=C sed -i \
  -e 's|<!--QC:TITLE-->.*<!--/QC:TITLE-->|A camada web do assistente está escalando.|' \
  -e "s|<!--QC:STATUS-->.*<!--/QC:STATUS-->|<span class=\"on\">Instância ${QC_INDEX} de ${QC_TOTAL} atrás do ALB — servida por ${HOST}</span>|" \
  -e "s|<!--QC:HOST-->.*<!--/QC:HOST-->|<code>${HOST}</code>|" \
  "$PAGINA"

# Valida a configuracao antes de reiniciar: um nginx.conf quebrado falha aqui, com
# mensagem clara, em vez de derrubar o servico.
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# Prova local de que o nginx serve a pagina nova, com a posicao certa na frota.
# Capturar em variavel (em vez de 'curl | grep -q') evita falso erro de SIGPIPE com
# pipefail.
RESPOSTA=$(curl -fsS http://localhost/)
if ! grep -q "Instância ${QC_INDEX} de ${QC_TOTAL} atrás do ALB" <<< "$RESPOSTA"; then
  echo "ERRO: o nginx respondeu, mas sem a pagina da Quantum Commerce desta instancia." >&2
  exit 1
fi

echo "nginx: $(systemctl is-active nginx)"
echo "pagina: $(grep -o '<title>[^<]*</title>' <<< "$RESPOSTA")"
echo "frota: instancia ${QC_INDEX} de ${QC_TOTAL}"
echo "host: ${HOST}"
echo "== provisionamento concluido =="
