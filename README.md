<div align="center">

# AntiModels

**Habilite qualquer modelo de IA externo no Antigravity.**

OpenAI · Anthropic · DeepSeek · Groq · xAI · Ollama · qualquer API compatível

[![License](https://img.shields.io/github/license/matheusqxt/AntiModels?color=green)](LICENSE)
[![Stars](https://img.shields.io/github/stars/matheusqxt/AntiModels?color=yellow)](https://github.com/matheusqxt/AntiModels/stargazers)
[![Last commit](https://img.shields.io/github/last-commit/matheusqxt/AntiModels)](https://github.com/matheusqxt/AntiModels/commits/main)
[![Issues](https://img.shields.io/github/issues/matheusqxt/AntiModels)](https://github.com/matheusqxt/AntiModels/issues)
[![Top language](https://img.shields.io/github/languages/top/matheusqxt/AntiModels)](https://github.com/matheusqxt/AntiModels)

[![Windows](https://img.shields.io/badge/Windows-10%2B-0078D6?logo=windows&logoColor=white)](#requisitos)
[![Node.js](https://img.shields.io/badge/Node.js-22.13%2B-339933?logo=nodedotjs&logoColor=white)](#requisitos)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?logo=powershell&logoColor=white)](#requisitos)
[![PRs welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)](#contribuindo)

</div>

---

O Antigravity desktop só oferece os modelos nativos do Google. O AntiModels adiciona os seus —
seus modelos, suas chaves, seu custo por token.

**No seletor de modelos do chat:**

```
Gemini 4 Argon            nativo
Claude Opus 5.5           nativo
GPT-4o                    <- seu
DeepSeek V4 Pro           <- seu
Groq · GPT-OSS 120B       <- seu
```

## Instalação

```powershell
git clone https://github.com/matheusqxt/AntiModels.git
cd AntiModels

.\INSTALAR-COMPLEMENTO.ps1                                     # uma vez, ~2 min
.\APLICAR-MODELOS.ps1 -Provider openai -Key sk-xxx -FecharApp  # adicione um provedor
.\VERIFICAR.ps1                                                # confira o estado
```

**Depois abra o Antigravity uma vez.** É no boot que ele cifra as chaves e registra os modelos no
seletor do chat.

Saída real do segundo comando:

```console
$ .\APLICAR-MODELOS.ps1 -Provider anthropic -Key sk-ant-xxx -FecharApp
[*] node gerar-modelos.js --provider anthropic --key **** --merge
merge: 3 adicionados, 0 atualizados, 3 no total
[+] Aplicado. Abra o Antigravity: ele cifra as chaves e aloca a identidade dos modelos.
```

## Como funciona

O Antigravity carrega modelos custom de um arquivo JSON local:

```
~/.gemini/antigravity/custom_models.json
```

No boot, o app lê esse arquivo, **cifra as chaves** com o DPAPI do Windows e **aloca uma identidade
nativa** para cada modelo — é isso que faz eles aparecerem no seletor junto dos built-in.

O AntiModels gera esse arquivo para você, **sem** depender do *Fetch provider models* da interface:

```
+-----------------+      +------------------+      +-------------------+
| provider-       | ---> |  gerar-modelos   | ---> | custom_models     |
| catalog.json    |      |  .js             |      | .json             |
+-----------------+      +------------------+      +---------+---------+
                                                             |
                            Antigravity lê no boot <---------+
                            cifra chaves · aloca identidades
```

## O problema que isto resolve

Não é o roteamento — é a **configuração**, e ela quebra em dois pontos que custam horas.

### 1. O fetch de catálogo falha em silêncio

Com a API respondendo `200`, `/v1/models` no formato OpenAI correto e a chave válida, o painel pode
não retornar catálogo nenhum. Sem catálogo, *Add selected* nunca grava, o arquivo continua com os
exemplos de fábrica, e **nada avisa que deu errado**.

O AntiModels escreve o arquivo direto e valida contra o schema do próprio app.

### 2. A escala de `reasoning_effort` varia por provedor **e por modelo**

Cada endpoint aceita níveis diferentes, e o erro devolvido é genérico:

```json
{"error": {"message": "Invalid inference request. Check the model's supported parameters and input limits."}}
```

Ele **não diz qual campo está errado.** Você testa um por um até achar:

| Provedor | Aceita | Rejeita |
|:--|:--|:--|
| OpenAI | `minimal` `low` `medium` `high` | — |
| Anthropic | `low` `medium` `high` | `none` |
| DeepSeek | `none` `low` `medium` `high` | — |
| xAI | `low` `medium` `high` | `none` |
| Groq | **só `none`** | `low` `medium` `high` -> HTTP 400 |
| Ollama | — | não envia o campo |

E pode variar **dentro do mesmo provedor**, por modelo. O AntiModels guarda a escala em
`effortPerModel`, corrige o nível antes de escrever e avisa:

```console
aviso: 'grok-4.7' receberia effort='none', que nao esta na escala aceita
[low/medium/high]. Usando 'low'.
```

## Provedores

Prontos no catálogo:

`openai` · `anthropic` · `deepseek` · `xai` · `groq` · `ollama`

### Adicione qualquer outro endpoint

O catálogo é um JSON. Estenda para qualquer API compatível:

```json
"meuprovedor": {
  "label": "Meu Provedor",
  "apiUrl": "https://api.exemplo.com/v1/chat/completions",
  "provider": "custom",
  "apiFormat": "openai",
  "keyEnvHint": "MEUPROVEDOR_API_KEY",
  "context": 128000,
  "maxOutput": 16384,
  "effortSupported": ["low", "medium", "high"],
  "defaultEffort": "medium",
  "models": [["modelo-grande", "Modelo Grande", "medium"]]
}
```

```powershell
.\APLICAR-MODELOS.ps1 -Provider meuprovedor -Key xxx
```

## Recursos

| | |
|:--|:--|
| **Merge idempotente** | Acumule OpenAI + Anthropic + Groq + Ollama sem perder nada. Rodar duas vezes não duplica modelo. |
| **Fail-closed** | Se o layout do seu Antigravity não for reconhecido, o instalador **aborta sem alterar arquivo nenhum**. Você nunca termina com um app quebrado. |
| **Rollback verificável** | Hashes do original e do patch guardados; um comando reverte. |
| **Guard de processo** | Recusa escrever com o Antigravity aberto (o app reescreve o arquivo na saída) e faz backup automático antes de sobrescrever. |
| **Diagnóstico** | `VERIFICAR.ps1` mostra o complemento, os arquivos, cada modelo com o status da chave, as identidades alocadas e as últimas injeções no log. |

## Estrutura

```
AntiModels/
├── README.md                    este arquivo
├── LEIA-ME.md                   guia de uso detalhado
├── docs/MECANISMO.md            referência técnica: catálogo, precedência de effort, troubleshooting
├── INSTALAR-COMPLEMENTO.ps1     instala / atualiza / reverte o complemento
├── APLICAR-MODELOS.ps1          gera a configuração para um provedor
├── VERIFICAR.ps1                diagnóstico do estado
├── gerar-modelos.js             o gerador (motor dos scripts acima)
└── provider-catalog.json        catálogo de provedores
```

## Requisitos

| Item | Mínimo |
|:--|:--|
| Windows | 10 |
| Node.js | 22.13+ — `winget install --id OpenJS.NodeJS.LTS` |
| Git | qualquer |
| Antigravity | 2.x standalone (desktop) |

> Não funciona no Antigravity IDE (VS Code) nem em sessões WSL — o complemento cobre apenas o
> desktop standalone em sessão local.

## Custo

Todo modelo adicionado consome tokens pagos na sua conta do provedor.
**Ollama é a única opção sem custo por token** — e está no catálogo.

## Contribuindo

Issues e PRs são bem-vindos. Se um provedor novo funcionar (ou falhar) para você, abra uma issue
com a **saída do `VERIFICAR.ps1`** e a versão do seu Antigravity — é o que permite marcar
compatibilidade com evidência em vez de suposição.

Para validar um provedor antes de reportar, siga o procedimento em
[`docs/MECANISMO.md` §8](docs/MECANISMO.md).

## Créditos

**[@matheusqxt](https://github.com/matheusqxt)** — descoberta do mecanismo e autoria deste kit.

Nada disso está documentado pelo fabricante: que o arquivo é o `custom_models.json`, que o app
cifra as chaves no boot, que o `name` é um identificador interno imutável ligado a uma identidade
nativa, e que a escala de `reasoning_effort` varia por modelo falhando com uma mensagem de erro que
não ajuda. Esse trabalho de engenharia reversa é o que este repositório publica.

**[antigravity-add-model](https://github.com/vahapogut/antigravity-add-model)** —
[@vahapogut](https://github.com/vahapogut). O complemento que efetivamente habilita modelos externos
no Antigravity desktop. **Sem ele, nada disso funcionaria.** O AntiModels gera a configuração para
ele; todo o crédito pela injeção no app é do autor.

**[Hermes Agent](https://github.com/NousResearch/hermes-agent)** — Nous Research. O agente usado
para inspecionar o app, testar os endpoints e validar o mecanismo ponta a ponta.

**Antigravity** — Google. Marca e produto de seus respectivos donos.

## Aviso

Projeto independente, sem afiliação com o Google. Manipula arquivos da instalação local do
Antigravity (`app.asar`), por isso o instalador mantém backup e rollback. Use por sua conta e risco;
teste em um ambiente que você possa restaurar.

## Licença

[MIT](LICENSE) © matheusqxt

<div align="center">
<sub>Se este projeto te economizou tempo, uma ⭐ ajuda outros a encontrarem.</sub>
</div>
