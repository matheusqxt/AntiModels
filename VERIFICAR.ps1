<#
.SYNOPSIS
  Diagnostico do estado: complemento, arquivos, identidades e log do proxy.
#>
[CmdletBinding()]
param()

$H = $env:USERPROFILE
$AGY = Join-Path $H '.gemini\antigravity'
function Ok   ($m) { Write-Host "[+] $m" -ForegroundColor Green }
function Warn ($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Info ($m) { Write-Host "`n=== $m ===" -ForegroundColor Cyan }

Info "Processos"
$p = Get-Process -Name 'Antigravity','language_server' -ErrorAction SilentlyContinue
if ($p) { Warn "$($p.Count) processos rodando (feche para escrever arquivos)" } else { Ok "nenhum (ideal para editar)" }

Info "Complemento"
$state = Join-Path $env:LOCALAPPDATA 'Programs\antigravity\resources\.antigravity-model-patch\state.json'
if (Test-Path $state) {
    $s = Get-Content $state -Raw | ConvertFrom-Json
    Ok "patch aplicado na versao $($s.version)"
    Write-Host "    backup: $($s.backupId)"
} else { Warn "nao aplicado (rode INSTALAR-COMPLEMENTO.ps1)" }

Info "Arquivos do kit"
foreach ($f in 'provider-catalog.json','custom_models.json','custom_model_identities.json') {
    $fp = Join-Path $AGY $f
    if (Test-Path $fp) {
        $i = Get-Item $fp
        Ok "$f — $([math]::Round($i.Length/1KB,1)) KB, modificado $($i.LastWriteTime)"
    } else { Warn "$f ausente" }
}

Info "Modelos configurados"
$cm = Join-Path $AGY 'custom_models.json'
if (Test-Path $cm) {
    $d = Get-Content $cm -Raw | ConvertFrom-Json
    Write-Host "    $($d.models.Count) modelos:"
    foreach ($m in $d.models) {
        $enc = if ($m.apiKey -like 'enc:*') { 'cifrada' } elseif ($m.apiKey) { 'TEXTO PURO' } else { 'sem chave' }
        $eff = if ($m.reasoningEffort) { $m.reasoningEffort } else { '-' }
        Write-Host ("      {0,-52} {1,-12} effort={2}" -f $m.name, $enc, $eff)
    }
}

Info "Identidades nativas (prova de registro pelo app)"
$ci = Join-Path $AGY 'custom_model_identities.json'
if (Test-Path $ci) {
    $d = Get-Content $ci -Raw | ConvertFrom-Json
    $n = ($d.assignments.PSObject.Properties | Measure-Object).Count
    Ok "$n atribuicoes alocadas"
} else { Warn "ausente — o app ainda nao carregou os modelos" }

Info "Log do proxy (ultimas injecoes)"
$log = Join-Path $env:APPDATA 'Antigravity\logs\main.log'
if (Test-Path $log) {
    $hits = Select-String -Path $log -Pattern 'Intercepting fetchAvailableModels|Migrating to encrypted' |
            Select-Object -Last 6
    if ($hits) { $hits | ForEach-Object { Write-Host "    $($_.Line.Trim())" } }
    else { Warn "nenhuma injecao registrada ainda — abra o Antigravity uma vez" }
} else { Warn "log nao encontrado" }

Write-Host ""
