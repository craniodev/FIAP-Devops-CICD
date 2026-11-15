#!/usr/bin/env python3
"""Gera arquitetura-final.excalidraw (Trabalho Final, DevOps & CI/CD).

Uso:     python3 gerar.py
Render:  bash ~/.claude/skills/excalidraw-aulas/scripts/render.sh \
             arquitetura-final.excalidraw /tmp/arquitetura-final-2x.png
         (render 2x, 3680 px) e reduza com LANCZOS para 2400 px de largura
         em ../img/arquitetura-final.png

Icones OFICIAIS em assets/ (SVG fonte + PNG 160px embutido, porque SVG
embutido nao rasteriza no render headless). Mesmos arquivos de
02-Ansible/01-provisionando-gitlab-runner/diagramas/assets:
  - ec2, elb, s3, parameter-store, vpc-group, aws-cloud: AWS Architecture
    Icons, pacote oficial 04/2026 (https://aws.amazon.com/architecture/icons/)
  - gitlab, github (Codespaces): marcas oficiais

Licoes de UX aplicadas (skill excalidraw-aulas): L1 acentuacao, L3 verbo com
sujeito na origem, L5 rotulo explicito, L6 empresa ficticia, L8 apoio e
preparacao tracejados, L10 so a reprovacao em vermelho, L11 fan-out de um
ponto com rotulo unico, L13 magenta so no titulo, L18 rotulo com fundo branco,
L20 corpo >= 17 px logicos, L21 caixa de rede so com o que mora na rede,
L22 smoke chega nos DOIS ALBs, L27 nenhuma borda de caixa tracejada,
L33 o make bootstrap tem ancora nos componentes que ele cria, L36/L44 folgas
verificadas por script (folgas() abaixo), L48 toda acao na AWS sai do runner,
L49/L55 reprovacao de qualquer stage volta para voce, L50 bootstrap B1..B4 x
stages 1..5, L54 rotulo de seta horizontal sempre acima, L59/L61 coletor dos
jobs sem toco alinhado, L60 margem externa.
"""
import base64
import json
import os
import sys

from PIL import ImageFont

DIR = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(DIR, "assets")

MAGENTA = "#B80D47"     # magenta-deep Quantum Commerce: so no titulo (L13)
TEXTO = "#1e1e1e"
ESCURO = "#343a40"      # texto secundario escuro (L32)
CINZA = "#495057"
AWS = "#232F3E"
GITLAB = "#E24329"
VPC_ROXO = "#8C4FFF"
ALERTA = "#C92A2A"      # so o caminho de reprovacao (L10)
FUNDO = "#f1f3f5"
PAINEL = "#f8f9fa"

PISO = 17               # L20: piso; o corpo usa 18 (~14 px em 1366)

_FONTES = {}


def log(*a):
    print(*a, file=sys.stderr, flush=True)


def larg(t, size):
    """Largura real do glifo (Helvetica = fontFamily 2 do Excalidraw)."""
    if size not in _FONTES:
        _FONTES[size] = ImageFont.truetype(
            "/System/Library/Fonts/Helvetica.ttc", size)
    return max(_FONTES[size].getlength(l) for l in t.split("\n"))


class Diagrama:
    def __init__(self):
        self.elements = []
        self.files = {}
        self._n = 0

    def _id(self, p):
        self._n += 1
        return f"{p}{self._n}"

    def _base(self, tipo, x, y, w, h, **kw):
        el = {
            "id": self._id(tipo[:3]), "type": tipo, "x": x, "y": y,
            "width": w, "height": h, "angle": 0, "strokeColor": TEXTO,
            "backgroundColor": "transparent", "fillStyle": "solid",
            "strokeWidth": 2, "strokeStyle": "solid", "roughness": 1,
            "opacity": 100, "groupIds": [], "frameId": None, "roundness": None,
            "seed": 1000 + self._n * 7, "version": 1,
            "versionNonce": 2000 + self._n * 11, "isDeleted": False,
            "boundElements": [], "updated": 1, "link": None, "locked": False,
        }
        el.update(kw)
        self.elements.append(el)
        return el

    def texto(self, t, x, y, w, size=18, cor=TEXTO, align="center"):
        size = max(size, PISO)
        linhas = t.count("\n") + 1
        h = linhas * size * 1.25
        self._base("text", x, y, w, h, strokeColor=cor, strokeWidth=1,
                   fontSize=size, fontFamily=2, text=t, originalText=t,
                   textAlign=align, verticalAlign="top", containerId=None,
                   lineHeight=1.25, baseline=int(size * 0.8))
        return h

    def rotulo(self, t, cx, y, size=18, cor=ESCURO, bg="#ffffff"):
        """Rotulo de seta centrado em cx, com fundo opaco atras (L18)."""
        w = larg(t, size) + 4
        h = (t.count("\n") + 1) * size * 1.25
        self._base("rectangle", cx - w / 2 - 6, y - 4, w + 12, h + 8,
                   strokeColor="transparent", backgroundColor=bg,
                   strokeWidth=1, roughness=0)
        self.texto(t, cx - w / 2, y, w, size=size, cor=cor)

    def rotulo_esq(self, t, x, y, **kw):
        """Rotulo que comeca em x."""
        self.rotulo(t, x + (larg(t, kw.get("size", 18)) + 4) / 2, y, **kw)

    def rotulo_dir(self, t, x, y, **kw):
        """Rotulo que termina em x."""
        self.rotulo(t, x - (larg(t, kw.get("size", 18)) + 4) / 2, y, **kw)

    def imagem(self, nome, x, y, s):
        fid = self._id("file")
        with open(os.path.join(ASSETS, f"{nome}.png"), "rb") as f:
            b64 = base64.b64encode(f.read()).decode()
        self.files[fid] = {"mimeType": "image/png", "id": fid,
                           "dataURL": f"data:image/png;base64,{b64}",
                           "created": 1}
        self._base("image", x, y, s, s, strokeColor="transparent",
                   roughness=0, status="saved", fileId=fid, scale=[1, 1])

    def ret(self, x, y, w, h, cor=TEXTO, bg="#ffffff", largura=2,
            sem_borda=False):
        self._base("rectangle", x, y, w, h,
                   strokeColor="transparent" if sem_borda else cor,
                   backgroundColor=bg, strokeWidth=largura)

    def caixa(self, x, y, w, h, titulo, cor, bg="transparent", icone=None,
              size=18, largura=2, sub=None):
        """Container com icone opcional e titulo no topo interno."""
        self.ret(x, y, w, h, cor=cor, bg=bg, largura=largura)
        tx = x + 14
        if icone:
            self.imagem(icone, x + 10, y + 8, 34)
            tx = x + 54
        self.texto(titulo, tx, y + 13, w - (tx - x) - 14, size=size,
                   cor=cor, align="left")
        if sub:
            self.texto(sub, tx, y + 13 + size * 1.25 + 4, w - (tx - x) - 14,
                       size=18, cor=TEXTO, align="left")

    def cartao(self, x, y, w, h, titulo, corpo, icone=None, s=44,
               tsize=19, csize=18, cor=TEXTO, bg="#ffffff", abaixo=False):
        """Cartao padrao (L40): icone + titulo + linhas. abaixo=True poe o
        corpo na largura toda, sob o icone."""
        self.ret(x, y, w, h, cor=cor, bg=bg)
        tx = x + 14
        if icone:
            self.imagem(icone, x + 12, y + 12, s)
            tx = x + 24 + s
        th = self.texto(titulo, tx, y + 11, w - (tx - x) - 10, size=tsize,
                        cor=cor, align="left")
        if corpo:
            cx, cy = (x + 14, y + 20 + s) if abaixo else (tx, y + 11 + th + 5)
            self.texto(corpo, cx, cy, w - (cx - x) - 10, size=csize,
                       cor=ESCURO, align="left")

    def no(self, icone, cx, cy, s=64):
        self.imagem(icone, cx - s / 2, cy - s / 2, s)
        return {"l": cx - s / 2, "r": cx + s / 2, "t": cy - s / 2,
                "b": cy + s / 2, "cx": cx, "cy": cy}

    def seta(self, pontos, cor=TEXTO, tracejada=False, largura=2,
             ponta=True, roughness=1):
        x0, y0 = pontos[0]
        rel = [[px - x0, py - y0] for px, py in pontos]
        xs = [p[0] for p in rel]
        ys = [p[1] for p in rel]
        self._base("arrow" if ponta else "line", x0, y0,
                   max(xs) - min(xs), max(ys) - min(ys),
                   strokeColor=cor, strokeWidth=largura,
                   strokeStyle="dashed" if tracejada else "solid",
                   roughness=roughness, points=rel, lastCommittedPoint=None,
                   startBinding=None, endBinding=None, startArrowhead=None,
                   endArrowhead="arrow" if ponta else None)

    def salvar(self, caminho):
        doc = {"type": "excalidraw", "version": 2,
               "source": "quantum-commerce-gerador",
               "elements": self.elements,
               "appState": {"gridSize": None,
                            "viewBackgroundColor": "#ffffff"},
               "files": self.files}
        with open(caminho, "w", encoding="utf-8") as f:
            json.dump(doc, f, ensure_ascii=False, indent=2)
        log(f"gerado: {caminho} ({len(self.elements)} elementos)")


def folgas(d, minimo=15, ponta=30):
    """L36/L44: rotulo a >= 15 px de qualquer borda de caixa e ponta de seta
    longe de borda que nao e o destino. Devolve as violacoes (vazio = ok)."""
    caixas = [e for e in d.elements if e["type"] == "rectangle"
              and e["strokeColor"] != "transparent"]
    rotulos = [e for e in d.elements if e["type"] == "rectangle"
               and e["strokeColor"] == "transparent"
               and e["backgroundColor"] == "#ffffff"]
    ruins = []
    for r in rotulos:
        rl, rr = r["x"], r["x"] + r["width"]
        rt, rb = r["y"], r["y"] + r["height"]
        for c in caixas:
            cl, cr = c["x"], c["x"] + c["width"]
            ct, cb = c["y"], c["y"] + c["height"]
            for nome, borda, vert in (("esq", cl, True), ("dir", cr, True),
                                      ("topo", ct, False), ("base", cb, False)):
                if vert:
                    if not (rt < cb and rb > ct):
                        continue
                    dist = 0 if rl < borda < rr else min(abs(rl - borda),
                                                         abs(rr - borda))
                else:
                    if not (rl < cr and rr > cl):
                        continue
                    dist = 0 if rt < borda < rb else min(abs(rt - borda),
                                                         abs(rb - borda))
                if dist < minimo:
                    ruins.append(f"rotulo@({rl:.0f},{rt:.0f}) a {dist:.0f}px "
                                 f"da borda {nome} de caixa@({cl:.0f},{ct:.0f})")
    for e in d.elements:
        if e["type"] != "arrow":
            continue
        px = e["x"] + e["points"][-1][0]
        py = e["y"] + e["points"][-1][1]
        perto = []
        for c in caixas:
            cl, cr = c["x"], c["x"] + c["width"]
            ct, cb = c["y"], c["y"] + c["height"]
            for dist, dentro in ((abs(px - cl), ct <= py <= cb),
                                 (abs(px - cr), ct <= py <= cb),
                                 (abs(py - ct), cl <= px <= cr),
                                 (abs(py - cb), cl <= px <= cr)):
                if dentro and dist < ponta:
                    perto.append(dist)
        perto.sort()
        extras = perto[1:] if perto and perto[0] <= 12 else perto
        for dist in extras:
            ruins.append(f"ponta em ({px:.0f},{py:.0f}) a {dist:.0f}px "
                         "de outra borda")
    return ruins


def sobreposicoes(d):
    """Texto x texto e texto x icone, com a largura real do glifo."""
    caixas = []
    for e in d.elements:
        if e["type"] == "text":
            w = larg(e["text"], e["fontSize"])
            x = e["x"] + (e["width"] - w) / 2 if e["textAlign"] == "center" \
                else e["x"]
            caixas.append(("txt", e["text"][:30], x, e["y"], w, e["height"]))
        elif e["type"] == "image":
            caixas.append(("img", e["fileId"], e["x"], e["y"], e["width"],
                           e["height"]))
    ruins = []
    for i, a in enumerate(caixas):
        for b in caixas[i + 1:]:
            if a[0] == "img" and b[0] == "img":
                continue
            if (a[2] < b[2] + b[4] and b[2] < a[2] + a[4]
                    and a[3] < b[3] + b[5] and b[3] < a[3] + a[5]):
                ruins.append(f"{a[1]!r} x {b[1]!r}")
    return ruins


def arquitetura_final():
    d = Diagrama()
    # Ordem de desenho: containers, depois setas, depois cartoes. Assim o
    # fundo de um container nunca cobre uma seta, e o cartao de origem cobre
    # o inicio da seta (L44: ponta sempre do mesmo tamanho).
    # Regra unica de rotulo (L54): rotulo de seta horizontal fica ACIMA dela,
    # a >= 12 px; de seta vertical, ao lado.

    # --- titulo -------------------------------------------------------------
    d.texto("Quantum Commerce · Trabalho Final: do git push às frotas dev e "
            "prod na AWS", 30, 20, 1760, size=32, cor=MAGENTA, align="left")
    d.texto("Empresa fictícia. O make bootstrap prepara o terreno uma vez; "
            "depois, cada git push valida, testa e entrega dev e prod, e os "
            "testes dizem o que corrigir.", 30, 66, 1760, size=20,
            cor=ESCURO, align="left")

    # --- geometria ----------------------------------------------------------
    CXL = 150                                      # coluna do "Você"
    GAP = 40                                       # vao entre os blocos
    BX, BY, BW, BH = 290, 105, 1500, 215           # faixa de preparacao
    CW, CG, CY, CH = 320, 50, 152, 150             # cartoes B1..B4
    CX0 = BX + (BW - 4 * CW - 3 * CG) / 2          # fileira centrada
    PX, PY, PW = 290, BY + BH + GAP, 1500          # pipeline
    SW, SG, SH = 245, 45, 160                      # stages
    SY = PY + 175
    sx0 = PX + (PW - 5 * SW - 4 * SG) / 2          # fileira centrada
    sx = [sx0 + i * (SW + SG) for i in range(5)]
    scx = [x + SW / 2 for x in sx]
    SCY = SY + 75
    BUS = PY + 127                                 # barramento de reprovacao
    # jobs (L59): um coletor sob os 5 stages e UMA seta dele ate o runner
    YCOL = SY + SH + 24
    PH = YCOL + 62 - PY
    AX, AY = 30, PY + PH + GAP                     # regiao AWS
    DY = AY - 790                                  # desloca o bloco AWS
    VX, VY = 410, AY + 55                          # VPC fiap-lab
    RX, RY, RW, RH = 680, VY + 140, 240, 320       # runner
    FX, FY, FW = 1110, RY, 620                     # frotas: mesmo topo
    # jobs (L59): descem do vao entre os stages 2 e 3, sem toco alinhado
    XJ = sx[1] + SW + SG / 2
    Y_DEPLOY = FY + 26                             # cabecalho das frotas
    Y_STATE, Y_TOKEN = RY + 45, RY + RH - 40
    PNX, PNW = FX + 20, FW - 40                    # paineis dev / prod
    ALB_X = PNX + 64
    TG_L = ALB_X + 28 + 60
    EC2_X = TG_L + 150 + 72 + 28
    DEVY, PRODY = FY + 50, FY + 220
    paineis = (("dev", "dev · 1 nó", DEVY, 150, DEVY + 62, [DEVY + 62]),
               ("prod", "prod · 3 nós", PRODY, 245, PRODY + 130,
                [PRODY + 62, PRODY + 130, PRODY + 198]))
    FH = PRODY + 245 + 20 - FY
    # smoke (L11): o leque abre no ponto medio entre os dois ALBs, sem degrau
    X_TRONCO = FX - 25
    Y_SMOKE = (DEVY + 62 + PRODY + 130) / 2
    VW, VH = 1760 - VX, FY + FH + 22 - VY
    AW, AH = 1760, VY + VH + 22 - AY
    LY = AY + AH + GAP                             # rodape

    # margem externa: moldura invisivel que o export inclui no recorte
    d._base("rectangle", 0, 0, 1820, LY + 108 + 30, strokeColor="transparent",
            backgroundColor="transparent", strokeWidth=1, roughness=0)

    # --- containers ---------------------------------------------------------
    d.ret(BX, BY, BW, BH, cor=CINZA, bg=FUNDO, largura=1)
    d.texto("Preparação · uma vez, automatizada:  make bootstrap REPO=… "
            "GITLAB_TOKEN=…   (rodar de novo é seguro)",
            BX + 20, BY + 12, BW - 40, size=19, cor=TEXTO, align="left")
    d.caixa(PX, PY, PW, PH, "Pipeline do GitLab CI/CD · os 5 stages do "
            ".gitlab-ci.yml que você escreve", TEXTO, icone="gitlab",
            size=19)
    d.caixa(AX, AY, AW, AH, "AWS · us-east-1 (Learner Lab)", AWS,
            icone="aws-cloud")
    d.caixa(VX, VY, VW, VH, "VPC fiap-lab", VPC_ROXO, icone="vpc-group",
            size=18)
    d.texto("já existe: o Terraform só a\nconsulta (não cria nem apaga)",
            VX + 14, VY + 50, 300, size=18, cor=VPC_ROXO, align="left")
    d.ret(FX, FY, FW, FH, cor=TEXTO, bg="#ffffff")
    d.texto("Frotas dev e prod · módulo web-cluster (você escreve)",
            FX + 24, FY + 13, FW - 38, size=18, align="left")
    for _, _, py, ph, _, _ in paineis:
        d.ret(PNX, py, PNW, ph, bg=PAINEL, sem_borda=True)

    # --- voce: um ator, dois papeis (prepara e desenvolve) -------------------
    eu = d.no("github", CXL, 195, s=64)
    d.texto("Você no\nCodespaces", CXL - 100, 233, 200, size=18)
    d.seta([(eu["r"] + 8, 195), (BX + 32, 195)], cor=CINZA, tracejada=True)
    d.rotulo("uma vez", 232, 152)

    repo = d.no("gitlab", CXL, SCY, s=64)
    d.seta([(CXL - 30, 288), (CXL - 30, repo["t"] - 8)], cor=TEXTO,
           largura=3)
    d.rotulo_dir("git push", CXL - 44, (288 + repo["t"]) / 2 - 11)
    d.texto("Repositório GitLab\ntrabalho-final\n(criado no B1):\n"
            "recebe seu Terraform\ne o .gitlab-ci.yml", CXL - 110,
            repo["b"] + 8, 220, size=18)

    # --- setas da preparacao -------------------------------------------------
    for i in range(3):
        x1 = CX0 + i * (CW + CG) + CW
        d.seta([(x1 - 20, CY + CH / 2), (x1 + CG - 8, CY + CH / 2)],
               cor=CINZA, tracejada=True)

    # --- setas do pipeline ---------------------------------------------------
    # reprovacao (L10, L49, L55): todo stage pode ficar vermelho; o
    # barramento volta para voce (o laco "corrige e faz novo push")
    for i in range(5):
        d.seta([(scx[i], SY + 20), (scx[i], BUS)], cor=ALERTA,
               tracejada=True, ponta=False, roughness=0)
    d.seta([(scx[4], BUS), (CXL + 30, BUS), (CXL + 30, 304)], cor=ALERTA,
           tracejada=True, largura=2, roughness=0)
    d.rotulo("qualquer job vermelho interrompe o pipeline: a mensagem diz o "
             "que corrigir (o teste aponta o Requisito do README) e você faz "
             "novo push\nfalhou antes do deploy? nada foi criado na AWS · "
             "falhou no smoke? dev e prod já estão no ar, e o novo push "
             "corrige", 1030, BUS - 64, size=18, cor=ALERTA)

    d.seta([(repo["r"] + 8, SCY), (sx[0] - 8, SCY)], cor=TEXTO, largura=3)
    d.rotulo("dispara", 232, SCY - 42)
    for i in range(4):
        d.seta([(sx[i] + SW - 20, SCY), (sx[i + 1] - 8, SCY)], cor=TEXTO,
               largura=3)

    # o GitLab entrega os jobs ao runner (L48); e o runner que age na AWS
    for x in scx:
        d.seta([(x, SY + SH - 10), (x, YCOL)], cor=TEXTO, largura=3,
               ponta=False, roughness=0)
    d.seta([(scx[0], YCOL), (scx[4], YCOL)], cor=TEXTO, largura=3,
           ponta=False, roughness=0)
    d.seta([(XJ, YCOL), (XJ, RY - 8)], cor=TEXTO, largura=3, roughness=0)
    d.rotulo_esq("o GitLab entrega os jobs de todos os stages ao runner",
                 XJ + 22, YCOL + 16)

    # deploy: um destino so, o cabecalho das frotas (L42, L45); o trecho
    # vertical fica a 80 px do tronco do smoke (L41)
    d.seta([(RX + RW - 20, Y_DEPLOY), (FX - 12, Y_DEPLOY)], cor=TEXTO,
           largura=3, roughness=0)
    d.rotulo("deploy:\nterraform apply\ndev, depois prod",
             (RX + RW + FX) / 2, Y_DEPLOY - 83)
    # smoke: leque de um ponto ate os dois ALBs (L11, L22)
    for _, _, _, _, alb_y, _ in paineis:
        d.seta([(RX + RW - 20, Y_SMOKE), (X_TRONCO, Y_SMOKE),
                (X_TRONCO, alb_y), (ALB_X - 36, alb_y)], cor=TEXTO,
               largura=3, roughness=0)
    d.rotulo("smoke-dev e\nsmoke-prod:\npytest chama\nos dois ALBs",
             (RX + RW + X_TRONCO) / 2, Y_SMOKE - 106)

    # apoio na regiao (L21: fora da VPC). L31: o ator esta no rotulo.
    d.seta([(RX + 15, Y_STATE), (350 + 8, Y_STATE)], cor=CINZA,
           tracejada=True)
    d.rotulo("o Terraform\ngrava o state", (VX + RX) / 2, Y_STATE - 62)
    d.seta([(350 - 15, Y_TOKEN), (RX - 8, Y_TOKEN)], cor=CINZA,
           tracejada=True)
    d.rotulo("fornece o token\nque registra o\nrunner (B3)", (VX + RX) / 2,
             Y_TOKEN - 84)

    # frotas: ALB -> Target Group -> EC2 (seta fina cinza = trafego HTTP)
    for env, _, _, _, alb_y, ys in paineis:
        d.seta([(ALB_X + 20, alb_y), (TG_L - 8, alb_y)], cor=CINZA,
               largura=2, roughness=0)
        xt = TG_L + 150 + 22
        for ey in ys:
            d.seta([(TG_L + 140, alb_y), (xt, alb_y), (xt, ey),
                    (EC2_X - 36, ey)], cor=CINZA, largura=2, roughness=0)

    # --- cartoes e nos -------------------------------------------------------
    cards = [
        ("B1 · projeto no GitLab",
         "cria o projeto trabalho-final,\ncadastra a chave SSH e\n"
         "desliga os runners\ncompartilhados"),
        ("B2 · runner registrado",
         "cria o runner no projeto e\nguarda o token (glrt-…) no\n"
         "SSM Parameter Store\n(SecureString)"),
        ("B3 · EC2 do runner",
         "sobe qc-runner-trabalho-final\n(IAM LabRole); o Ansible roda\n"
         "no Codespaces e a configura\nvia SSM, sem SSH"),
        ("B4 · clone + kit de testes",
         "clona o repositório e faz\npush de tests/ e validacao/\n"
         "(sem .gitlab-ci.yml ainda,\nnenhum pipeline roda)"),
    ]
    for i, (t, c) in enumerate(cards):
        d.cartao(CX0 + i * (CW + CG), CY, CW, CH, t, c)

    etapas = [
        ("1 · validar", "fmt-validate: fmt e validate\ntf-test: terraform "
         "test\ncheckov: relatório de\nsegurança (não barra)"),
        ("2 · planejar", "plan-dev e plan-prod:\nterraform plan -out\n"
         "plan-<env>.tfplan"),
        ("3 · contrato", "contrato-dev e\ncontrato-prod: pytest\n"
         "do kit sobre o plan\n(nomes, nós, backend)"),
        ("4 · deploy", "deploy-dev, depois\ndeploy-prod: apply do\n"
         "plan que passou\nno contrato"),
        ("5 · smoke", "com dev e prod no ar:\npytest chama cada ALB\n"
         "(HTTP 200; 1 nó em dev,\n3 em prod, todos healthy)"),
    ]
    for x, (t, c) in zip(sx, etapas):
        d.cartao(x, SY, SW, SH, t, c)

    d.cartao(60, Y_STATE - 92, 290, 190, "Amazon S3\nbase-config-<seu RM>",
             "state do Terraform:\nkey trabalho-final/\nterraform.tfstate\n"
             "(um state por\nworkspace: dev e prod)", icone="s3",
             abaixo=True)
    d.cartao(60, Y_TOKEN - 72, 290, 150, "AWS SSM\nParameter Store",
             "/fiap/trabalho-final/\nrunner-token\n(SecureString, B2)",
             icone="parameter-store", abaixo=True)
    d.cartao(RX, RY, RW, RH, "EC2 do runner\n(B3)",
             "qc-runner-trabalho-final\n\nGitLab Runner (shell):\n"
             "roda todos os jobs.\n\nterraform, checkov e\n"
             "pytest: instalados\npelo Ansible.\n\nIAM LabRole: nenhuma\n"
             "chave AWS no GitLab.", icone="ec2", abaixo=True)

    for env, nome, py, _, alb_y, ys in paineis:
        d.texto(nome, PNX + 14, py + 9, 200, size=18, align="left")
        d.no("elb", ALB_X, alb_y, s=56)
        d.texto(f"ALB\nqc-alb-{env}", ALB_X - 60, alb_y + 34, 120, size=18)
        d.ret(TG_L, alb_y - 25, 150, 50, cor=TEXTO, bg="#ffffff")
        d.texto(f"Target Group\nqc-tg-{env}", TG_L, alb_y - 22, 150,
                size=18)
        for k, ey in enumerate(ys):
            d.no("ec2", EC2_X, ey, s=56)
            d.texto(f"nginx-{env}-{k + 1:03d}", EC2_X + 38, ey - 11, 140,
                    size=18, align="left")

    # --- rodape: legenda e fim -----------------------------------------------
    itens = [(TEXTO, False, 3, "fluxo principal", TEXTO),
             (CINZA, False, 2, "HTTP dentro das frotas", TEXTO),
             (CINZA, True, 2, "preparação e apoio", ESCURO),
             (ALERTA, True, 2, "reprovação: volta para você", ALERTA)]
    LW = 20 + sum(72 + larg(t, 18) + 34 for *_, t, _ in itens)
    d.caixa(30, LY, LW, 108, "Legenda", TEXTO, bg=PAINEL, size=18)
    lx = 50
    for cor, tr, lg, t, tc in itens:
        d.seta([(lx, LY + 74), (lx + 60, LY + 74)], cor=cor, tracejada=tr,
               largura=lg)
        d.texto(t, lx + 72, LY + 62, larg(t, 18) + 6, size=18, cor=tc,
                align="left")
        lx += 72 + larg(t, 18) + 34
    DX = 30 + LW + 30
    d.caixa(DX, LY, 1790 - DX, 108, "Ao terminar: make destroy", TEXTO,
            bg=PAINEL, size=18)
    d.texto("apaga dev, prod e o runner (EC2, registro no GitLab\ne token). "
            "A VPC fiap-lab e o bucket ficam.", DX + 14, LY + 44,
            1790 - DX - 28, size=18, cor=TEXTO, align="left")
    log(f"  legenda: caixa {LW:.0f} px; destroy {1790 - DX:.0f} px")

    for v in folgas(d):
        log("  FOLGA:", v)
    for v in sobreposicoes(d):
        log("  SOBREPOSICAO:", v)
    d.salvar(os.path.join(DIR, "arquitetura-final.excalidraw"))


if __name__ == "__main__":
    arquitetura_final()
