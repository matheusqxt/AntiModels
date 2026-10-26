# AntiModal — Kit de Instalação de Modelos no Antigravity

Tudo que é preciso para habilitar **modelos externos** (OpenAI, Anthropic, DeepSeek, Groq,
xAI, Ollama e qualquer API compatível) no Antigravity desktop, sem depender do "Fetch provider models" da interface.

**Testado neste Windows em 26/10/2026.** Versões, tamanhos e códigos de retorno citados aqui
foram lidos do sistema em execução.

---

## Comece aqui

```powershell
cd AntiModal

# 1. Instalar o complemento (uma vez; ~2 min)
.\INSTALAR-COMPLEMENTO.ps1

# 2. Adicionar um provedor (feche o Antigravity antes, ou use -FecharApp)
.\APLICAR-MODELOS.ps1 -Provider openai -Key sk-sua_chave -FecharApp

# 3. Conferir o estado
.\VERIFICAR.ps1

# 4. ABRIR O ANTIGRAVITY. Ele cifra as chaves e aloca a identidade dos modelos.
#    Depois, no seletor de modelos do chat, escolha o modelo novo (ex. "GPT-4o (OpenAI)").

# Provedores prontos no catálogo: openai, anthropic, deepseek, xai, groq, ollama.
```

> **Ordem importa:** o app precisa ser aberto **uma vez** depois do passo 2. É no boot que ele
> lê o arquivo, cifra as chaves e registra os modelos. Antes disso, eles não existem para a UI.

---

## Conteúdo

| Arquivo | O que é |
|---|---|
| `INSTALAR-COMPLEMENTO.ps1` | Instala/atualiza/reverte o complemento `antigravity-add-model` |
| `APLICAR-MODELOS.ps1` | Gera o `custom_models.json` para um provedor |
| `VERIFICAR.ps1` | Diagnóstico: complemento, arquivos, identidades, log do proxy |
| `gerar-modelos.js` | O gerador (motor dos dois scripts acima) |
| `provider-catalog.json` | Catálogo: 7 provedores com endpoints e escalas de effort |
| `docs/MECANISMO.md` | Documentação técnica do mecanismo |

---

## Requisitos

| Item | Mínimo | Nota |
|---|---|---|
| Windows | 10 | |
| Node.js | **22.13+** | `winget install --id OpenJS.NodeJS.LTS` |
| Git | qualquer | o instalador usa `git clone` |
| Antigravity | 2.x standalone | o complemento valida o layout sozinho |

Se o Node estiver velho, `INSTALAR-COMPLEMENTO.ps1` para com mensagem clara — não tenta seguir.

---

## Uso detalhado

### `INSTALAR-COMPLEMENTO.ps1`

```powershell
.\INSTALAR-COMPLEMENTO.ps1              # instala ou atualiza
.\INSTALAR-COMPLEMENTO.ps1 -Force       # reaplica mesmo se já instalado
.\INSTALAR-COMPLEMENTO.ps1 -Restore     # reverte tudo
```

Faz: confere Node/git → clona ou atualiza em `C:\antigravity-add-model` → `npm ci` → `npm run build`
→ `node scripts/deploy.mjs --check` → fecha o app (com sua confirmação) → aplica.

**É fail-closed:** se o `--check` não reconhecer o layout do seu Antigravity, ele **aborta sem
alterar arquivo nenhum**. Você não termina com um app quebrado.

### `APLICAR-MODELOS.ps1`

```powershell
# OpenAI
.\APLICAR-MODELOS.ps1 -Provider openai -Key sk-xxx

# Anthropic (usa o formato nativo da API)
.\APLICAR-MODELOS.ps1 -Provider anthropic -Key sk-ant-xxx

# DeepSeek, só dois modelos
.\APLICAR-MODELOS.ps1 -Provider deepseek -Key sk-xxx -Models "deepseek-flash,deepseek-v4-pro"

# Ollama local — sem chave
.\APLICAR-MODELOS.ps1 -Provider ollama -Models "llama3.3,qwen3.5"

# Conferir antes de escrever
.\APLICAR-MODELOS.ps1 -Provider xai -Key xai-xxx -DryRun

# Forçar um nível de reasoning
.\APLICAR-MODELOS.ps1 -Provider xai -Key xai-xxx -Effort low

# Substituir tudo em vez de mesclar
.\APLICAR-MODELOS.ps1 -Provider groq -Key gsk-xxx -NoMerge
```

| Flag | Efeito |
|---|---|
| `-Provider` | Chave no catálogo. **Obrigatório.** |
| `-Key` | API key (ou use a env `<PROVIDER>_API_KEY`) |
| `-Models` | IDs separados por vírgula (default: todos do catálogo) |
| `-Effort` | Sobrescreve o `reasoningEffort` |
| `-NoMerge` | Substitui em vez de mesclar |
| `-DryRun` | Mostra o JSON, não escreve |
| `-FecharApp` | Fecha o Antigravity antes (ele bloqueia a escrita) |

**O padrão é `--merge`:** preserva os modelos que já existem e só adiciona/atualiza os do
provedor atual. Você pode acumular OpenAI + Anthropic + Groq + Ollama no mesmo Antigravity.

### `VERIFICAR.ps1`

```powershell
.\VERIFICAR.ps1
```

Reporta: processos rodando, estado do complemento, os três arquivos de configuração, cada modelo
com o status da chave (`cifrada` / `TEXTO PURO` / `sem chave`) e o effort, as identidades nativas
alocadas, e as últimas injeções no log do proxy. É o primeiro comando a rodar quando algo
não aparece na interface.

---

## Provedores no catálogo

| Chave | `-Provider` | apiFormat | Escala de effort |
|---|---|---|---|
| OpenAI | `openai` | openai | `minimal` `low` `medium` `high` |
| Anthropic | `anthropic` | **anthropic** | `low` `medium` `high` |
| DeepSeek | `deepseek` | openai | `none` `low` `medium` `high` |
| xAI (Grok) | `xai` | openai | `low` `medium` `high` |
| Groq | `groq` | openai | **só `none`** |
| Ollama (local) | `ollama` | openai | — (sem reasoning) |

O catálogo é o ponto de partida, não uma lista fechada — veja **Adicionar um provedor** abaixo.

### Escala de `reasoning_effort`

Esta é a pegadinha que mais quebra configuração: **cada provedor aceita uma escala diferente**, e
o erro é genérico (`Invalid inference request`), sem dizer qual campo está errado.

| Provedor | Aceita | Rejeita (HTTP 400) |
|---|---|---|
| DeepSeek | `none` `low` `medium` `high` | — |
| OpenAI | `minimal` `low` `medium` `high` | — |
| Anthropic | `low` `medium` `high` | `none` |
| xAI | `low` `medium` `high` | `none` |
| Groq | **só `none`** | `low` `medium` `high` |

O gerador corrige automaticamente e **avisa** quando o nível pedido não é aceito:

```
aviso: 'zai-org/GLM-5.3-Flash' receberia effort='medium', que nao esta na escala
aceita [low/high]. Usando 'high'.
```

---

## Adicionar um provedor que não está no catálogo

Edite `provider-catalog.json` (o mesmo arquivo em `~/.gemini/antigravity/`), adicionando uma chave:

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
  "effortRejected": [],
  "defaultEffort": "medium",
  "models": [
    ["modelo-grande", "Modelo Grande", "medium"],
    ["modelo-rapido", "Modelo Rápido", "low"]
  ],
  "slugs": { "modelo-grande": "meu-grande" },
  "verified": false
}
```

Depois: `.\APLICAR-MODELOS.ps1 -Provider meuprovedor -Key xxx`

`provider` precisa existir no complemento: `openai`, `anthropic`, `google`, `deepseek`,
`openrouter`, `groq`, `xai`, `zai`, `kimi`, `mistral`, `ollama`, `lmstudio`, `custom`…

### Descobrir a escala de effort de um provedor novo

```bash
for L in none minimal low medium high max; do
  printf '%-8s ' "$L"
  curl -s -o /dev/null -w '%{http_code}\n' https://api.exemplo.com/v1/chat/completions \
    -H "Authorization: Bearer $KEY" -H 'Content-Type: application/json' \
    -d "{\"model\":\"modelo\",\"messages\":[{\"role\":\"user\",\"content\":\"ok\"}],\"max_tokens\":64,\"reasoning_effort\":\"$L\"}"
done
```

`200` = aceito, `400` = rejeitado. Registre em `effortPerModel` se variar por modelo.

> **Use `max_tokens ≥ 64`.** Em modelo com reasoning, orçamento pequeno faz ele gastar tudo
> pensando e devolver `content` **vazio** — sem erro e sem HTTP 400. Um provedor perfeitamente
> funcional parece quebrado se você testar com `max_tokens: 8`.

---

## Como funciona (resumo)

1. O complemento injeta um proxy no Antigravity e intercepta `fetchAvailableModels`
   (visível no log: `[Proxy] Intercepting fetchAvailableModels request`).
2. Ele lê `~/.gemini/antigravity/custom_models.json` no boot, **cifra as chaves** com o DPAPI do
   Windows e **aloca uma identidade nativa** para cada modelo em `custom_model_identities.json`.
3. A partir daí os modelos aparecem no seletor do chat, junto dos built-in da Google.

Nada disso toca na sua conta Google nem nos modelos nativos.

---

## Regras que evitam dor de cabeça

1. **Feche o Antigravity para editar os arquivos.** Ele reescreve na saída e você perderia a
   alteração. O gerador recusa escrever com ele aberto (exit 3).
2. **Nunca edite `custom_models.json` depois que o app cifrou as chaves.** O campo `apiKey` vira
   `enc:...` e um import com valor cifrado é recusado. Use o gerador, que escreve texto puro e
   deixa o app cifrar.
3. **Não mude o campo `name` de um modelo já gravado.** É o identificador interno; mudar faz o app
   perder o vínculo com a identidade alocada. O gerador preserva o nome existente no `--merge`.
4. **Um provedor por vez, com `--merge`.** Assim você acumula sem perder o que já configurou.
5. **Após update do Antigravity**, o patch pode ser sobrescrito. Rode `.\VERIFICAR.ps1`; se o
   complemento sumiu, `.\INSTALAR-COMPLEMENTO.ps1` de novo.

---

## Problemas comuns

| Sintoma | Causa | Solução |
|---|---|---|
| `ANTIGRAVITY ABERTO` / exit 3 | app rodando | use `-FecharApp` ou feche manualmente |
| Modelos não aparecem no seletor | app não foi aberto depois de aplicar | abra o Antigravity uma vez |
| Aparecem os built-in (Gemini, Claude Opus) mas não os seus | normal — built-in são da Google | procure os seus pelo nome, ex. `(OpenAI)` ou `(Groq)` |
| `HTTP 400 Invalid inference request` ao conversar | `effort` fora da escala | `-Effort none`, ou ajuste no catálogo |
| Resposta vazia, sem erro | `max_output_tokens` pequeno em modelo com reasoning | aumente no catálogo (`maxOutput`) |
| `CHECK FALHOU` ao instalar | layout/versão do Antigravity não reconhecido | nada foi alterado; reporte a versão |
| Tela preta após update do Antigravity | update sobrescreveu o patch | `.\INSTALAR-COMPLEMENTO.ps1 -Restore` e reavalie |
| `Node e antigo` | versão < 22.13 | `winget install --id OpenJS.NodeJS.LTS` |

---

## Segurança e custo

- As chaves ficam em **texto puro** em `custom_models.json` até o app abrir pela primeira vez;
  depois são cifradas com o DPAPI (só decifram na sua conta de usuário do Windows).
- **Todo modelo adicionado consome tokens pagos** na sua conta do provedor. Ollama é a única
  opção sem custo por token.
- O complemento é de terceiros (`vahapogut/antigravity-add-model`, v2.0.1, commit `f793635`).
  Ele preserva o runtime do app e mantém backup com hashes para rollback verificável.

---

## Estado verificado nesta máquina

| Elo | Evidência |
|---|---|
| Complemento instalado | patch ativo, backup com hashes guardado para rollback |
| Proxy injeta | `[Proxy] Intercepting fetchAvailableModels request` no `main.log` |
| Arquivo lido pelo app | `[Proxy] Plaintext custom_models.json detected. Migrating to encrypted format...` |
| Chaves cifradas | modelos com `"encrypted": true` no `custom_models.json` |
| Identidades alocadas | `custom_model_identities.json` com uma identidade nativa por modelo |
| Merge idempotente | rodar 2x não cria duplicata e preserva o `name` de cada modelo |
| Merge por provedor | adicionar um 2º provedor preserva os modelos do 1º |

O único elo que depende de você é o **seletor de modelos na interface** — o kit não dirige a GUI
nem faz login Google.

### Verificado ponta a ponta

O mecanismo foi validado com **um provedor compatível com a API OpenAI**, do início ao fim:
listagem de modelos, escala de `reasoning_effort` por modelo, geração com tool calling e o
agente completando um ciclo real de ferramentas. Esse provedor não é destacado aqui de propósito —
o que este kit documenta é o **mecanismo**, que é o mesmo para qualquer endpoint compatível.

Os demais provedores do catálogo têm endpoints, formatos e escalas extraídos das documentações
oficiais, mas **a geração não foi exercitada individualmente**. Trate-os como ponto de partida:
rode o procedimento de descoberta de `effort` e teste um chat antes de confiar.

## Referências

- Complemento: <https://github.com/vahapogut/antigravity-add-model>
- DeepSeek: <https://api-docs.deepseek.com/quick_start/pricing/>
- OpenAI: <https://developers.openai.com/api/docs/pricing>
- Anthropic: <https://platform.claude.com/docs/en/about-claude/pricing>
- xAI: <https://docs.x.ai/developers/pricing>
- Groq: <https://console.groq.com/docs/models>
