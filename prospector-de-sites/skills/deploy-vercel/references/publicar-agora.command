#!/bin/bash
# Prospector de Sites — publica a fila na Vercel: UM PROJETO POR LEAD (Mac).
# Manual: duplo clique. Automatico (launchd): chamado com --auto (log em publicador-log.txt, sem pause).
# Requer: Node.js + Vercel CLI (npm i -g vercel). Token/escopo/prefixo ficam no prospector-config.json
# Fila (fila-publicacao.txt): uma linha por arquivo -> caminho/local|[slug]/arquivo
# Resultado: publicacoes.txt -> [slug]|[url]|[OK ou VERIFICAR]|[data]
cd "$(dirname "$0")"
BASE="$(pwd)"
AUTO=0; [ "$1" = "--auto" ] && AUTO=1

# o launchd roda com PATH minimo: acrescenta os lugares comuns onde o npm instala a CLI
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:$HOME/.volta/bin:$PATH"
for d in "$HOME"/.nvm/versions/node/*/bin; do [ -d "$d" ] && PATH="$d:$PATH"; done
export PATH

# o log usa caminho absoluto: durante o deploy o diretorio atual e a pasta do lead, que vai pro ar
log(){ if [ $AUTO -eq 1 ]; then echo "[$(date '+%d/%m %H:%M:%S')] $1" >> "$BASE/publicador-log.txt"; else echo "$1"; fi; }
fim(){ [ $AUTO -eq 0 ] && read -p "Pressione Enter para fechar..."; exit $1; }

[ -f fila-publicacao.txt ] || { [ $AUTO -eq 0 ] && log "Nada na fila — peca /publicar ao Claude primeiro."; fim 0; }

# depois de um erro, o automatico espera 10 min (evita martelar a Vercel: o Hobby tem limite de deploys por dia)
if [ $AUTO -eq 1 ] && [ -f publicador-erro.flag ] && [ -n "$(find publicador-erro.flag -mmin -10 2>/dev/null)" ]; then exit 0; fi

# trava: evita duas publicacoes ao mesmo tempo
if [ -f publicador.lock ] && [ -n "$(find publicador.lock -mmin -10 2>/dev/null)" ]; then
  [ $AUTO -eq 0 ] && log "Ja existe uma publicacao em andamento. Aguarde."
  fim 0
fi
date > publicador.lock
TMP=$(mktemp -d)
trap 'rm -f "$BASE/publicador.lock"; rm -rf "$TMP"' EXIT

CFG=prospector-config.json
[ -f $CFG ] || { log "ERRO: prospector-config.json nao encontrado."; fim 1; }
cfg(){ python3 -c "import json;print(json.load(open('$CFG')).get('vercel',{}).get('$1',''))"; }
TOKEN=$(cfg token); ESCOPO=$(cfg escopo); PREFIXO=$(cfg prefixo)
[ -n "$TOKEN" ] || { log "ERRO: preencha o token da Vercel no dashboard (Configuracoes > Conexao Vercel)."; fim 1; }
command -v vercel >/dev/null 2>&1 || { log "ERRO: Vercel CLI nao encontrada. Instale o Node.js (nodejs.org) e rode no Terminal: npm i -g vercel"; touch publicador-erro.flag; fim 1; }
EXTRA=(); [ -n "$ESCOPO" ] && EXTRA=(--scope "$ESCOPO")

# nome do projeto na Vercel: prefixo + slug, minusculo, sem "---", ate 100 caracteres
nome_projeto(){ printf '%s' "$PREFIXO$1" | tr 'A-Z' 'a-z' | sed -E 's/[^a-z0-9._-]/-/g; s/-{3,}/-/g; s/^-+//; s/-+$//' | cut -c1-100; }

# endereco publico REAL (alias de producao) lido da API da Vercel. NUNCA usar a URL que o "vercel deploy" imprime:
# ela e a URL do deploy (com hash) e costuma pedir login. Se o alias curto "[nome].vercel.app" pertence ao projeto, ele aparece na resposta.
url_publica(){
  local api="https://api.vercel.com/v9/projects/$1"
  [ -n "$ESCOPO" ] && api="$api?slug=$ESCOPO"
  curl -s -m 30 -H "Authorization: Bearer $TOKEN" "$api" 2>/dev/null | python3 -c '
import sys, re
nome = sys.argv[1]
txt = sys.stdin.read()
hosts = set(re.findall(r"[a-z0-9][a-z0-9.-]*\.vercel\.app", txt))
if nome + ".vercel.app" in hosts:
    print("https://" + nome + ".vercel.app")
else:
    c = sorted([h for h in hosts if h.startswith(nome)], key=len)
    if c: print("https://" + c[0])
' "$1"
}
status_http(){ curl -s -o /dev/null -w '%{http_code}' -m 20 "$1" 2>/dev/null; }

# ---- le a fila: slug = primeiro trecho do destino (cada slug = um projeto)
: > "$TMP/itens"; : > "$TMP/pendentes"
while IFS='|' read -r LOCAL REMOTO || [ -n "$LOCAL" ]; do
  LOCAL=$(printf '%s' "$LOCAL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  REMOTO=$(printf '%s' "$REMOTO" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'); REMOTO="${REMOTO#/}"
  [ -z "$LOCAL" ] && continue
  case "$REMOTO" in ""|*..*) log "IGNORADA (destino invalido): $REMOTO"; continue;; esac
  SLUG="${REMOTO%%/*}"; RESTO="${REMOTO#*/}"
  if [ "$SLUG" = "$REMOTO" ] || [ -z "$RESTO" ]; then log "IGNORADA (o destino precisa ser slug/arquivo): $REMOTO"; continue; fi
  SLUG=$(printf '%s' "$SLUG" | tr 'A-Z' 'a-z' | sed 's/[^a-z0-9-]/-/g')
  echo "$SLUG|$RESTO|$LOCAL" >> "$TMP/itens"
done < fila-publicacao.txt

# pasta persistente por lead: vercel-site/[slug]/ (guarda index.html e proposta.html entre publicacoes)
SITE="$BASE/vercel-site"; mkdir -p "$SITE"
PUBLICADOS=0; ERROS=0
for SLUG in $(cut -d'|' -f1 "$TMP/itens" | sort -u); do
  NOME=$(nome_projeto "$SLUG"); DIR="$SITE/$SLUG"; mkdir -p "$DIR"
  FALTOU=0; : > "$TMP/linhas-$SLUG"
  while IFS='|' read -r S RESTO LOCAL; do
    [ "$S" = "$SLUG" ] || continue
    echo "$LOCAL|$SLUG/$RESTO" >> "$TMP/linhas-$SLUG"
    if [ ! -f "$LOCAL" ]; then log "[$SLUG] PULOU (nao existe): $LOCAL"; FALTOU=1; continue; fi
    mkdir -p "$DIR/$(dirname "$RESTO")" && cp "$LOCAL" "$DIR/$RESTO" || FALTOU=1
  done < "$TMP/itens"
  if [ $FALTOU -eq 1 ]; then
    cat "$TMP/linhas-$SLUG" >> "$TMP/pendentes"; ERROS=$((ERROS+1)); log "[$SLUG] NAO publicado: faltam arquivos."; continue
  fi

  cd "$DIR" || { cat "$TMP/linhas-$SLUG" >> "$TMP/pendentes"; ERROS=$((ERROS+1)); continue; }
  if [ ! -f .vercel/project.json ]; then
    log "[$SLUG] criando/vinculando o projeto '$NOME' na Vercel ..."
    SAIDA=$(vercel link --yes --project "$NOME" --token "$TOKEN" "${EXTRA[@]}" 2>&1)
    if [ $? -ne 0 ]; then
      vercel project add "$NOME" --token "$TOKEN" "${EXTRA[@]}" >/dev/null 2>&1
      SAIDA=$(vercel link --yes --project "$NOME" --token "$TOKEN" "${EXTRA[@]}" 2>&1) || log "  aviso ao vincular: ${SAIDA//"$TOKEN"/***}"
    fi
  fi
  log "[$SLUG] publicando (20s a 2 min) ..."
  SAIDA=$(vercel deploy --prod --yes --token "$TOKEN" "${EXTRA[@]}" 2>&1); COD=$?
  cd "$BASE"
  SAIDA="${SAIDA//"$TOKEN"/***}"
  if [ $COD -ne 0 ]; then
    log "[$SLUG] FALHOU o deploy (codigo $COD): $SAIDA"; cat "$TMP/linhas-$SLUG" >> "$TMP/pendentes"; ERROS=$((ERROS+1)); continue
  fi

  URL=$(url_publica "$NOME"); ESTADO="OK"
  if [ -z "$URL" ]; then URL="https://$NOME.vercel.app"; ESTADO="VERIFICAR"; log "[$SLUG] nao consegui ler o endereco na API da Vercel; usei o provavel."; fi
  [ "$URL" = "https://$NOME.vercel.app" ] || ESTADO="VERIFICAR"
  HTTP=000
  for T in 1 2 3; do HTTP=$(status_http "$URL"); [ "$HTTP" = "200" ] && break; sleep 5; done
  [ "$HTTP" = "200" ] || ESTADO="VERIFICAR"
  echo "$SLUG|$URL|$ESTADO|$(date '+%Y-%m-%d %H:%M')" >> "$BASE/publicacoes.txt"
  log "[$SLUG] $URL (HTTP $HTTP, $ESTADO)"
  PUBLICADOS=$((PUBLICADOS+1))
done

# fila: arquiva a original; o que falhou volta como fila nova (so os itens pendentes)
mv fila-publicacao.txt "fila-publicada-$(date '+%Y%m%d-%H%M%S').txt"
sort -u "$TMP/pendentes" -o "$TMP/pendentes"
if [ -s "$TMP/pendentes" ]; then
  cp "$TMP/pendentes" fila-publicacao.txt; touch publicador-erro.flag
  log "Concluido com pendencias: $PUBLICADOS publicado(s), $ERROS com erro. O que falhou voltou para a fila (nova tentativa em 10 min)."
  fim 1
fi
rm -f publicador-erro.flag
log "Concluido: $PUBLICADOS lead(s) publicado(s). Veja publicacoes.txt e avise o Claude ('publiquei') para verificar."
fim 0
