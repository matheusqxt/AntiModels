<#



.SYNOPSIS



  Gera o custom_models.json com um provedor externo (OpenAI, Anthropic, DeepSeek, Groq, xAI, Ollama, ...).



.DESCRIPTION



  Wrapper do gerar-modelos.js. Fecha o Antigravity se preciso, gera com --merge



  (preserva o que ja existe), mostra o resultado e manda reabrir o app.



.EXAMPLE



  .\APLICAR-MODELOS.ps1 -Provider openai -Key sk-xxx



  .\APLICAR-MODELOS.ps1 -Provider deepseek -Key sk-xxx -Models "deepseek-flash,deepseek-v4-pro"



  .\APLICAR-MODELOS.ps1 -Provider ollama -Models "llama3.3" -NoMerge



  .\APLICAR-MODELOS.ps1 -Provider anthropic -Key sk-ant-xxx -DryRun



#>



[CmdletBinding()]



param(



    [Parameter(Mandatory=$true)][string]$Provider,



    [string]$Key,



    [string]$Models,



    [string]$Effort,



    [switch]$NoMerge,



    [switch]$DryRun,



    [switch]$FecharApp



)



$ErrorActionPreference = 'Stop'



$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path



$JS   = Join-Path $ROOT 'gerar-modelos.js'



$CAT  = Join-Path $env:USERPROFILE '.gemini\antigravity\provider-catalog.json'



function Ok   ($m) { Write-Host "[+] $m" -ForegroundColor Green }



function Info ($m) { Write-Host "[*] $m" -ForegroundColor Cyan }



function Die  ($m) { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }



if (-not (Test-Path $JS))  { Die "gerar-modelos.js nao encontrado ao lado deste script." }



if (-not (Test-Path $CAT)) {



    Die "Catalogo nao encontrado: $CAT`nCopie o provider-catalog.json deste kit para la, ou rode INSTALAR-KIT.ps1."



}



$node = (Get-Command node -ErrorAction SilentlyContinue).Source



if (-not $node) { $node = Join-Path ${env:ProgramFiles} 'nodejs\node.exe' }



if (-not (Test-Path $node)) { Die "Node nao encontrado." }



# Fechar o app se pedido (o gerador ja recusa escrever com ele aberto)



if ($FecharApp) {



    $p = Get-Process -Name 'Antigravity','language_server' -ErrorAction SilentlyContinue



    if ($p) { Info "Fechando o Antigravity..."; $p | Stop-Process -Force; Start-Sleep -Seconds 2 }



}



$args = @($JS, '--provider', $Provider)



if ($Key)     { $args += @('--key', $Key) }



if ($Models)  { $args += @('--models', $Models) }



if ($Effort)  { $args += @('--effort', $Effort) }



if (-not $NoMerge) { $args += '--merge' }



if ($DryRun)  { $args += '--dry-run' }



Info ("node " + ($args -join ' ')).Replace($Key, '****')



& $node @args



$code = $LASTEXITCODE



switch ($code) {



    0 { if ($DryRun) { Ok "Previa acima. Rode sem -DryRun para aplicar." }



        else { Ok "Aplicado. Abra o Antigravity: ele cifra as chaves e aloca a identidade dos modelos." } }



    2 { Die "Provedor invalido ou sem modelos." }



    3 { Die "Antigravity esta aberto. Feche-o, ou rode com -FecharApp." }



    default { Die "Falha (exit $code)." }



}



