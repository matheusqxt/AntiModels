# AntiModels

**Habilite qualquer modelo de IA externo no Antigravity — OpenAI, Anthropic, DeepSeek, Groq, xAI, Ollama e qualquer API compatível.**

O Antigravity desktop só oferece os modelos nativos do Google. Este kit adiciona os seus: seus
modelos, suas chaves, seu custo por token — sem passar pelo "Fetch provider models" da interface,
que falha silenciosamente com vários provedores.

```
Antigravity/
├── Gemini 4 Argon          ← nativo
├── Claude Opus 5.5         ← nativo
├── GPT-4o (OpenAI)         ← seu, via este kit
├── DeepSeek V4 Pro         ← seu, via este kit
└── Groq · GPT-OSS 120B     ← seu, via este kit
```

---

## Como funciona

O Antigravity carrega modelos custom de um arquivo JSON local:

```
~/.gemini/antigravity/custom_models.json
```

No boot, o app lê esse arquivo, **cifra as chaves** com o DPAPI do Windows e **aloca uma identidade
nativa** para cada modelo. A partir daí eles aparecem no seletor do chat, junto dos built-in.

Este kit gera esse arquivo para você — **sem** depender da descoberta de catálogo pela GUI, que em
vários provedores simplesmente não retorna nada e não diz por quê.

---

## Uso

```powershell
# 1. Instalar (uma vez, ~2 min)
.\INSTALAR-COMPLEMENTO.ps1

# 2. Adicionar um provedor
.\APLICAR-MODELOS.ps1 -Provider openai -Key sk-xxx -FecharApp

# 3. Conferir
.\VERIFICAR.ps1

# 4. Abrir o Antigravity uma vez — ele cifra as chaves e registra os modelos
```

Pronto. No seletor de modelos do chat, escolha o seu.

```
$ .\APLICAR-MODELOS.ps1 -Provider anthropic -Key sk-ant-xxx -FecharApp
[*] node gerar-modelos.js --provider anthropic --key **** --merge
merge: 3 adicionados, 0 atualizados, 3 no total
[+] Aplicado. Abra o Antigravity: ele cifra as chaves e aloca a identidade dos modelos.
```

Provedores prontos: `openai` · `anthropic` · `deepseek` · `xai` · `groq` · `ollama`

### Adicionar qualquer outro endpoint

O catálogo é um JSON — estenda para qualquer API compatível:

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

---

## O problema que este kit resolve

Não é o roteamento — é a **configuração**, e ela quebra em dois pontos que custam horas:

### 1. O `Fetch provider models` falha em silêncio

Com uma API respondendo `200`, `/v1/models` no formato OpenAI correto, e a chave válida, o painel
pode não retornar catálogo nenhum. Sem catálogo, o botão "Add selected" nunca grava, o arquivo
continua com os exemplos de fábrica, e **nada avisa que deu errado**.

O kit escreve o arquivo direto e valida contra o schema do próprio app.

### 2. A escala de `reasoning_effort` varia por provedor **e por modelo**

Cada endpoint aceita níveis diferentes, e o erro é genérico:

```json
{"error": {"message": "Invalid inference request. Check the model's supported parameters and input limits."}}
```

Ele **não diz qual campo está errado**. Você testa um por um até achar:

| Provedor | Aceita | Rejeita |
|---|---|---|
| OpenAI | `minimal` `low` `medium` `high` | — |
| Anthropic | `low` `medium` `high` | `none` |
| DeepSeek | `none` `low` `medium` `high` | — |
| xAI | `low` `medium` `high` | `none` |
| Groq | **só `none`** | `low` `medium` `high` → HTTP 400 |
| Ollama | — | não envia o campo |

Pior: pode variar **dentro do mesmo provedor**, por modelo. O kit guarda a escala em
`effortPerModel`, corrige o nível antes de escrever e avisa:

```
aviso: 'grok-4.7' receberia effort='none', que nao esta na escala aceita
[low/medium/high]. Usando 'low'.
```

---

## Recursos

- **`--merge` idempotente** — acumule OpenAI + Anthropic + Groq + Ollama sem perder nada. Rodar
  duas vezes não duplica modelo.
- **Fail-closed** — se o layout do seu Antigravity não for reconhecido, o instalador **aborta sem
  alterar arquivo nenhum**. Você nunca termina com um app quebrado.
- **Rollback verificável** — hashes do original e do patch guardados; um comando reverte.
- **Guard de processo** — recusa escrever com o Antigravity aberto (o app reescreve o arquivo na
  saída) e faz backup automático antes de sobrescrever.
- **Diagnóstico** — `VERIFICAR.ps1` mostra complemento, arquivos, cada modelo com status da chave,
  identidades alocadas e as últimas injeções no log do proxy.

---

## Estrutura

| Arquivo | O que é |
|---|---|
| `LEIA-ME.md` | Guia de uso |
| `docs/MECANISMO.md` | Documentação técnica: catálogo, precedência de effort, troubleshooting |
| `INSTALAR-COMPLEMENTO.ps1` | Instala / atualiza / reverte o complemento |
| `APLICAR-MODELOS.ps1` | Gera a configuração para um provedor |
| `VERIFICAR.ps1` | Diagnóstico do estado |
| `gerar-modelos.js` | O gerador (motor dos scripts acima) |
| `provider-catalog.json` | Catálogo de provedores |

---

## Créditos

**Descoberta e engenharia do mecanismo:** este kit existe porque alguém teve que descobrir, na
prática, como o Antigravity carrega modelos externos — que o arquivo é o `custom_models.json`,
que ele cifra as chaves no boot, que o `name` é um identificador interno imutável ligado a uma
identidade nativa, e que a escala de `reasoning_effort` varia por modelo e falha com uma mensagem
de erro que não ajuda. Nada disso está documentado pelo fabricante.

**[@matheusqxt](https://github.com/matheusqxt)** fez essa descoberta e construiu este kit.

**Ferramentas e projetos que tornaram possível:**

- [**antigravity-add-model**](https://github.com/vahapogut/antigravity-add-model) — de
  [@vahapogut](https://github.com/vahapogut). O complemento que efetivamente habilita modelos
  externos no Antigravity desktop. Este kit gera a configuração para ele; sem ele, nada disso
  funcionaria. Todo o crédito pela injeção no app é do autor.
- [**Hermes Agent**](https://github.com/NousResearch/hermes-agent) — da Nous Research. O agente
  usado para inspecionar o app, testar os endpoints e validar o mecanismo ponta a ponta.
- [**Node.js**](https://nodejs.org/) — runtime do gerador (requer 22.13+).
- **Antigravity** — Google. Marca e produto de seus respectivos donos; este é um projeto
  independente, não afiliado.

---

## Requisitos

| Item | Mínimo |
|---|---|
| Windows | 10 |
| Node.js | 22.13+ (`winget install --id OpenJS.NodeJS.LTS`) |
| Git | qualquer |
| Antigravity | 2.x standalone (desktop) |

Não funciona no Antigravity IDE (VS Code) nem em sessões WSL — o complemento cobre apenas o
desktop standalone em sessão local.

---

## Custo

Todo modelo adicionado consome tokens pagos na sua conta do provedor. **Ollama é a única opção sem
custo por token** — e está no catálogo.

---

## Aviso

Projeto independente, sem afiliação com o Google. Manipula arquivos da instalação local do
Antigravity (`app.asar`), por isso o instalador mantém backup e rollback. Use por sua conta e
risco; teste em um ambiente que você possa restaurar.

---

## Licença

MIT — veja `LICENSE`.
