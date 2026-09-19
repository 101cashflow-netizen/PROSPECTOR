# Prospector de Sites - publicacao automatica na Vercel
# Manual: duplo clique no publicar-agora.bat (mostra janela)
# Automatico: instalado pelo instalar-publicador.bat, roda a cada minuto escondido (-Auto)
# Requer: Node.js + Vercel CLI (npm i -g vercel). Token e projeto ficam no prospector-config.json
param([switch]$Auto)
$ErrorActionPreference = "Stop"
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pasta
# o log usa caminho absoluto: durante o deploy o diretorio atual e vercel-site, que vai pro ar
function Fim($code){ if(-not $Auto){ pause }; exit $code }
function Log($msg,$cor="Gray"){
  if($Auto){ Add-Content (Join-Path $pasta "publicador-log.txt") ("[" + (Get-Date -Format "dd/MM HH:mm:ss") + "] " + $msg) }
  else { Write-Host $msg -ForegroundColor $cor }
}

function Publicar {
  try { $cfg = Get-Content "prospector-config.json" -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Log "ERRO: prospector-config.json nao encontrado/invalido." "Red"; $script:rc = 1; return }
  $token = $cfg.vercel.token; $projeto = $cfg.vercel.projeto; $escopo = $cfg.vercel.escopo
  if (-not $token -or -not $projeto) { Log "ERRO: preencha a conexao Vercel (dashboard > Configuracoes) incluindo o token." "Red"; $script:rc = 1; return }
  if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) { Log "ERRO: Vercel CLI nao encontrada. Instale o Node.js (nodejs.org) e rode no terminal: npm i -g vercel" "Red"; $script:rc = 1; return }

  # pasta acumulada: TODOS os sites ja publicados ficam aqui (cada deploy envia a pasta inteira)
  $site = Join-Path $pasta "vercel-site"
  New-Item -ItemType Directory -Force -Path $site | Out-Null

  $fila = Get-Content "fila-publicacao.txt" -Encoding UTF8 | Where-Object { $_ -match "\|" }
  $ok = 0; $falha = 0
  foreach ($linha in $fila) {
    $par = $linha -split "\|", 2
    $local = $par[0].Trim()
    $remoto = ($par[1].Trim() -replace "^public_html/", "").TrimStart([char[]]@([char]47, [char]92))
    if (($remoto -match "\.\.") -or [string]::IsNullOrWhiteSpace($remoto)) { Log ("PULOU (destino invalido): " + $remoto) "Yellow"; $falha++; continue }
    if (-not (Test-Path -LiteralPath $local)) { Log ("PULOU (nao existe): " + $local) "Yellow"; $falha++; continue }
    $dest = Join-Path $site $remoto
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
    Copy-Item -LiteralPath $local -Destination $dest -Force
    Log ("Preparado: " + $local + " -> " + $remoto)
    $ok++
  }
  if ($ok -eq 0) { Log "Nada para publicar: todas as linhas da fila falharam." "Red"; $script:rc = 1; return }

  $extra = @()
  if ($escopo) { $extra = @("--scope", $escopo) }
  $anterior = $ErrorActionPreference
  $ErrorActionPreference = "Continue"
  Push-Location $site
  try {
    if (-not (Test-Path ".vercel\project.json")) {
      Log ("Vinculando o projeto '" + $projeto + "' na Vercel ...")
      $saidaLink = [string](& vercel link --yes --project $projeto --token $token @extra 2>&1 | Out-String)
      if ($LASTEXITCODE -ne 0) { Log ("  aviso ao vincular: " + $saidaLink.Replace($token, "***").Trim()) "Yellow" }
    }
    Log "Publicando na Vercel (pode levar de 20s a 2 min) ..."
    $saida = [string](& vercel deploy --prod --yes --token $token @extra 2>&1 | Out-String)
    $codigo = $LASTEXITCODE
  } finally {
    Pop-Location
    $ErrorActionPreference = $anterior
  }
  $saida = $saida.Replace($token, "***").Trim()

  if ($codigo -eq 0) {
    Log ("Concluido: " + $ok + " arquivos enviados, " + $falha + " ignorados.") "Cyan"
    Log ("  Vercel: " + $saida) "Gray"
    if ($falha -eq 0) {
      Rename-Item "fila-publicacao.txt" ("fila-publicada-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt") -Force
      Log "Fila concluida. Avise o Claude ('publiquei') para verificar as URLs." "Cyan"
    } else {
      Log "Algumas linhas da fila foram ignoradas: a fila continua la para voce conferir." "Yellow"
    }
    $script:rc = 0
  } else {
    Log ("FALHOU o deploy (codigo " + $codigo + "): " + $saida) "Red"
    $script:rc = 1
  }
}

if (-not (Test-Path "fila-publicacao.txt")) { if(-not $Auto){ Log "Nada na fila - peca /publicar ao Claude primeiro." "Yellow" }; Fim 0 }

# trava: evita duas publicacoes ao mesmo tempo (o deploy pode demorar mais que 1 minuto)
if (Test-Path "publicador.lock") {
  $idade = ((Get-Date) - (Get-Item "publicador.lock").LastWriteTime).TotalMinutes
  if ($idade -lt 10) { if(-not $Auto){ Log "Ja existe uma publicacao em andamento. Aguarde." "Yellow" }; Fim 0 }
}
Set-Content "publicador.lock" (Get-Date -Format "s")
$script:rc = 0
try { Publicar } catch { Log ("ERRO: " + $_.Exception.Message) "Red"; $script:rc = 1 } finally { Remove-Item "publicador.lock" -Force -ErrorAction SilentlyContinue }
Fim $script:rc
