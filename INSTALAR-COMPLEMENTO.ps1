<#

.SYNOPSIS

  Instala o complemento antigravity-add-model, que habilita modelos externos

  no Antigravity desktop.



.DESCRIPTION

  Faz o ciclo completo: confere prerequisitos, clona, builda, valida o layout

  do app com --check e aplica o patch. Aborta em qualquer erro (fail-closed).



.PARAMETER Force

  Reaplica o patch mesmo que ja esteja instalado para a versao atual.



.PARAMETER Restore

  Reverte o patch e sai.



.EXAMPLE

  .\INSTALAR-COMPLEMENTO.ps1

  .\INSTALAR-COMPLEMENTO.ps1 -Restore

#>

[CmdletBinding()]

param(

    [switch]$Force,

    [switch]$Restore

)



$ErrorActionPreference = 'Stop'



$REPO     = 'https://github.com/vahapogut/antigravity-add-model.git'

$WORKDIR  = 'C:\antigravity-add-model'

$AGY_DIR  = Join-Path $env:LOCALAPPDATA 'Programs\antigravity'

$AGY_EXE  = Join-Path $AGY_DIR 'Antigravity.exe'



function Info  ($m) { Write-Host "[*] $m" -ForegroundColor Cyan }

function Ok    ($m) { Write-Host "[+] $m" -ForegroundColor Green }

function Warn  ($m) { Write-Host "[!] $m" -ForegroundColor Yellow }

function Die   ($m) { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }



# ---------- estado do app ----------

function Get-AgyProcs {

    Get-Process -Name 'Antigravity','language_server' -ErrorAction SilentlyContinue

}

function Assert-AgyClosed {

    $p = Get-AgyProcs

    if ($p) {

        Warn "O Antigravity esta aberto ($($p.Count) processos). Feche-o (inclusive da bandeja) e rode de novo."

        $ans = Read-Host "Fechar agora? (s/N)"

        if ($ans -eq 's' -or $ans -eq 'S') {

            $p | Stop-Process -Force

            Start-Sleep -Seconds 2

            if (Get-AgyProcs) { Die "Nao consegui fechar tudo. Feche manualmente e tente de novo." }

            Ok "Fechado."

        } else {

            Die "Abortado: o app precisa estar fechado."

        }

    }

}



if (-not (Test-Path $AGY_EXE)) { Die "Antigravity nao encontrado em $AGY_EXE" }

Info "Antigravity: $AGY_EXE"



# ---------- restore ----------

if ($Restore) {

    Info "Revertendo o patch..."

    Assert-AgyClosed

    if (-not (Test-Path $WORKDIR)) { Die "Repo nao encontrado em $WORKDIR" }

    Push-Location $WORKDIR

    try { node scripts/deploy.mjs --restore } finally { Pop-Location }

    Ok "Patch revertido. Reabra o Antigravity."

    exit 0

}



# ---------- prerequisitos ----------

Info "Conferindo Node..."

$node = $null

foreach ($cand in @('node', (Join-Path ${env:ProgramFiles} 'nodejs\node.exe'))) {

    try { $node = & $cand -v 2>$null } catch { continue }

    if ($node) { $nodePath = $cand; break }

}

if (-not $node) {

    Die "Node nao encontrado. Instale: winget install --id OpenJS.NodeJS.LTS"

}

$maj = [int]($node.TrimStart('v').Split('.')[0])

if ($maj -lt 22) { Die "Node $node e antigo (precisa 22.13+). Atualize: winget install --id OpenJS.NodeJS.LTS" }

Ok "Node $node"



Info "Conferindo git..."

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Die "git nao encontrado no PATH." }

Ok "git ok"



# ---------- clone / update ----------

if (Test-Path $WORKDIR) {

    Info "Repo ja existe; atualizando..."

    Push-Location $WORKDIR

    try { git pull --ff-only } finally { Pop-Location }

} else {

    Info "Clonando em $WORKDIR ..."

    git clone --depth 1 $REPO $WORKDIR

}

Push-Location $WORKDIR

try {

    Info "Instalando dependencias (npm ci)..."

    npm ci --ignore-scripts

    if ($LASTEXITCODE -ne 0) { Die "npm ci falhou." }



    Info "Compilando (npm run build)..."

    npm run build

    if ($LASTEXITCODE -ne 0) { Die "build falhou." }



    Info "Validando layout do app (--check)..."

    node scripts/deploy.mjs --check

    if ($LASTEXITCODE -ne 0) {

        Die "CHECK FALHOU: este layout/versao nao e compativel. Nada foi alterado."

    }

    Ok "Check passou."



    if ($Force -or $true) {

        Assert-AgyClosed

        Info "Aplicando o patch..."

        node scripts/deploy.mjs

        if ($LASTEXITCODE -ne 0) { Die "deploy falhou." }

    }

} finally { Pop-Location }



Ok "Complemento instalado. Abra o Antigravity manualmente."

Info "Agora configure um provedor: .\APLICAR-MODELOS.ps1 -Provider openai -Key sk-..."

