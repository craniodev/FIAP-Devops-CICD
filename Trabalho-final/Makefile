# Trabalho Final - DevOps & CI/CD (Quantum Commerce)
# Wrapper fino: a lógica vive em bootstrap/*.sh. Rode a partir desta pasta:
#   cd /workspaces/FIAP-Devops-CICD/Trabalho-final && make help

SHELL := /bin/bash
.DEFAULT_GOAL := help
.PHONY: help bootstrap status validar smoke kit destroy destroy-ambientes destroy-runner

# REPO, GITLAB_TOKEN, GITLAB_URL, CLONE_DIR e AMBIENTE chegam aos scripts pelo
# ambiente, nunca pela linha de comando do bash (que apareceria no 'ps').
export REPO GITLAB_TOKEN GITLAB_URL CLONE_DIR AMBIENTE

help: ## Lista os comandos disponíveis
	@printf 'Trabalho Final - comandos (rode nesta pasta, no Codespaces)\n\n'
	@awk 'BEGIN {FS = ":.*## "} /^[a-z-]+:.*## / {printf "  make %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@printf '\nPrimeira vez:\n  make bootstrap REPO=git@gitlab.com:<seu-usuario>/trabalho-final.git GITLAB_TOKEN=glpat-...\n'
	@printf '  (REPO aceita também https://gitlab.com/<seu-usuario>/trabalho-final ou só trabalho-final;\n'
	@printf '   sem GITLAB_TOKEN, o bootstrap pergunta o token sem mostrar na tela.)\n'
	@printf 'Depois, REPO e GITLAB_TOKEN ficam salvos em ~/.trabalho-final.env.\n'

bootstrap: ## Cria ou reaproveita projeto GitLab, runner na AWS, chave SSH e clone com o kit (idempotente)
	@bash bootstrap/bootstrap.sh

status: ## Mostra runner online?, URL do projeto, último pipeline e DNS do ALB de dev e prod
	@bash bootstrap/status.sh

validar: ## No clone: fmt, validate, terraform test (dev), plan dev e prod + test_contrato.py, sem apply
	@bash bootstrap/validar.sh validar

smoke: ## Roda test_smoke.py contra dev e prod já no ar (AMBIENTE=dev ou prod para só um)
	@bash bootstrap/validar.sh smoke

kit: ## (Re)copia o kit de testes para o clone, sem tocar nos seus arquivos
	@bash bootstrap/bootstrap.sh kit

destroy: ## destroy-ambientes + destroy-runner (a rede fiap-lab é mantida)
	@bash bootstrap/destroy.sh tudo

destroy-ambientes: ## No clone: terraform destroy nos workspaces dev e prod
	@bash bootstrap/destroy.sh ambientes

destroy-runner: ## Destrói a EC2 do runner e apaga o runner no GitLab e o token no SSM
	@bash bootstrap/destroy.sh runner
