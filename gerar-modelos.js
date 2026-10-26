#!/usr/bin/env node
/**
 * gerar-modelos.js — gera o custom_models.json do Antigravity a partir do catalogo de provedores.
 *
 * Le o catalogo de provedores, combina com um arquivo de chaves (nao versionado)
 * e escreve o custom_models.json no formato que o complemento antigravity-add-model
 * valida. Nao depende de fetch de catalogo pela GUI.
 *
 * Uso:
 *   node gerar-modelos.js --provider openai --key sk-xxx
 *   node gerar-modelos.js --provider anthropic --key sk-ant-xxx --merge
 *   node gerar-modelos.js --provider groq --key gsk-xxx --models "openai/gpt-oss-20b"
 *   node gerar-modelos.js --provider ollama --models "llama3.3,qwen3.5" --merge
 *   node gerar-modelos.js --provider xai --key xai-xxx --dry-run
 *
 * Flags:
 *   --provider NAME   chave no provider-catalog.json (obrigatorio)
 *   --key VALUE       API key              (ou env <PROVIDER>_API_KEY)
 *   --models LIST     IDs separados por virgula (default: todos do catalogo)
 *   --effort LEVEL    sobrescreve o reasoningEffort de todos
 *   --merge           preserva modelos existentes; so adiciona/atualiza
 *   --out PATH        destino (default: ~/.gemini/antigravity/custom_models.json)
 *   --dry-run         imprime o JSON, nao escreve
 */
const fs = require('node:fs');
const path = require('node:path');
const os = require('node:os');

const HOME = os.homedir();
const AGY = path.join(HOME, '.gemini', 'antigravity');

function arg(name, dflt) {
  const i = process.argv.indexOf('--' + name);
  if (i < 0) return dflt;
  const v = process.argv[i + 1];
  return v && !v.startsWith('--') ? v : true;
}

const providerName = arg('provider');
if (!providerName || providerName === true) {
  console.error('erro: --provider e obrigatorio. Opcoes no provider-catalog.json.');
  process.exit(2);
}
const dryRun = !!arg('dry-run', false);
const merge = !!arg('merge', false);
const outPath = arg('out', path.join(AGY, 'custom_models.json'));
const effortOverride = arg('effort', null);
const modelsArg = arg('models', null);

const catalogPath = path.join(AGY, 'provider-catalog.json');
if (!fs.existsSync(catalogPath)) {
  console.error('erro: catalogo nao encontrado em ' + catalogPath);
  process.exit(2);
}
const catalog = JSON.parse(fs.readFileSync(catalogPath, 'utf8'));
const p = catalog[providerName];
if (!p) {
  console.error(`erro: provedor '${providerName}' nao esta no catalogo.`);
  console.error('disponiveis: ' + Object.keys(catalog).join(', '));
  process.exit(2);
}

// Chave: flag > variavel de ambiente > vazio (local nao precisa)
let key = arg('key', null);
if (!key || key === true) {
  key = p.keyEnvHint ? (process.env[p.keyEnvHint] || '') : '';
}
if (p.keyEnvHint && !key && p.provider !== 'ollama') {
  console.error(`aviso: nenhuma chave para '${providerName}'. Use --key ou exporte ${p.keyEnvHint}.`);
}

// Lista de modelos: se --models foi dado, usa; senao o catalogo do provedor
let models;
if (modelsArg && modelsArg !== true) {
  models = String(modelsArg).split(',').map((s) => s.trim()).filter(Boolean)
    .map((id) => ({ id, label: id }));
} else {
  if (!p.models || !p.models.length) {
    console.error(`erro: '${providerName}' nao tem modelos no catalogo. Use --models "id1,id2".`);
    process.exit(2);
  }
  models = p.models.map(([id, label, effort]) => ({ id, label, effort }));
}

// Slug estavel para o campo name (o complemento exige o prefixo models/).
// Usa a tabela 'slugs' do catalogo quando existir; senao deriva do ID preservando
// pontos decimais (v4.1 nao pode virar v4-1).
function slug(id) {
  if (p.slugs && p.slugs[id]) return p.slugs[id];
  return String(id)
    .split('/').pop()                       // descarta o vendor
    .toLowerCase()
    .replace(/[^a-z0-9.]+/g, '-')           // preserva o ponto
    .replace(/\.-/g, '.').replace(/-\./g, '.')
    .replace(/^[-.]+|[-.]+$/g, '');
}

// Corrige um effort que o modelo/provedor rejeita, avisando.
// Precedencia: escala POR MODELO (effortPerModel) > escala do PROVEDOR (effortSupported).
// effortRejected so cobre nivel que o provedor inteiro recusa.
function resolveEffort(m) {
  let e = effortOverride || m.effort || p.defaultEffort;
  if (!e) return e;

  const perModel = (p.effortPerModel || {})[m.id];
  const accepted = perModel || p.effortSupported;

  if (accepted && accepted.length && !accepted.includes(e)) {
    // escolhe o nivel mais proximo da escala declarada pelo modelo/provedor
    const fallback = m.effort && accepted.includes(m.effort) ? m.effort
                   : (accepted.includes(p.defaultEffort) ? p.defaultEffort : accepted[accepted.length - 1]);
    console.error(
      `aviso: '${m.id}' receberia effort='${e}', que nao esta na escala aceita ` +
      `[${accepted.join('/')}]. Usando '${fallback}'.`
    );
    e = fallback;
  }
  return e;
}

const entries = models.map((m) => {
  const entry = {
    name: `models/${providerName}-${slug(m.id)}`,
    displayName: `${m.label || m.id} (${p.label})`,
    description: `${p.label} — ${m.id}`,
    provider: p.provider,
    apiFormat: p.apiFormat,
    apiUrl: p.apiUrl,
    externalModelName: m.id,
    enabled: true,
    contextWindow: p.context,
    maxOutputTokens: p.maxOutput,
    timeout: 300000,
    maxRetries: 2,
  };
  if (key) entry.apiKey = key;
  const e = resolveEffort(m);
  if (e) { entry.reasoningEffort = e; entry.supportsThinking = true; }
  return entry;
});

// Merge: identifica um modelo pelo par (provider, externalModelName), NAO pelo `name`.
// O `name` e o identificador interno e pode ter sido gerado por uma versao anterior do
// catalogo (slug diferente); casar por ele DUPLICA o modelo em vez de atualizar, e a
// duplicata perde a identidade nativa ja alocada pelo app.
let finalModels = entries;
if (merge && fs.existsSync(outPath)) {
  let existing = [];
  try { existing = JSON.parse(fs.readFileSync(outPath, 'utf8')).models || []; } catch { existing = []; }
  const keyOf = (m) => `${m.provider || ''}::${m.externalModelName || m.name || ''}`.toLowerCase();
  const byKey = new Map(existing.map((m) => [keyOf(m), m]));
  let added = 0, updated = 0, renamed = 0;
  for (const e of entries) {
    const k = keyOf(e);
    const prev = byKey.get(k);
    if (prev) {
      updated++;
      // O `name` gravado e IMUTAVEL: e o identificador interno e o app ja alocou uma
      // identidade nativa para ele. `slugs` serve para ESCOLHER o nome na primeira
      // gravacao, nunca para reescrever um nome existente — renomear faz o app perder
      // o vinculo com a identidade alocada.
      if (prev.name) {
        if (prev.name !== e.name) renamed++;
        e.name = prev.name;
      }
      // Preserva a chave cifrada ja existente quando nenhuma foi fornecida agora
      if (!e.apiKey && prev.apiKey) e.apiKey = prev.apiKey;
    } else added++;
    byKey.set(k, e);
  }
  finalModels = [...byKey.values()];
  console.error(
    `merge: ${added} adicionados, ${updated} atualizados` +
    (renamed ? `, ${renamed} renomeados (name preservado do arquivo)` : '') +
    `, ${finalModels.length} no total`
  );
}

const payload = { models: finalModels };
const text = JSON.stringify(payload, null, 2) + '\n';

if (dryRun) {
  console.log(text);
  console.error(`--dry-run: ${finalModels.length} modelos, nada escrito.`);
  process.exit(0);
}

// O app reescreve o arquivo na saida — exige estar fechado
const { execSync } = require('node:child_process');
try {
  const out = execSync('tasklist', { encoding: 'utf8' });
  if (/Antigravity\.exe|language_server\.exe/i.test(out)) {
    console.error('ERRO: Antigravity esta aberto. Feche-o — ele sobrescreve este arquivo na saida.');
    process.exit(3);
  }
} catch { /* tasklist indisponivel (nao-Windows): segue */ }

fs.mkdirSync(path.dirname(outPath), { recursive: true });
if (fs.existsSync(outPath)) {
  const bak = `${outPath}.bak.${Date.now()}`;
  fs.copyFileSync(outPath, bak);
  console.error('backup: ' + bak);
}
fs.writeFileSync(outPath, text, 'utf8');
console.error(`escrito: ${outPath} (${finalModels.length} modelos, ${Buffer.byteLength(text)} bytes)`);
