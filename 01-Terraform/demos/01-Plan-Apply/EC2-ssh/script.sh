#!/bin/bash
# set -e: o script PARA no primeiro erro. Sem isso, o SSM marcaria o comando como
# 'Success' mesmo que um passo falhasse no meio — dando falsa certeza ao apply.
set -euo pipefail

echo "== provisionando servidor web da Quantum Commerce =="

# Amazon Linux 2023 usa dnf e entrega nginx direto nos repositorios padrao
# (o antigo amazon-linux-extras nao existe mais nessa versao). -q: o SSM so devolve
# os primeiros 24.000 caracteres do stdout; sem ele o log do dnf empurraria as linhas
# de validacao abaixo para fora do log exibido no apply.
sudo dnf install -y -q nginx

# O local-exec injeta SITE_B64 (o site/index.html em base64) como primeira linha do
# comando SSM; sem ela nao ha pagina para publicar, entao falhamos cedo.
: "${SITE_B64:?SITE_B64 ausente: a pagina deveria chegar no comando SSM}"
PAGINA=/usr/share/nginx/html/index.html
echo "$SITE_B64" | base64 -d | sudo tee "$PAGINA" > /dev/null

# Troca cada marcador (um por linha) pelo texto da pagina publicada; o texto de
# pre-visualizacao local some. A pagina e regravada do base64 a cada execucao, entao
# reprovisionar continua idempotente. 'env LC_ALL=C' faz o sed tratar acentos e o
# travessao como bytes, sem depender do locale da instancia.
HOST=$(uname -n)
sudo env LC_ALL=C sed -i \
  -e 's|<!--QC:TITLE-->.*<!--/QC:TITLE-->|A primeira infraestrutura do assistente está online.|' \
  -e 's|<!--QC:STATUS-->.*<!--/QC:STATUS-->|<span class="on">EC2 / Nginx online — página servida pela instância</span>|' \
  -e "s|<!--QC:HOST-->.*<!--/QC:HOST-->|<code>${HOST}</code>|" \
  "$PAGINA"

# Valida a configuracao antes de reiniciar: um nginx.conf quebrado falha aqui, com
# mensagem clara, em vez de derrubar o servico.
sudo nginx -t
sudo systemctl enable nginx
sudo systemctl restart nginx

# Prova local de que o nginx serve a pagina nova. Capturar em variavel (em vez de
# 'curl | grep -q') evita falso erro de SIGPIPE com pipefail.
RESPOSTA=$(curl -fsS http://localhost/)
if ! grep -q 'Quantum Commerce' <<< "$RESPOSTA"; then
  echo "ERRO: o nginx respondeu, mas sem a pagina da Quantum Commerce." >&2
  exit 1
fi

echo "nginx: $(systemctl is-active nginx)"
echo "pagina: $(grep -o '<title>[^<]*</title>' <<< "$RESPOSTA")"
echo "host: ${HOST}"
echo "== provisionamento concluido =="
