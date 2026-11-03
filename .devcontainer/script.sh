#!/bin/bash
set -euo pipefail
set -x

# Resolve a pasta do proprio script: funciona qualquer que seja o nome do fork/clone.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

sudo apt-get update -y
# jq e usado pelos labs que provisionam via SSM (envia o script e le o log/status
# do comando). python3-venv garante o modulo venv no Python do sistema.
sudo apt-get install -y jq python3-venv

mkdir -p ~/.aws/
cp "${SCRIPT_DIR}/config" ~/.aws/config

# Mesmo tooling que o lab 02-Ansible instala a mao (venv ~/venv + Ansible + boto3
# + collections). Ansible e boto3 precisam estar no MESMO Python para o connection
# plugin aws_ssm funcionar; por isso tudo vai para o venv, nunca para o sistema.
# Os passos manuais do lab continuam funcionando e viram no-op.
[ -d ~/venv ] || python3 -m venv ~/venv
~/venv/bin/pip install --quiet --upgrade pip
~/venv/bin/pip install --quiet ansible boto3 botocore
~/venv/bin/ansible-galaxy collection install community.aws amazon.aws

# Deixa ansible/ansible-playbook no PATH de qualquer terminal (login e interativo)
# sem exigir o "source ~/venv/bin/activate" em toda aula.
for rc in ~/.bashrc ~/.profile; do
  grep -q 'venv/bin' "$rc" 2>/dev/null || echo 'export PATH="$HOME/venv/bin:$PATH"' >> "$rc"
done

# Confirma as ferramentas de que os labs dependem.
aws --version
jq --version
terraform -version
~/venv/bin/ansible --version
