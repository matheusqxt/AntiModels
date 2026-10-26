# Antigravity + Provedores Externos — Mecanismo e Referência

Adicionar **qualquer** provedor OpenAI/Anthropic-compatible ao Antigravity desktop, por um
gerador parametrizado — sem depender do "Fetch provider models" da interface.

**Status: mecanismo verificado ponta a ponta** (ver §10). Catálogo com 6 provedores prontos e
extensível para qualquer endpoint compatível.

---

## 1. Por que existe um gerador

O caminho oficial (`Settings → Models & Usage → Fetch provider models`) pode falhar mesmo com a API
respondendo 200 e formato OpenAI válido: ele simplesmente não retorna o catálogo, o botão
"Add selected" nunca grava, e o arquivo fica com os 3 exemplos de fábrica. Não há mensagem de erro.

O gerador contorna isso escrevendo `custom_models.json` direto, e resolve a parte que realmente
dá trabalho: **a escala de `reasoning_effort` varia por provedor e por modelo**. Mandar um nível
que o endpoint não aceita devolve HTTP 400 com mensagem genérica
(`"Invalid inference request. Check the model's supported parameters and input limits."`), sem
dizer qual campo está errado. O gerador conhece a escala de cada provedor e corrige antes de
escrever, avisando quando o faz.

---

## 2. Componentes

| Arquivo | Papel |
|---|---|
| `gerar-modelos.js` | Gerador — lê o catálogo, resolve effort, escreve o JSON |
| `provider-catalog.json` | Catálogo de provedores: endpoints, formatos, escalas de effort |
| `~/.gemini/antigravity/custom_models.json` | **Saída** — lido pelo complemento no boot |
| `C:\antigravity-add-model\` | Complemento que habilita modelos externos no app |

---

## 3. Uso do gerador

```bash
export PATH="/c/Program Files/nodejs:$PATH"   # Node 22.13+ obrigatório

node gerar-modelos.js --provider openai --key sk-xxx
node gerar-modelos.js --provider anthropic --key sk-ant-xxx --merge
node gerar-modelos.js --provider groq --key gsk-xxx --models "openai/gpt-oss-20b"
node gerar-modelos.js --provider ollama --models "llama3.3,qwen3.5" --merge
node gerar-modelos.js --provider xai --key xai-xxx --dry-run
```

| Flag | Efeito |
|---|---|
| `--provider NAME` | Chave no catálogo. **Obrigatório.** |
| `--key VALUE` | API key, ou use a env `<PROVIDER>_API_KEY` do catálogo |
| `--models LIST` | IDs separados por vírgula (default: todos do catálogo para aquele provedor) |
| `--effort LEVEL` | Sobrescreve o `reasoningEffort` de todos |
| `--merge` | Preserva modelos existentes; só adiciona/atualiza os do provedor atual |
| `--out PATH` | Destino alternativo |
| `--dry-run` | Imprime o JSON, **não escreve** |

**Exit codes:** `0` ok · `2` provedor inexistente ou sem modelos · `3` Antigravity aberto.

O script recusa escrever com o Antigravity rodando (o app reescreve o arquivo na saída, e você
perderia a alteração) e faz backup automático antes de sobrescrever.

### Fluxo recomendado

```bash
# 1. Conferir o que será escrito
node gerar-modelos.js --provider openai --key sk-xxx --dry-run

# 2. Fechar o Antigravity
tasklist | grep -icE "antigravity"    # precisa dar 0

# 3. Aplicar preservando o que já existe
node gerar-modelos.js --provider openai --key sk-xxx --merge

# 4. Reabrir o Antigravity — ele cifra as chaves e aloca identidade no primeiro boot
```

---

## 4. O catálogo: como estender

`provider-catalog.json` é um objeto por provedor:

```json
{
  "openai": {
    "label": "OpenAI",
    "apiUrl": "https://api.openai.com/v1/chat/completions",
    "provider": "openai",
    "apiFormat": "openai",
    "keyEnvHint": "OPENAI_API_KEY",
    "context": 400000,
    "maxOutput": 128000,
    "effortSupported": ["minimal", "low", "medium", "high"],
    "effortRejected": [],
    "defaultEffort": "medium",
    "effortPerModel": {
      "gpt-6.1-terra": ["low", "medium", "high", "xhigh"]
    },
    "models": [
      ["gpt-6.1-terra", "GPT-6.1 Terra", "medium"],
      ["gpt-4o", "GPT-4o", "medium"]
    ],
    "slugs": {
      "gpt-6.1-terra": "gpt-6.1-terra"
    },
    "verified": false
  }
}
```

### Campos

| Campo | Regra |
|---|---|
| `provider` | Deve existir em `PROVIDERS` do complemento: `openai`, `anthropic`, `google`, `deepseek`, `openrouter`, `groq`, `xai`, `zai`, `kimi`, `mistral`, `ollama`, `lmstudio`, `custom`… |
| `apiFormat` | `openai` \| `anthropic` \| `google`. **Errar aqui dá falha silenciosa** — a resposta volta num formato que o app não entende. |
| `apiUrl` | URL **completa** do endpoint (`/chat/completions` ou `/v1/messages`), sem credenciais embutidas |
| `context` / `maxOutput` | `maxOutput` precisa ser **menor** que `context` |
| `effortSupported` | Escala do **provedor** |
| `effortPerModel` | Escala de **cada modelo**, quando difere. Vence a do provedor. |
| `effortRejected` | Só níveis que o provedor **inteiro** recusa (ex.: Groq graduado) |
| `models` | `[id, label, effort]` — o `effort` aqui é o desejado; o script corrige se a escala não aceitar |
| `slugs` | Nome interno na primeira gravação. **Depois de gravado, o `name` nunca muda.** |
| `verified` | `true` só se você testou geração neste provedor |

### Regra de precedência do `reasoningEffort`

```
--effort  >  models[][2]  >  defaultEffort
                     ↓ corrigido contra
       effortPerModel[modelo]  >  effortSupported
```

Se o nível resolvido não está na escala aceita, o script troca pelo mais próximo e **avisa**:

```
aviso: 'grok-4.7' receberia effort='none', que nao esta na escala aceita
[low/medium/high]. Usando 'low'.
```

---

## 5. Provedores no catálogo

| Chave | provider | apiFormat | Endpoint | Scale de effort |
|---|---|---|---|---|
| `openai` | `openai` | openai | `api.openai.com/v1/chat/completions` | `minimal` `low` `medium` `high` |
| `anthropic` | `anthropic` | **anthropic** | `api.anthropic.com/v1/messages` | `low` `medium` `high` |
| `deepseek` | `deepseek` | openai | `api.deepseek.com/v1/chat/completions` | `none` `low` `medium` `high` |
| `xai` | `xai` | openai | `api.x.ai/v1/chat/completions` | `low` `medium` `high` |
| `groq` | `groq` | openai | `api.groq.com/openai/v1/chat/completions` | **só `none`** |
| `ollama` | `ollama` | openai | `localhost:11434/v1/chat/completions` | — (local, sem reasoning) |

### Escalas de effort por provedor

| Provedor | Aceita | Rejeita |
|---|---|---|
| OpenAI | `minimal` `low` `medium` `high` (`xhigh` na linha o-series) | — |
| Anthropic | `low` `medium` `high` | `none` |
| DeepSeek | `none` `low` `medium` `high` | — |
| xAI | `low` `medium` `high` | `none` |
| Groq | **só `none`** | `low` `medium` `high` → HTTP 400 |
| Ollama | — | não envia o campo |

> Groq: a regra "só `none`/`default`" vem do código-fonte do Hermes (`providers/base.py`), que
> documenta o 400 em níveis graduados. **Não testada diretamente aqui.**

---

## 6. Evidência de execução

Saídas reais do gerador, não exemplos escritos à mão.

### OpenAI — 3 modelos

```
$ node gerar-modelos.js --provider openai --key sk-*** --dry-run
{
  "models": [
    {
      "name": "models/openai-gpt-6.1-terra",
      "displayName": "GPT-6.1 Terra (OpenAI)",
      "provider": "openai",
      "apiFormat": "openai",
      "apiUrl": "https://api.openai.com/v1/chat/completions",
      "externalModelName": "gpt-6.1-terra",
      "contextWindow": 400000,
      "maxOutputTokens": 128000,
      "apiKey": "sk-***",
      "reasoningEffort": "medium",
      "supportsThinking": true
    }, ...
  ]
}
--dry-run: 3 modelos, nada escrito.
```

### Anthropic — `apiFormat` nativo

```
$ node gerar-modelos.js --provider anthropic --key sk-ant-*** --models claude-sonnet-5.5 --dry-run
{
  "name": "models/anthropic-sonnet-5.5",
  "displayName": "claude-sonnet-5.5 (Anthropic)",
  "provider": "anthropic",
  "apiFormat": "anthropic",
  "apiUrl": "https://api.anthropic.com/v1/messages",
  "externalModelName": "claude-sonnet-5.5",
  "contextWindow": 200000,
  "maxOutputTokens": 64000,
  "reasoningEffort": "medium"
}
```

### Groq — força `none`

```
$ node gerar-modelos.js --provider groq --key gsk-*** --dry-run
"provider": "groq",
"apiUrl": "https://api.groq.com/openai/v1/chat/completions",
"externalModelName": "openai/gpt-oss-120b",
"reasoningEffort": "none"
```

### Ollama — sem chave, sem effort

```
$ node gerar-modelos.js --provider ollama --models "llama3.3,qwen3.5" --dry-run
{
  "name": "models/ollama-llama3.3",
  "provider": "ollama",
  "apiUrl": "http://localhost:11434/v1/chat/completions",
  "externalModelName": "llama3.3"
}
```

Sem `apiKey`, sem `reasoningEffort` — local não precisa de nenhum dos dois.

### Correção de effort inválido

```
$ node gerar-modelos.js --provider xai --key xai-*** --effort none \
    --models "grok-4.7" --dry-run
aviso: 'grok-4.7' receberia effort='none', que nao esta na escala aceita
[low/medium/high]. Usando 'low'.
```

### Provedor inexistente

```
$ node gerar-modelos.js --provider naoexiste --dry-run
erro: provedor 'naoexiste' nao esta no catalogo.
disponiveis: openai, anthropic, deepseek, xai, groq, ollama
exit=2
```

### Guard de processo

```
$ node gerar-modelos.js --provider openai --key sk-*** --merge
ERRO: Antigravity esta aberto. Feche-o — ele sobrescreve este arquivo na saida.
exit=3
```

### Suíte de testes

| Caso | Resultado |
|---|---|
| Merge idempotente (2 execuções seguidas) | nomes preservados, sem duplicata |
| Merge com provedor diferente | 6 → 9 modelos, nenhum do 1º provedor alterado |
| Sem `--merge` | substitui a lista |
| `--out` em arquivo novo | cria corretamente |
| Correção de effort fora da escala | troca e avisa |
| Provedor inválido → exit 2 | OK |
| Guard: app aberto → exit 3 | OK (bloqueou corretamente) |

---

## 7. O que NÃO está verificado

Sendo explícito, porque uma tabela de compatibilidade que parece testada sem ser é pior que
nenhuma:

- O **mecanismo** foi exercitado ponta a ponta com um provedor compatível com a API OpenAI:
  listagem de modelos, escala de effort por modelo, geração com tool calling e um ciclo completo
  de ferramentas do agente. Esse provedor não é destacado no kit — o que se documenta aqui é o
  mecanismo, idêntico para qualquer endpoint compatível.
- **OpenAI / Anthropic / DeepSeek / xAI / Groq** — endpoints, formatos, preços e limites vieram
  das documentações oficiais; **a geração não foi exercitada individualmente**.
- **Groq** — a regra de effort veio do código-fonte do Hermes, não de teste direto.
- **Ollama** — o endpoint e a ausência de chave são o padrão documentado; não executei um servidor
  local para confirmar.
- Recursos por-modelo do complemento (imagem, thinking budget, compaction) não foram tocados.

Todos os provedores do catálogo estão com `"verified": false` justamente por isso. Ao validar um,
marque-o `true` e registre a data.

---

## 8. Como verificar um provedor novo (procedimento)

Antes de marcar `verified: true`:

```bash
# 1. Listar os IDs reais do provedor
curl -s https://<endpoint>/v1/models -H "Authorization: Bearer $KEY" | python -m json.tool

# 2. Descobrir a escala de effort testando um por um (HTTP 400 = rejeitado)
for L in none minimal low medium high max; do
  printf '%-8s ' "$L"
  curl -s -o /dev/null -w '%{http_code}\n' https://<endpoint>/v1/chat/completions \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -d "{\"model\":\"<id>\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}],\"max_tokens\":64,\"reasoning_effort\":\"$L\"}"
done

# 3. Registrar no catalogo: effortPerModel por modelo, models[] com o effort escolhido

# 4. Gerar com --dry-run e conferir

# 5. Aplicar com o app fechado; reabrir e testar um chat
```

**Use `max_tokens` generoso (≥64) no teste.** Em modelo com reasoning, orçamento pequeno faz o
modelo gastar tudo pensando e devolver `content` **vazio** — sem erro, sem HTTP 400. Isso não é
falha do provedor e não deve virar um "rejeitado" na tabela.

Depois de validar, marque `verified: true` **naquele** modelo/provedor e registre a data.

---

## 9. Troubleshooting

| Sintoma | Causa | Ação |
|---|---|---|
| `erro: provedor 'X' nao esta no catalogo` | chave ausente no `provider-catalog.json` | adicione, ou use `--models` com um provedor existente |
| `ERRO: Antigravity esta aberto` (exit 3) | app rodando | feche; ele reescreve o arquivo na saída |
| Modelo não aparece no seletor | `name` mudou depois da primeira carga | mantenha o `slug`; se mudar, remova e readicione |
| HTTP 400 "Invalid inference request" na geração | `reasoningEffort` fora da escala | confira `effortPerModel`; em dúvida, `--effort none` |
| Resposta vazia, sem erro | `maxOutput` pequeno demais em modelo com reasoning | aumente no catálogo |
| Resposta em formato que o app não entende | `apiFormat` errado (ex.: `openai` num endpoint Anthropic) | corrija para `anthropic`/`google` |
| `Machine-encrypted keys cannot be imported` | chave veio como `enc:` | o gerador escreve texto puro; não edite o arquivo depois de cifrado |
| App em tela preta após update do Antigravity | update sobrescreveu o patch | `cd C:/antigravity-add-model && node scripts/deploy.mjs --restore` e reavalie |

---

## 10. Verificação de ponta a ponta

Cadeia completa confirmada, cada elo com evidência lida do sistema em execução:

| Elo | Evidência |
|---|---|
| Complemento injeta | `[Proxy] Intercepting fetchAvailableModels request` no `main.log` |
| Arquivo lido | `[Proxy] Plaintext custom_models.json detected. Migrating to encrypted format...` |
| Chaves cifradas | `custom_models.json` com `"encrypted": true`, `apiKey: "enc:…"` |
| Identidade alocada | `custom_model_identities.json` com uma identidade nativa por modelo |
| Geração funciona | modelos respondendo HTTP 200 com os efforts configurados |
| Agente fecha o loop | `hermes chat -q` no alias do provedor: executou `terminal` → `date +%A` → respondeu |

O elo que **só você** pode confirmar é o seletor de modelos na interface — o kit não dirige a GUI
nem faz login Google.

---

## Referências

- Complemento: <https://github.com/vahapogut/antigravity-add-model>
- OpenAI: <https://developers.openai.com/api/docs/pricing>
- Anthropic: <https://platform.claude.com/docs/en/about-claude/pricing>
- DeepSeek: <https://api-docs.deepseek.com/quick_start/pricing/>
- xAI: <https://docs.x.ai/developers/pricing>
- Groq: <https://console.groq.com/docs/models>

---

*Gerado em 26/10/2026. Versões, hashes, contagens e códigos HTTP lidos do sistema em execução;
preços das documentações oficiais na mesma data. Provedores marcados `verified: false` não tiveram
geração exercitada individualmente.*
