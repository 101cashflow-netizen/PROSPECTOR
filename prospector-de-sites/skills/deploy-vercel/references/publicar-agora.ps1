# Prospector de Sites - publicacao na Vercel: UM PROJETO POR LEAD (Windows)
# Manual: duplo clique no publicar-agora.bat (mostra janela)
# Automatico: instalado pelo instalar-publicador.bat, roda a cada minuto escondido (-Auto)
# Requer: Node.js + Vercel CLI (npm i -g vercel). Token/escopo/prefixo ficam no prospector-config.json
# Fila (fila-publicacao.txt): uma linha por arquivo -> caminho\local|slug/arquivo
# Resultado: publicacoes.txt -> slug|url|OK ou VERIFICAR|data
param([switch]$Auto)
$ErrorActionPreference = "Stop"
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
$pasta = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $pasta
function Fim($code){ if(-not $Auto){ pause }; exit $code }
# o log usa caminho absoluto: durante o deploy o diretorio atual e a pasta do lead, que vai pro ar
function Log($msg,$cor="Gray"){
  if($Auto){ Add-Content (Join-Path $pasta "publicador-log.txt") ("[" + (Get-Date -Format "dd/MM HH:mm:ss") + "] " + $msg) }
  else { Write-Host $msg -ForegroundColor $cor }
}

# nome do projeto na Vercel: prefixo + slug, minusculo, sem "---", ate 100 caracteres
function NomeProjeto($prefixo, $slug){
  $n = ($prefixo + $slug).ToLower() -replace "[^a-z0-9._-]", "-"
  $n = ($n -replace "-{3,}", "-").Trim("-")
  if ($n.Length -gt 100) { $n = $n.Substring(0, 100).Trim("-") }
  return $n
}

# endereco publico REAL (alias de producao) lido da API da Vercel. NUNCA usar a URL que o "vercel deploy" imprime:
# ela e a URL do deploy (com hash) e costuma pedir login. Se o alias curto "[nome].vercel.app" pertence ao projeto, ele aparece na resposta.
function UrlPublica($nome, $token, $escopo){
  try {
    $uri = "https://api.vercel.com/v9/projects/" + $nome
    if ($escopo) { $uri = $uri + "?slug=" + $escopo }
    $resp = Invoke-WebRequest -UseBasicParsing -Uri $uri -Headers @{ Authorization = ("Bearer " + $token) } -TimeoutSec 30
    $hosts = @([regex]::Matches($resp.Content, "[a-z0-9][a-z0-9.-]*\.vercel\.app") | ForEach-Object { $_.Value } | Sort-Object -Unique)
    if ($hosts -contains ($nome + ".vercel.app")) { return ("https://" + $nome + ".vercel.app") }
    $cand = @($hosts | Where-Object { $_.StartsWith($nome) } | Sort-Object Length)
    if ($cand.Count -gt 0) { return ("https://" + $cand[0]) }
  } catch { }
  return ""
}

function StatusHttp($url){
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 20 -MaximumRedirection 0 -ErrorAction Stop
    return [int]$r.StatusCode
  } catch {
    if ($_.Exception.Response) { return [int]$_.Exception.Response.StatusCode }
    return 0
  }
}

function Publicar {
  try { $cfg = Get-Content "prospector-config.json" -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Log "ERRO: prospector-config.json nao encontrado/invalido." "Red"; $script:rc = 1; return }
  $token = $cfg.vercel.token; $escopo = $cfg.vercel.escopo; $prefixo = $cfg.vercel.prefixo
  if (-not $token) { Log "ERRO: preencha o token da Vercel no dashboard (Configuracoes > Conexao Vercel)." "Red"; $script:rc = 1; return }
  if (-not (Get-Command vercel -ErrorAction SilentlyContinue)) {
    Log "ERRO: Vercel CLI nao encontrada. Instale o Node.js (nodejs.org) e rode no terminal: npm i -g vercel" "Red"
    Set-Content (Join-Path $pasta "publicador-erro.flag") (Get-Date -Format "s"); $script:rc = 1; return
  }
  $extra = @(); if ($escopo) { $extra = @("--scope", $escopo) }

  # ---- le a fila: slug = primeiro trecho do destino (cada slug = um projeto)
  $pendentes = New-Object System.Collections.ArrayList
  $itens = New-Object System.Collections.ArrayList
  $linhas = @(Get-Content "fila-publicacao.txt" -Encoding UTF8 | Where-Object { $_ -match "\|" })
  foreach ($linha in $linhas) {
    $par = $linha -split "\|", 2
    $local = $par[0].Trim()
    $remoto = $par[1].Trim().Replace("\", "/").TrimStart([char[]]@([char]47))
    if (($remoto -match "\.\.") -or (-not $remoto.Contains("/"))) { Log ("IGNORADA (o destino precisa ser slug/arquivo): " + $remoto) "Yellow"; continue }
    $slug = ($remoto.Split("/")[0]).ToLower() -replace "[^a-z0-9-]", "-"
    $resto = $remoto.Substring($remoto.IndexOf("/") + 1)
    if ([string]::IsNullOrWhiteSpace($resto)) { Log ("IGNORADA (destino sem arquivo): " + $remoto) "Yellow"; continue }
    [void]$itens.Add([pscustomobject]@{ Slug = $slug; Resto = $resto; Local = $local; Linha = ($local + "|" + $slug + "/" + $resto) })
  }

  # pasta persistente por lead: vercel-site\[slug]\ (guarda index.html e proposta.html entre publicacoes)
  $site = Join-Path $pasta "vercel-site"
  New-Item -ItemType Directory -Force -Path $site | Out-Null
  $publicados = 0; $erros = 0

  foreach ($grupo in @($itens | Group-Object Slug)) {
    $slug = $grupo.Name
    $nome = NomeProjeto $prefixo $slug
    $dir = Join-Path $site $slug
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $faltou = $false
    foreach ($it in $grupo.Group) {
      if (-not (Test-Path -LiteralPath $it.Local)) { Log ("[" + $slug + "] PULOU (nao existe): " + $it.Local) "Yellow"; $faltou = $true; continue }
      $dest = Join-Path $dir $it.Resto
      New-Item -ItemType Directory -Force -Path (Split-Path -Parent $dest) | Out-Null
      Copy-Item -LiteralPath $it.Local -Destination $dest -Force
    }
    if ($faltou) {
      foreach ($it in $grupo.Group) { [void]$pendentes.Add($it.Linha) }
      $erros++; Log ("[" + $slug + "] NAO publicado: faltam arquivos.") "Yellow"; continue
    }

    $anterior = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    Push-Location $dir
    try {
      if (-not (Test-Path ".vercel\project.json")) {
        Log ("[" + $slug + "] criando/vinculando o projeto '" + $nome + "' na Vercel ...")
        $sl = [string](& vercel link --yes --project $nome --token $token @extra 2>&1 | Out-String)
        if ($LASTEXITCODE -ne 0) {
          $pa = [string](& vercel project add $nome --token $token @extra 2>&1 | Out-String)
          $sl = [string](& vercel link --yes --project $nome --token $token @extra 2>&1 | Out-String)
          if ($LASTEXITCODE -ne 0) { Log ("  aviso ao vincular: " + $sl.Replace($token, "***").Trim()) "Yellow" }
        }
      }
      Log ("[" + $slug + "] publicando (20s a 2 min) ...")
      $saida = [string](& vercel deploy --prod --yes --token $token @extra 2>&1 | Out-String)
      $codigo = $LASTEXITCODE
    } finally {
      Pop-Location
      $ErrorActionPreference = $anterior
    }
    $saida = $saida.Replace($token, "***").Trim()
    if ($codigo -ne 0) {
      Log ("[" + $slug + "] FALHOU o deploy (codigo " + $codigo + "): " + $saida) "Red"
      foreach ($it in $grupo.Group) { [void]$pendentes.Add($it.Linha) }
      $erros++; continue
    }

    $url = UrlPublica $nome $token $escopo
    $estado = "OK"
    if (-not $url) { $url = "https://" + $nome + ".vercel.app"; $estado = "VERIFICAR"; Log ("[" + $slug + "] nao consegui ler o endereco na API da Vercel; usei o provavel.") "Yellow" }
    if ($url -ne ("https://" + $nome + ".vercel.app")) { $estado = "VERIFICAR" }
    $http = 0
    for ($t = 1; $t -le 3; $t++) { $http = StatusHttp $url; if ($http -eq 200) { break }; Start-Sleep -Seconds 5 }
    if ($http -ne 200) { $estado = "VERIFICAR" }
    Add-Content (Join-Path $pasta "publicacoes.txt") ($slug + "|" + $url + "|" + $estado + "|" + (Get-Date -Format "yyyy-MM-dd HH:mm"))
    Log ("[" + $slug + "] " + $url + " (HTTP " + $http + ", " + $estado + ")") "Cyan"
    $publicados++
  }

  # fila: arquiva a original; o que falhou volta como fila nova (so os itens pendentes)
  Rename-Item "fila-publicacao.txt" ("fila-publicada-" + (Get-Date -Format "yyyyMMdd-HHmmss") + ".txt") -Force
  if ($pendentes.Count -gt 0) {
    Set-Content "fila-publicacao.txt" @($pendentes | Sort-Object -Unique) -Encoding UTF8
    Set-Content (Join-Path $pasta "publicador-erro.flag") (Get-Date -Format "s")
    Log ("Concluido com pendencias: " + $publicados + " publicado(s), " + $erros + " com erro. O que falhou voltou para a fila (nova tentativa em 10 min).") "Yellow"
    $script:rc = 1
  } else {
    Remove-Item (Join-Path $pasta "publicador-erro.flag") -Force -ErrorAction SilentlyContinue
    Log ("Concluido: " + $publicados + " lead(s) publicado(s). Veja publicacoes.txt e avise o Claude ('publiquei') para verificar.") "Cyan"
    $script:rc = 0
  }
}

if (-not (Test-Path "fila-publicacao.txt")) { if(-not $Auto){ Log "Nada na fila - peca /publicar ao Claude primeiro." "Yellow" }; Fim 0 }

# depois de um erro, o automatico espera 10 min (evita martelar a Vercel: o Hobby tem limite de deploys por dia)
if ($Auto -and (Test-Path "publicador-erro.flag")) {
  if (((Get-Date) - (Get-Item "publicador-erro.flag").LastWriteTime).TotalMinutes -lt 10) { exit 0 }
}
# trava: evita duas publicacoes ao mesmo tempo
if (Test-Path "publicador.lock") {
  $idade = ((Get-Date) - (Get-Item "publicador.lock").LastWriteTime).TotalMinutes
  if ($idade -lt 10) { if(-not $Auto){ Log "Ja existe uma publicacao em andamento. Aguarde." "Yellow" }; Fim 0 }
}
Set-Content "publicador.lock" (Get-Date -Format "s")
$script:rc = 0
try { Publicar } catch { Log ("ERRO: " + $_.Exception.Message) "Red"; $script:rc = 1 } finally { Remove-Item "publicador.lock" -Force -ErrorAction SilentlyContinue }
Fim $script:rc
