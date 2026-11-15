"""Opcoes de linha de comando e fixtures compartilhadas pelos testes do kit.

    pytest validacao/test_contrato.py --ambiente dev --plan plan-dev.json
    pytest validacao/test_smoke.py --ambiente dev --alb-dns <DNS do ALB>
"""

import json
from pathlib import Path

import pytest

# Tamanho da frota por workspace (Requisito 6).
FROTA = {"dev": 1, "prod": 3}

# validacao/ fica na raiz do repositorio do aluno, ao lado do Terraform raiz.
RAIZ_TERRAFORM = Path(__file__).resolve().parent.parent


def pytest_addoption(parser):
    grupo = parser.getgroup("trabalho-final")
    grupo.addoption(
        "--ambiente",
        choices=sorted(FROTA),
        help="workspace testado: dev (1 nó) ou prod (3 nós)",
    )
    grupo.addoption(
        "--plan",
        help="plan em JSON, gerado com: terraform show -json plan-<env>.tfplan > plan-<env>.json",
    )
    grupo.addoption(
        "--alb-dns",
        help="DNS do ALB do ambiente, vindo de: terraform output -raw alb_dns",
    )


def falhar(mensagem):
    # Sem traceback: a aba Tests do GitLab mostra so a mensagem para o aluno.
    pytest.fail(mensagem, pytrace=False)


@pytest.fixture(scope="session")
def ambiente(request):
    valor = request.config.getoption("--ambiente")
    if not valor:
        falhar(
            "Faltou a opção --ambiente (dev ou prod) na chamada do pytest. "
            "Copie o job do README sem alterar a linha do pytest. Revise o Requisito 7."
        )
    return valor


@pytest.fixture(scope="session")
def nos_esperados(ambiente):
    return FROTA[ambiente]


@pytest.fixture(scope="session")
def plano(request):
    caminho = request.config.getoption("--plan")
    if not caminho:
        falhar(
            "Faltou a opção --plan com o plan em JSON. O job contrato-<env> do README gera "
            "o arquivo com terraform show -json plan-<env>.tfplan > plan-<env>.json. "
            "Revise o Requisito 7."
        )
    arquivo = Path(caminho)
    if not arquivo.is_file():
        falhar(
            f"O arquivo do plan {caminho} não existe. O job contrato-<env> precisa de "
            "needs: plan-<env>, e o job plan-<env> precisa publicar plan-<env>.tfplan em "
            "artifacts. Revise o Requisito 7."
        )
    try:
        return json.loads(arquivo.read_text(encoding="utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        falhar(
            f"O arquivo {caminho} não é um plan em JSON (parece o .tfplan binário). "
            "Converta com terraform show -json plan-<env>.tfplan > plan-<env>.json. "
            "Revise o Requisito 7."
        )


@pytest.fixture(scope="session")
def backend():
    # O terraform init grava aqui a configuracao do backend ja resolvida, inclusive
    # o que veio por -backend-config. E a fonte mais fiel do backend em uso.
    arquivo = RAIZ_TERRAFORM / ".terraform" / "terraform.tfstate"
    if not arquivo.is_file():
        falhar(
            f"Não encontrei {arquivo.relative_to(RAIZ_TERRAFORM)}: ou o terraform init não "
            "rodou antes do pytest (o job contrato-<env> do README roda o init; Requisito 7), "
            'ou o Terraform raiz não tem bloco backend "s3" no backend.tf e o state ficou '
            "local (Requisito 3)."
        )
    return json.loads(arquivo.read_text(encoding="utf-8")).get("backend") or {}


@pytest.fixture(scope="session")
def alb_dns(request):
    valor = (request.config.getoption("--alb-dns") or "").strip()
    # Aceita o DNS colado com http:// ou barra final, como o navegador mostra.
    valor = valor.removeprefix("http://").removeprefix("https://").rstrip("/")
    if not valor:
        falhar(
            "A opção --alb-dns chegou vazia. O job smoke-<env> pega o DNS com "
            "terraform output -raw alb_dns no workspace do ambiente: confira se o raiz "
            "declara o output alb_dns (Requisito 2) e se o job seleciona o workspace "
            "antes (Requisito 7)."
        )
    return valor
