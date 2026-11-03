# Exercício 01.A - Count na prática: filas para o catálogo da Quantum Commerce

> **Segunda-feira, 9h. Comitê de Tecnologia da Quantum Commerce, Projeto 3: Categorização Automatizada do Catálogo.**
> A cada semana entram **50 mil itens novos** no catálogo de moda e eletrônicos, e hoje alguém classifica tudo à mão. Nenhuma IA roda neste projeto ainda. **Helena Marques**, Head de Engenharia de IA e Entrega Contínua, quer resolver primeiro a base:
>
> > *— "Hoje não vamos classificar nenhum produto com IA. Quero provar uma capacidade básica: se amanhã precisarmos de três canais independentes para receber lotes de classificação, você cria três filas em código? E se forem cinco, ajusta sem copiar e colar recurso?"*
>
> **Diego Tavares**, AI SRE sênior, deixa o limite claro: *— "Uma fila SQS só **recebe e guarda mensagens**. Ela não classifica nada, não chama modelo e não distribui mensagens entre as outras filas. Quem decide para qual fila vai cada lote é o produtor, e quem processa é o consumidor; nenhum dos dois existe ainda. Hoje a entrega é só a infraestrutura das filas, e ela tem que escalar mudando um número."*

Os comandos `bash` rodam **no terminal do Codespaces**. A conferência visual é feita **no console da AWS** (serviço SQS). Credenciais: veja [Preparando Credenciais](../../../00-create-codespaces/Inicio-de-aula.md).

> [!WARNING]
> **Pré-requisitos obrigatórios antes de começar:**
>
> - [ ] [Lab 01.3 — Count](../../demos/03-Count/README.md) concluído: você já viu `count` escalar 2 → 3 → 2 lendo o `plan`
> - [ ] Credenciais AWS do Academy atualizadas no Codespaces (o [passo 1](#passo-1) confirma)
> - [ ] Você consegue abrir o [console do SQS em us-east-1](https://us-east-1.console.aws.amazon.com/sqs/v3/home?region=us-east-1#/queues)
>
> **Tempo estimado: ~20–25 min** (execução pura ~5 a 6 min, somando applies de ~30 s, esperas de ~60 s da listagem do SQS e o destroy; o resto é escrever o código, ler o `plan` e registrar a decisão).

**Isto é um desafio, não um tutorial.** Este README diz **o que** construir e **como provar** que funcionou; o código Terraform é seu. As pistas ficam fechadas, e você decide quando abrir.

## Sua missão

Escrever, do zero, uma configuração Terraform que cria **N filas SQS idênticas**, com N controlado por **uma variável numérica**. Depois provar três coisas pelo `plan`:

- com N = 3, nascem 3 filas;
- com N = 5, o Terraform **só acrescenta 2** e não toca nas 3 que já existem;
- com N = 3 de novo, o Terraform **só remove 2**.

No fim, você escreve um `DECISION.md` curto explicando por que `count` serve aqui e quando `for_each` serviria melhor, e destrói tudo o que criou. Nenhuma fila é criada pelo console: só por Terraform.

## O que você já sabe (e onde rever)

| Você vai precisar de | Onde viu |
|---|---|
| Bloco `terraform`/`provider` com região `us-east-1` e `default_tags` | Demo 03: [`versions.tf`](../../demos/03-Count/versions.tf) e o topo do [`main.tf`](../../demos/03-Count/main.tf) |
| `count` criando cópias numeradas (`web[0]`, `web[1]`...) | Demo 03: [Contexto](../../demos/03-Count/README.md#contexto) |
| `count.index` para dar um nome diferente a cada cópia | Demo 03: bloco `aws_instance.web` no [`main.tf`](../../demos/03-Count/main.tf) (procure `format(`) |
| Ler o `plan` para saber o que vai ser criado ou removido | Demo 03: [passo 10](../../demos/03-Count/README.md#passo-10) e [passo 12](../../demos/03-Count/README.md#passo-12) |
| `init`, `plan`, `apply -auto-approve`, `destroy -auto-approve` | Demo 03: [passo 3](../../demos/03-Count/README.md#passo-3) (`init`), [passo 4](../../demos/03-Count/README.md#passo-4) (`plan`), [passo 5](../../demos/03-Count/README.md#passo-5) (`apply`) e [passo 14](../../demos/03-Count/README.md#passo-14) (`destroy`) |

O único recurso novo é `aws_sqs_queue`. Todo o resto você já executou.

## Mapa do exercício

| Etapa | O que você faz | Passos | Tempo |
|-------|----------------|--------|-------|
| [Requisitos](#requisitos-obrigatórios) e [pistas](#pistas-abra-só-se-precisar) | Entende o que construir | | ~4 min |
| [Roteiro](#roteiro) | Escreve o código, cria 3 filas, sobe para 5, volta para 3 (inclui ~4 min só de espera: applies e listagem do SQS) | [1](#passo-1) · [2](#passo-2) · [3](#passo-3) · [4](#passo-4) · [5](#passo-5) · [6](#passo-6) · [7](#passo-7) | ~14 min |
| [Evidências](#evidências-da-atividade) | Escreve o `DECISION.md` | [8](#passo-8) | ~4 min |
| [Limpeza](#limpeza-segura) | Destrói só as filas deste exercício | [9](#passo-9) · [10](#passo-10) | ~3 min |

---

## Requisitos obrigatórios

Sua configuração precisa cumprir **todos** estes itens. Eles descrevem o comportamento, não o código.

| # | Requisito |
|---|-----------|
| **R1** | Provider AWS (`hashicorp/aws`, versão `~> 6.0`) apontando para a região **`us-east-1`**. |
| **R2** | **Uma variável do tipo número** controla quantas filas existem. Valor inicial: **3**. |
| **R3** | **Um único** bloco `resource "aws_sqs_queue"` com `count` ligado a essa variável. Nada de copiar o bloco três vezes. |
| **R4** | Nomes previsíveis, com dois dígitos e começando em 01: **`qc-catalog-classification-01`**, **`-02`**, **`-03`**... |
| **R5** | Toda fila com as tags **`Project = quantum-commerce`** e **`ManagedBy = terraform`**. |
| **R6** | Só os atributos `name` e `tags` na fila (mais o `count`). Fila padrão (Standard), sem FIFO, sem dead-letter queue. |
| **R7** | Os arquivos ficam na sua pasta `~/exercicio-count`, **fora** do clone do curso (o [passo 2](#passo-2) explica por quê). |

## Pistas (abra só se precisar)

Tente primeiro sem abrir. Se travar por mais de 3 minutos, abra o nível seguinte.

<details>
<summary><b>💡 Pista nível 1: a direção</b></summary>
<blockquote>

Você precisa de três peças, que podem ficar num único `main.tf`:

- o bloco `terraform` + `provider "aws"`, que você pode adaptar da Demo 03 (ela usa um provider extra, `http`, que aqui não faz falta). Atenção: lá a região não está escrita no provider, ela vem de uma variável declarada em outro arquivo da demo (`variables.tf`). Se copiar o provider, traga essa variável junto ou escreva a região direto;
- uma `variable` com tipo número e um valor padrão;
- **um** recurso `aws_sqs_queue` que recebe `count` igual a essa variável.

Com `count`, o Terraform cria cópias `[0]`, `[1]`, `[2]`. Se todas tivessem o mesmo `name`, a AWS recusaria (nome de fila é único por conta e região). Então o `name` tem que **mudar a cada cópia**, e o que muda a cada cópia é o `count.index`.

Para as tags, a Demo 03 mostra um jeito que vale para todos os recursos do provider de uma vez. Colocar `tags` direto na fila também atende ao R5.

</blockquote>
</details>

<details>
<summary><b>💡 Pista nível 2: onde está na documentação oficial</b></summary>
<blockquote>

- [Meta-argumento `count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count): leia a parte sobre `count.index`; ela diz **por qual número o índice começa**.
- [Recurso `aws_sqs_queue`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue): na seção *Argument Reference*, procure `name` e `tags`. Ignore o resto: o R6 pede só esses dois.
- [Variáveis de entrada](https://developer.hashicorp.com/terraform/language/values/variables): veja `type` e `default`, e como referenciar a variável em outro bloco (`var.<nome>`).
- [Função `format`](https://developer.hashicorp.com/terraform/language/functions/format): é ela que transforma o número 1 no texto `01`. A Demo 03 usa a mesma função para chamar as máquinas de `nginx-001`.

**Repare numa diferença que o plano vai mostrar:** o Terraform numera as cópias pelo índice, de `[0]` a `[N-1]` (com N = 3: `[0]`, `[1]`, `[2]`). O R4 pede nomes de `01` a `N` (`-01`, `-02`, `-03`). Índice e nome andam juntos, mas deslocados em uma unidade. A conta que transforma um no outro é sua.

Sobre o nome em si: o SQS aceita até 80 caracteres, só letras, números, `-` e `_`. `qc-catalog-classification-05` tem 28, então o limite não é risco aqui.

</blockquote>
</details>

<details>
<summary><b>💡 Pista nível 3: como depurar o nome antes de criar qualquer fila</b></summary>
<blockquote>

O `terraform console` deixa testar uma expressão sem criar nada. Na sua pasta, depois do `terraform init`:

```bash
cd ~/exercicio-count
echo 'format("%02d", 0 + 1)' | terraform console
```

> Saída esperada:
>
> ```text
> "01"
> ```

Como ler isso: `%02d` quer dizer "número inteiro, com 2 dígitos, completando com zero à esquerda". O `0` faz o papel do primeiro `count.index`, e o `+ 1` é a conta da pista nível 2: o índice começa em 0, o nome começa em 01. Troque o `0` por `4` e veja o que sai.

Falta só juntar esse pedaço ao prefixo `qc-catalog-classification-` dentro do `name`. Em HCL, um texto entre aspas aceita expressões dentro de `${ }`, do mesmo jeito que você viu em outros blocos da Demo 03.

A segunda ferramenta de depuração é o próprio `plan`: antes de qualquer `apply`, ele mostra a linha `+ name = "..."` de cada fila. Se o nome estiver errado ali, ainda não custou nada.

</blockquote>
</details>

---

## Roteiro

Os passos abaixo são o procedimento: onde trabalhar, quando rodar cada comando e o que deve aparecer. O conteúdo do `.tf` continua sendo seu.

<a id="passo-1"></a>

**1. Confirme credenciais e Terraform**

```bash
aws sts get-caller-identity --query Arn --output text && terraform -version | head -1
```

> Saída esperada (o número da conta e a versão variam):
>
> ```text
> arn:aws:sts::<account-id>:assumed-role/voclabs/user...
> Terraform v1.x.x
> ```

Se aparecer `ExpiredToken` ou `Unable to locate credentials`, atualize as credenciais ([Preparando Credenciais](../../../00-create-codespaces/Inicio-de-aula.md)) antes de seguir.

---

<a id="passo-2"></a>

**2. Crie sua pasta de trabalho fora do clone do curso**

```bash
mkdir -p ~/exercicio-count && cd ~/exercicio-count && pwd
```

> Saída esperada:
>
> ```text
> /home/vscode/exercicio-count
> ```

O caminho **não** pode conter `FIAP-AI-Devops-CICD`. Por quê: o `terraform init` cria uma pasta `.terraform/` e o `apply` cria o arquivo de estado (`terraform.tfstate`). Dentro do clone do curso, esses arquivos atrapalhariam o seu próximo `git pull` do material da aula. Numa pasta própria, o seu código e o seu estado ficam isolados.

---

<a id="passo-3"></a>

**3. Escreva sua configuração**

Abra um arquivo novo no editor do Codespaces:

```bash
code ~/exercicio-count/main.tf
```

Escreva ali o código que cumpre os requisitos [R1 a R6](#requisitos-obrigatórios) e salve (`Ctrl+S`). Pode dividir em vários arquivos (`versions.tf`, `variables.tf`...) se preferir: o Terraform lê todos os `.tf` da pasta.

Depois formate e valide:

```bash
cd ~/exercicio-count && terraform init && terraform fmt && terraform validate
```

> Saída esperada (últimas linhas):
>
> ```text
> Terraform has been successfully initialized!
> ...
> Success! The configuration is valid.
> ```

O `validate` só confere a sintaxe; ele não prova que os nomes estão certos. Quem prova é o passo 4.

---

<a id="passo-4"></a>

**4. Leia o plano com 3 filas**

```bash
cd ~/exercicio-count && terraform plan
```

> Saída esperada (as linhas que importam; `<seu_nome>` é o nome que você deu ao recurso):
>
> ```text
>   # aws_sqs_queue.<seu_nome>[0] will be created
>       + name = "qc-catalog-classification-01"
>   # aws_sqs_queue.<seu_nome>[1] will be created
>       + name = "qc-catalog-classification-02"
>   # aws_sqs_queue.<seu_nome>[2] will be created
>       + name = "qc-catalog-classification-03"
> Plan: 3 to add, 0 to change, 0 to destroy.
> ```

Repare no par índice/nome: o índice `[0]` vira o nome `-01`. Se os nomes não forem exatamente esses três, corrija o código **antes** do apply e rode o `plan` de novo.

---

<a id="passo-5"></a>

**5. Crie as 3 filas e confira na AWS**

```bash
cd ~/exercicio-count && terraform apply -auto-approve
aws sqs list-queues --queue-name-prefix qc-catalog
```

> Saída esperada (a ordem das URLs pode variar):
>
> ```text
> Apply complete! Resources: 3 added, 0 changed, 0 destroyed.
> {
>     "QueueUrls": [
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-01",
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-02",
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-03"
>     ]
> }
> ```

O `apply` leva cerca de 30 segundos. Cada fila mostra `Still creating...` por uns 27 s antes do `Creation complete`: é o tempo normal do SQS, o terminal não travou.

Se o `list-queues` mostrar menos de 3 URLs, a listagem do SQS ainda não atualizou: espere cerca de 60 s e rode de novo, ou confira pelo estado com `terraform state list` (deve listar 3 endereços `aws_sqs_queue.<seu_nome>[0]` a `[2]`).

No [console do SQS](https://us-east-1.console.aws.amazon.com/sqs/v3/home?region=us-east-1#/queues), digite `qc-catalog` na busca por prefixo: aparecem **3 filas**, todas do tipo **Standard**. Abra uma delas, aba **Tags**: lá estão `Project = quantum-commerce` e `ManagedBy = terraform`. A coluna de mensagens disponíveis mostra **0**, e é o esperado: ninguém envia mensagens ainda.

<!-- TROCAR-IMAGEM: img/sqs-to-be.png | motivo: print antigo com filas "fila-criada-0" a "fila-criada-4" (nome fora do padrão e índice começando em 0), contradiz o R4 e faria o aluno duvidar dos próprios nomes | capturar: console SQS filtrado por "qc-catalog" com as 3 filas qc-catalog-classification-01..03, tipo Standard -->
<!-- ![Console SQS com as filas do catálogo](img/sqs-to-be.png) -->

Para conferir as tags pelo terminal:

```bash
aws sqs list-queue-tags --queue-url "$(aws sqs get-queue-url --queue-name qc-catalog-classification-01 --query QueueUrl --output text)"
```

> Saída esperada (pode haver tags extras, se você colocou):
>
> ```text
> {
>     "Tags": {
>         "ManagedBy": "terraform",
>         "Project": "quantum-commerce"
>     }
> }
> ```

---

<a id="passo-6"></a>

**6. Suba para 5 filas e leia o plano antes de aplicar**

No seu código, troque o valor padrão da variável de `3` para `5` e salve. Depois:

```bash
cd ~/exercicio-count && terraform plan
```

> Saída esperada (as linhas que importam):
>
> ```text
>   # aws_sqs_queue.<seu_nome>[3] will be created
>       + name = "qc-catalog-classification-04"
>   # aws_sqs_queue.<seu_nome>[4] will be created
>       + name = "qc-catalog-classification-05"
> Plan: 2 to add, 0 to change, 0 to destroy.
> ```

Esta é a lição do exercício: as filas `[0]`, `[1]` e `[2]` **não aparecem** no plano, porque nada nelas mudou. Só se o resumo for `2 to add, 0 to change, 0 to destroy`, aplique:

```bash
cd ~/exercicio-count && terraform apply -auto-approve
aws sqs list-queues --queue-name-prefix qc-catalog
```

> Saída esperada: `Apply complete! Resources: 2 added, 0 changed, 0 destroyed.` e **5 URLs**, de `-01` a `-05`.

No teste real, o `list-queues` rodado logo depois do apply ainda mostrava **3** URLs. Não é erro: a listagem do SQS atrasa. Espere cerca de 60 s e rode de novo, ou confira na hora com `terraform state list`, que já mostra os 5 índices.

---

<a id="passo-7"></a>

**7. Volte para 3 filas**

Troque o valor padrão de `5` para `3`, salve e leia o plano:

```bash
cd ~/exercicio-count && terraform plan
```

> Saída esperada (as linhas que importam):
>
> ```text
>   # aws_sqs_queue.<seu_nome>[3] will be destroyed
>   # aws_sqs_queue.<seu_nome>[4] will be destroyed
> Plan: 0 to add, 0 to change, 2 to destroy.
> ```

O `count` sempre remove **do fim da lista**: saem `-04` e `-05`, e as três primeiras ficam intactas. Aplique:

```bash
cd ~/exercicio-count && terraform apply -auto-approve
```

> Saída esperada: `Apply complete! Resources: 0 added, 0 changed, 2 destroyed.`

O `terraform state list` já mostra só `[0]`, `[1]` e `[2]` na hora. A listagem do SQS demora: as filas `-04` e `-05` ainda podem aparecer por cerca de 60 segundos. **Espere 1 minuto** e só então rode:

```bash
aws sqs list-queues --queue-name-prefix qc-catalog
```

> Saída esperada (a ordem das URLs pode variar):
>
> ```text
> {
>     "QueueUrls": [
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-01",
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-02",
>         "https://sqs.us-east-1.amazonaws.com/<account-id>/qc-catalog-classification-03"
>     ]
> }
> ```

Guarde esta saída: ela entra no seu `DECISION.md` no passo 8. Se ainda vierem 5 URLs, espere mais 1 minuto e rode de novo.

---

## Critérios de aceite

O exercício está concluído quando **todos** os itens abaixo forem verdadeiros. Cada um tem um jeito objetivo de conferir.

| # | Critério | Como conferir |
|---|----------|---------------|
| **C1** | O código fica em `~/exercicio-count`, com **um único** `resource "aws_sqs_queue"` usando `count` e uma variável numérica | leitura do seu `.tf`; `pwd` do [passo 2](#passo-2) sem `FIAP-AI-Devops-CICD` |
| **C2** | Com a variável em 3, o plano mostra `Plan: 3 to add, 0 to change, 0 to destroy.` e os nomes `qc-catalog-classification-01`, `-02`, `-03` | [passo 4](#passo-4) |
| **C3** | Depois do apply, `aws sqs list-queues --queue-name-prefix qc-catalog` lista **exatamente 3** URLs terminadas em `-01`, `-02`, `-03`, e o console SQS mostra 3 filas Standard | [passo 5](#passo-5) |
| **C4** | A fila `-01` tem as tags `Project = quantum-commerce` e `ManagedBy = terraform` | `list-queue-tags` do [passo 5](#passo-5) ou aba **Tags** no console |
| **C5** | De 3 para 5, o plano mostra `Plan: 2 to add, 0 to change, 0 to destroy.`, criando só os índices `[3]` e `[4]` (`-04` e `-05`) | [passo 6](#passo-6) |
| **C6** | De 5 para 3, o plano mostra `Plan: 0 to add, 0 to change, 2 to destroy.`, removendo só `[3]` e `[4]` | [passo 7](#passo-7) |
| **C7** | Nenhuma fila foi criada ou apagada pelo console: todas as mudanças vieram de `terraform apply` | seu histórico do terminal |
| **C8** | `DECISION.md` escrito por você, em `~/exercicio-count`, respondendo aos itens e às perguntas D1 e D2 do [passo 8](#passo-8) | o próprio arquivo |
| **C9** | Depois da limpeza, `terraform state list` volta vazio e `list-queues --queue-name-prefix qc-catalog` não lista nenhuma URL | [passo 9](#passo-9) e [passo 10](#passo-10) |

---

## Evidências da atividade

<a id="passo-8"></a>

**8. Escreva o seu `DECISION.md`**

```bash
code ~/exercicio-count/DECISION.md
```

É um registro de decisão curto (estilo ADR), escrito **por você**, em 1 a 3 linhas por item. Não existe modelo pronto para copiar; a argumentação é o exercício.

- **Contexto:** o que Helena pediu e o que **não** foi construído (lembre-se do aviso do Diego sobre o que uma fila SQS faz).
- **Decisão:** por que `count` resolve este pedido.
- **Pergunta D1:** imagine que, em vez de "5 filas iguais", Helena pedisse uma fila por canal de negócio com nome fixo, por exemplo `moda`, `eletronicos` e `acessorios`. O que aconteceria com `count` se o canal do meio deixasse de existir? Por que `for_each` faria mais sentido nesse cenário?
- **Evidência:** cole as três linhas `Plan:` que você viu nos passos 4, 6 e 7 e a saída do `list-queues` do passo 7 (a que você rodou depois de esperar 1 minuto).
- **Pergunta D2 (para o Diego):** uma coisa que você confirmaria com ele antes de ligar produtores e consumidores reais nessas filas.

> [!IMPORTANT]
> **Mascare o Account ID antes de compartilhar.** A URL de cada fila, no output do `apply` e no `list-queues`, carrega o número da sua conta AWS (`https://sqs.us-east-1.amazonaws.com/<ACCOUNT>/qc-catalog-...`). Em texto, troque-o por `<account-id>`; em print, cubra com uma tarja. Também não cole credenciais, a saída de `aws configure` nem o conteúdo do `terraform.tfstate`.

---

## Pontos de atenção

Os erros mais prováveis, com a pista para você mesmo diagnosticar. A correção é sua.

<details>
<summary><b>⚠ Se der erro: os nomes saem <code>-1</code>, <code>-00</code> ou <code>-001</code></b></summary>
<blockquote>

Compare o primeiro `+ name` do plano com o R4. Duas perguntas resolvem: por qual número o `count.index` começa? Quantos dígitos o seu `format` pede? Teste a expressão no `terraform console` ([pista nível 3](#pistas-abra-só-se-precisar)) antes de mexer no `.tf`.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: ao subir para 5, o plano mostra <code>must be replaced</code>, <code>update in-place</code> ou algum <code>destroy</code></b></summary>
<blockquote>

Mudar só o número nunca deveria tocar nas filas existentes. Se o plano mexe nelas, outra coisa mudou junto: procure no plano as linhas marcadas com `~` ou `-/+` e veja qual atributo aparece com `->` (valor antigo → valor novo). Normalmente é o `name` ou uma tag que foi editada ao mesmo tempo. Não aplique até o resumo ser `2 to add, 0 to change, 0 to destroy`.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: o <code>apply</code> terminou, mas o <code>list-queues</code> mostra outro número de filas</b></summary>
<blockquote>

Antes de suspeitar do código, separe as duas fontes. O `terraform state list` diz o que o Terraform criou; o `list-queues` diz o que a listagem do SQS já enxerga, e ela atrasa cerca de 60 s depois de criar ou apagar fila. Se o `state list` tem o número certo de índices, espere 1 minuto e liste de novo. Se o `state list` também está errado, volte à linha `Plan:` do último `plan` e veja o que ele propôs.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: o <code>apply</code> fica parado em <code>Still creating...</code></b></summary>
<blockquote>

Cada fila leva uns 27 s para ficar pronta, e o apply de 3 filas leva cerca de 30 s no total, porque elas são criadas em paralelo. Até 1 minuto é normal. Se passar de 2 minutos, verifique se a sessão do Learner Lab ainda está ativa.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>QueueDeletedRecently</code> ou "You must wait 60 seconds after deleting a queue"</b></summary>
<blockquote>

O SQS não deixa recriar uma fila com o mesmo nome antes de 60 segundos da remoção. Acontece se você voltou de 5 para 3 e logo depois subiu para 5 de novo (ou destruiu e recriou). Não é erro do seu código: espere 1 minuto e rode o mesmo `apply`.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>Reference to undeclared input variable</code></b></summary>
<blockquote>

O seu código usa `var.<algum_nome>` que não foi declarado em nenhum `.tf` da sua pasta. O caso mais comum: o provider copiado da Demo 03 traz `region = var.aws_region`, mas a declaração dessa variável ficou no `variables.tf` da demo, que você não copiou. A mensagem de erro diz o nome da variável e a linha. Duas saídas: declarar essa variável na sua pasta ou escrever a região `us-east-1` direto no provider (R1).

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>Invalid value for input variable</code> ou <code>Incorrect attribute value type</code></b></summary>
<blockquote>

O Terraform está recebendo texto onde espera número (ou o contrário). Confira o `type` da sua variável e se o valor padrão está escrito como número, sem aspas. A [página de variáveis](https://developer.hashicorp.com/terraform/language/values/variables) mostra os tipos aceitos.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>No configuration files</code> ou o plano propõe criar tudo de novo</b></summary>
<blockquote>

Você provavelmente está em outra pasta. Rode `pwd`: deve ser `~/exercicio-count`. O estado das suas filas vive só nessa pasta; numa pasta diferente, o Terraform não sabe que elas existem.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: <code>ExpiredToken</code>, <code>InvalidClientTokenId</code> ou <code>AccessDenied</code></b></summary>
<blockquote>

A sessão do Learner Lab expirou ou as credenciais no Codespaces estão velhas. Atualize-as ([Preparando Credenciais](../../../00-create-codespaces/Inicio-de-aula.md)) e repita o último comando. O estado na sua pasta continua valendo: o Terraform retoma de onde parou.

</blockquote>
</details>

<details>
<summary><b>⚠ Se der erro: a fila aparece no console, mas sem as tags</b></summary>
<blockquote>

Releia o R5 e confira se as tags estão em um lugar que o Terraform aplica a esta fila: no próprio recurso ou no `default_tags` do provider. O plano mostra a linha `tags_all` de cada fila; é nela que as tags finais aparecem.

</blockquote>
</details>

---

## Limpeza segura

Este exercício cria **só filas SQS**. Ele não usa, não lê e não altera a VPC `fiap-lab` da Demo 02: **não rode `destroy` em nenhuma pasta de demo** do curso, só na sua `~/exercicio-count`.

<a id="passo-9"></a>

**9. Destrua as filas deste exercício**

```bash
cd ~/exercicio-count && terraform destroy -auto-approve && terraform state list
```

> Saída esperada:
>
> ```text
> Destroy complete! Resources: 3 destroyed.
> ```

O `terraform state list` logo depois não imprime nada: o estado ficou vazio.

---

<a id="passo-10"></a>

**10. Confirme que nenhuma fila ficou**

Espere cerca de 1 minuto (a listagem do SQS demora para refletir a remoção) e rode:

```bash
aws sqs list-queues --queue-name-prefix qc-catalog
```

> Saída esperada: **nenhuma URL** (a saída vem vazia). No console do SQS, a busca por `qc-catalog` também não mostra nada.

Se ainda aparecer alguma URL depois de 2 minutos, volte ao [passo 9](#passo-9): o `destroy` remove só o que sobrou no estado. A pasta `~/exercicio-count` pode ficar: ela guarda o seu código e o seu `DECISION.md`.

> [!CAUTION]
> SQS cobra por requisição, e fila vazia parada não gera custo relevante. Mesmo assim, a limpeza é parte do critério de aceite (C9): infraestrutura de laboratório que fica para trás vira lixo de conta e confunde o próximo exercício.

---

## Próximo passo

Abra o **[Exercício 01.B — State remoto e Workspaces](../State-e-workspace/README.md)**. Lá o estado sai da sua pasta local e vai para um lugar compartilhado.

---

<details>
<summary><b>💡 Glossário rápido</b></summary>
<blockquote>

| Termo | O que é |
|-------|---------|
| **SQS** | Simple Queue Service: fila gerenciada da AWS. Recebe mensagens e as guarda até um consumidor ler; não processa nada sozinha. |
| **Fila Standard** | Tipo padrão de fila SQS: alta vazão, sem garantia de ordem. |
| **Produtor / consumidor** | Quem envia mensagens para a fila / quem lê e processa. Neste exercício, nenhum dos dois existe. |
| **`count`** | Meta-argumento que cria N cópias numeradas de um recurso. |
| **`count.index`** | A posição da cópia atual, começando em 0. |
| **`for_each`** | Alternativa ao `count` que cria uma cópia por chave (nome fixo), em vez de por posição. |
| **HCL** | HashiCorp Configuration Language: a linguagem dos arquivos `.tf`. |
| **FIFO** | Tipo de fila SQS com ordem garantida e nome terminado em `.fifo`; não é usado aqui (R6). |
| **Dead-letter queue (DLQ)** | Fila separada que recebe as mensagens que falharam várias vezes no consumidor; não é usada aqui (R6). |
| **`default_tags`** | Bloco dentro do `provider "aws"` que aplica as mesmas tags a todos os recursos daquele provider. |
| **`terraform console`** | Terminal interativo do Terraform para testar expressões sem criar recursos. |
| **ADR** | Architecture Decision Record: registro curto de uma decisão técnica e do porquê. |

</blockquote>
</details>

<details>
<summary><b>💡 Referências oficiais</b></summary>
<blockquote>

- [Terraform: meta-argumento `count`](https://developer.hashicorp.com/terraform/language/meta-arguments/count)
- [Terraform: variáveis de entrada](https://developer.hashicorp.com/terraform/language/values/variables)
- [Terraform: função `format`](https://developer.hashicorp.com/terraform/language/functions/format)
- [Terraform: comando `terraform console`](https://developer.hashicorp.com/terraform/cli/commands/console)
- [Provider AWS: recurso `aws_sqs_queue`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue)
- [AWS CLI: `aws sqs list-queues`](https://docs.aws.amazon.com/cli/latest/reference/sqs/list-queues.html)
- [Amazon SQS: `DeleteQueue`](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/APIReference/API_DeleteQueue.html), que documenta a espera de 60 segundos para recriar uma fila com o mesmo nome

</blockquote>
</details>

<details>
<summary><b>💡 Como pedir ajuda se travou</b></summary>
<blockquote>

Antes de pedir ajuda, colete estas 4 informações:

1. **Em que passo você está** (ex.: "passo 6, subi para 5")
2. **Mensagem de erro literal** (a partir da linha `Error:`) ou a linha `Plan:` que veio diferente da esperada
3. **Saída de `pwd`** (prova que você está em `~/exercicio-count`)
4. **O que você já tentou** e quais pistas já abriu

Canais (em ordem de prioridade):

- **Issues do repositório**: [github.com/vamperst/FIAP-AI-Devops-CICD/issues](https://github.com/vamperst/FIAP-AI-Devops-CICD/issues)
- **E-mail do professor**: `Rafael@rfbarbosa.com`

</blockquote>
</details>
