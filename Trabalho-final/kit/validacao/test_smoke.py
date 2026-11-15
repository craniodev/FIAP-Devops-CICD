"""Smoke test pos-deploy: a frota do ambiente esta no ar atras do ALB?

Roda no job smoke-<env> do pipeline, depois do deploy-<env>:

    ALB_DNS=$(terraform output -raw alb_dns)
    pytest validacao/test_smoke.py --ambiente dev --alb-dns "$ALB_DNS"

Usa so a biblioteca padrao (HTTP) e o boto3 (AWS), ambos no /opt/venv do runner.
Cada funcao e uma linha na aba Tests do GitLab e a mensagem diz o que corrigir.
"""

import re
import sys
import time
import urllib.error
import urllib.request

import boto3
import pytest
from botocore.exceptions import BotoCoreError, ClientError

from conftest import falhar

REGIAO = "us-east-1"

# Um ALB recem-criado leva alguns minutos ate o DNS propagar e os alvos passarem no
# health check. Ate la a resposta e erro de DNS, 502 ou 503. Todas as esperas do
# arquivo dividem um prazo unico de 5 min, contado a partir do primeiro teste.
ESPERA_MAXIMA_S = 300
INTERVALO_S = 10
TIMEOUT_HTTP_S = 5

REQUISICOES_PARA_HOSTS = 30
TITULO_DA_PAGINA = "Quantum Commerce · AI Customer Assistant"

# Texto que o script.sh injeta no marcador QC:STATUS de cada EC2:
#   Instância 2 de 3 atrás do ALB — servida por ip-10-0-1-23.ec2.internal
STATUS = re.compile(r"Instância (\d+) de (\d+) atrás do ALB — servida por ([^<\s]+)")


def log(*partes):
    # Progresso vai para stderr: o pytest mostra no log do job sem misturar com o
    # resultado dos testes.
    print(*partes, file=sys.stderr, flush=True)


def _get(url):
    requisicao = urllib.request.Request(url, headers={"Cache-Control": "no-cache"})
    with urllib.request.urlopen(requisicao, timeout=TIMEOUT_HTTP_S) as resposta:
        return resposta.status, resposta.read().decode("utf-8", errors="replace")


# ---------- fixtures ----------


@pytest.fixture(scope="session")
def prazo():
    return time.monotonic() + ESPERA_MAXIMA_S


@pytest.fixture(scope="session")
def url(alb_dns):
    return f"http://{alb_dns}/"


@pytest.fixture(scope="session")
def pagina(url, prazo):
    """Primeira resposta 200 do ALB. O deploy so termina depois que cada EC2 foi
    provisionada, entao a partir do primeiro 200 o conteudo ja e o definitivo."""
    inicio = time.monotonic()
    ultimo_erro = "nenhuma resposta"
    while True:
        try:
            status, corpo = _get(url)
            if status == 200:
                segundos = time.monotonic() - inicio
                log(f"ALB respondeu 200 em {segundos:.0f}s")
                return {"status": 200, "corpo": corpo, "segundos": segundos}
            ultimo_erro = f"HTTP {status}"
        except urllib.error.HTTPError as erro:
            ultimo_erro = f"HTTP {erro.code}"
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError) as erro:
            ultimo_erro = f"sem conexão ({getattr(erro, 'reason', erro)})"
        segundos = time.monotonic() - inicio
        if time.monotonic() >= prazo:
            log(f"fim da espera após {segundos:.0f}s; última resposta: {ultimo_erro}")
            return {"status": None, "erro": ultimo_erro, "segundos": segundos}
        log(f"aguardando o ALB ({segundos:.0f}s): {ultimo_erro}")
        time.sleep(INTERVALO_S)


@pytest.fixture(scope="session")
def no_ar(pagina, url):
    if pagina["status"] != 200:
        falhar(
            f"O ALB {url} não respondeu HTTP 200 em {pagina['segundos']:.0f}s (última tentativa: "
            f"{pagina['erro']}). Confira se o deploy terminou sem erro, se o listener na porta 80 "
            "encaminha para o Target Group e se o Security Group libera a porta 80. "
            "Revise os Requisitos 1 e 5."
        )
    return pagina["corpo"]


def _rodada_de_hosts(url):
    hosts = set()
    for _ in range(REQUISICOES_PARA_HOSTS):
        try:
            _, corpo = _get(url)
        except (urllib.error.URLError, TimeoutError, ConnectionError, OSError):
            continue
        achado = STATUS.search(corpo)
        if achado:
            hosts.add(achado.group(3))
    return hosts


@pytest.fixture(scope="session")
def hosts_vistos(no_ar, url, nos_esperados, prazo):
    """Hosts distintos numa rodada de 30 requisicoes. Um alvo que acabou de passar
    no health check demora a entrar no rodizio do ALB: se a rodada nao enxergar a
    frota inteira, repete ate o prazo e fica com a melhor rodada."""
    melhor = set()
    while True:
        hosts = _rodada_de_hosts(url)
        log(f"hosts distintos em {REQUISICOES_PARA_HOSTS} requisições: {sorted(hosts)}")
        if len(hosts) > len(melhor):
            melhor = hosts
        if len(melhor) >= nos_esperados or time.monotonic() >= prazo:
            return melhor
        time.sleep(INTERVALO_S)


@pytest.fixture(scope="session")
def ec2():
    return boto3.client("ec2", region_name=REGIAO)


@pytest.fixture(scope="session")
def elbv2():
    return boto3.client("elbv2", region_name=REGIAO)


def _chamar_aws(funcao, **parametros):
    try:
        return funcao(**parametros)
    except (BotoCoreError, ClientError) as erro:
        falhar(
            f"A chamada à AWS falhou ({erro}). Se for ExpiredToken, as credenciais do Learner "
            "Lab expiraram: atualize-as no runner e rode o job de novo."
        )


# ---------- pagina servida pelo ALB ----------


def test_alb_responde_200(no_ar, pagina):
    assert no_ar
    log(f"tempo até o ALB responder 200: {pagina['segundos']:.0f}s")


def test_pagina_do_assistente(no_ar, url):
    if TITULO_DA_PAGINA not in no_ar:
        achado = re.search(r"<title>([^<]*)</title>", no_ar)
        titulo = achado.group(1) if achado else "sem <title>"
        falhar(
            f'O ALB {url} respondeu, mas a página tem o título "{titulo}" em vez de '
            f'"{TITULO_DA_PAGINA}". O módulo precisa levar a pasta site/ com o index.html '
            "da demo Count, que o terraform_data.provisiona envia para cada EC2. "
            "Revise o Requisito 1."
        )


def test_pagina_mostra_tamanho_da_frota(no_ar, ambiente, nos_esperados):
    achado = STATUS.search(no_ar)
    if not achado:
        falhar(
            "A página não mostra \"Instância i de N atrás do ALB\": o script.sh não personalizou "
            "o index.html na EC2 (provisionamento não rodou ou o script.sh foi alterado). "
            "Leve o script.sh e o site/ da demo Count sem mudanças. Revise o Requisito 1."
        )
    total = int(achado.group(2))
    if total != nos_esperados:
        falhar(
            f'A página diz "Instância {achado.group(1)} de {total}", mas {ambiente} deveria ter '
            f'{nos_esperados} nó(s). Confira node_count = terraform.workspace == "prod" ? 3 : 1 '
            "no raiz (Requisito 2) e o workspace selecionado no deploy (Requisito 6)."
        )


def test_alb_distribui_entre_os_hosts(hosts_vistos, ambiente, nos_esperados):
    if len(hosts_vistos) != nos_esperados:
        falhar(
            f"Em {REQUISICOES_PARA_HOSTS} requisições ao ALB apareceram {len(hosts_vistos)} "
            f"host(s) distinto(s) {sorted(hosts_vistos)}, mas {ambiente} deveria ter "
            f"{nos_esperados}. Confira se cada EC2 está registrada no Target Group "
            "(count de aws_lb_target_group_attachment.web = length(aws_instance.web)). "
            "Revise os Requisitos 1 e 6."
        )


# ---------- recursos na AWS ----------


def test_ec2_running(ec2, ambiente, nos_esperados):
    nomes = [f"nginx-{ambiente}-{i:03d}" for i in range(1, nos_esperados + 1)]
    resposta = _chamar_aws(
        ec2.describe_instances,
        Filters=[
            {"Name": "tag:Name", "Values": [f"nginx-{ambiente}-*"]},
            {"Name": "instance-state-name", "Values": ["running"]},
        ],
    )
    achados = sorted(
        tag["Value"]
        for reserva in resposta["Reservations"]
        for instancia in reserva["Instances"]
        for tag in instancia.get("Tags", [])
        if tag["Key"] == "Name"
    )
    if achados != nomes:
        falhar(
            f"EC2 running com tag Name nginx-{ambiente}-*: {achados or 'nenhuma'}. Esperado: "
            f"{nomes}. Confira format(\"nginx-%s-%03d\", terraform.workspace, count.index + 1) "
            f"(Requisito 4) e se o deploy-{ambiente} rodou no workspace {ambiente} (Requisito 6)."
        )


def _target_group(elbv2, ambiente):
    nome = f"qc-tg-{ambiente}"
    try:
        return elbv2.describe_target_groups(Names=[nome])["TargetGroups"][0]
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "TargetGroupNotFound":
            falhar(
                f'O Target Group "{nome}" não existe na AWS. Use name = "qc-tg-${{terraform.workspace}}" '
                f"em aws_lb_target_group.web e confira se o deploy-{ambiente} terminou. "
                "Revise o Requisito 5."
            )
        raise


def test_target_group_com_alvos_healthy(elbv2, ambiente, nos_esperados, prazo):
    grupo = _target_group(elbv2, ambiente)
    # O deploy termina antes de os alvos passarem no health check (initial ->
    # healthy leva alguns ciclos de 6 s): espera dentro do mesmo prazo do arquivo.
    while True:
        saude = _chamar_aws(elbv2.describe_target_health, TargetGroupArn=grupo["TargetGroupArn"])
        estados = [alvo["TargetHealth"]["State"] for alvo in saude["TargetHealthDescriptions"]]
        saudaveis = estados.count("healthy")
        if (saudaveis == nos_esperados and len(estados) == nos_esperados) or time.monotonic() >= prazo:
            break
        log(f"aguardando alvos healthy em qc-tg-{ambiente}: {estados}")
        time.sleep(INTERVALO_S)
    if saudaveis != nos_esperados or len(estados) != nos_esperados:
        falhar(
            f"O Target Group qc-tg-{ambiente} tem {saudaveis} alvo(s) healthy de {len(estados)} "
            f"registrado(s) (estados: {estados or 'nenhum alvo'}), mas {ambiente} deveria ter "
            f"{nos_esperados} healthy. Confira o count de aws_lb_target_group_attachment.web "
            "e se o nginx subiu (log do terraform_data.provisiona no deploy). "
            "Revise os Requisitos 1 e 6."
        )


def test_dns_do_alb_confere(elbv2, ambiente, alb_dns):
    nome = f"qc-alb-{ambiente}"
    try:
        balanceador = elbv2.describe_load_balancers(Names=[nome])["LoadBalancers"][0]
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "LoadBalancerNotFound":
            falhar(
                f'O ALB "{nome}" não existe na AWS. Use name = "qc-alb-${{terraform.workspace}}" '
                f"em aws_lb.web e confira se o deploy-{ambiente} terminou. Revise o Requisito 5."
            )
        raise
    if balanceador["DNSName"].lower() != alb_dns.lower():
        falhar(
            f"O --alb-dns recebido ({alb_dns}) não é o DNS do ALB {nome} ({balanceador['DNSName']}). "
            f"O job smoke-{ambiente} precisa selecionar o workspace {ambiente} antes de "
            "terraform output -raw alb_dns, e o output alb_dns do raiz deve vir de "
            "module.<nome>.alb_dns. Revise os Requisitos 2 e 7."
        )
