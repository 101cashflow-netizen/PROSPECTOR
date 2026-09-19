#!/bin/bash
# Prospector de Sites — publica a fila na Vercel (Mac).
# Manual: duplo clique. Automatico (launchd): chamado com --auto (log em publicador-log.txt, sem pause).
# Requer: Node.js + Vercel CLI (npm i -g vercel). Token e projeto ficam no prospector-config.json
cd "$(dirname "$0")"
BASE="$(pwd)"
AUTO=0; [ "$1" = "--auto" ] && AUTO=1

# o launchd roda com PATH minimo: acrescenta os lugares comuns onde o npm instala a CLI
export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.npm-global/bin:$HOME/.volta/bin:$PATH"
for d in "$HOME"/.nvm/versions/node/*/bin; do [ -d "$d" ] && PATH="$d:$PATH"; done
export PATH

# o log usa caminho absoluto: durante o deploy o diretorio atual e vercel-site, que vai pro ar
log(){ if [ $AUTO -eq 1 ]; then echo "[$(date '+%d/%m %H:%M:%S')] $1" >> "$BASE/publicador-log.txt"; else echo "$1"; fi; }
fim(){ [ $AUTO -eq 0 ] && read -p "Pressione Enter para fechar..."; exit $1; }

[ -f fila-publicacao.txt ] || { [ $AUTO -eq 0 ] && log "Nada na fila — peca /publicar ao Claude primeiro."; fim 0; }

# trava: evita duas publicacoes ao mesmo tempo (o deploy pode demorar mais que 1 minuto)
if [ -f publicador.lock ] && [ -n "$(find publicador.lock -mmin -10 2>/dev/null)" ]; then
  [ $AUTO -eq 0 ] && log "Ja existe uma publicacao em andamento. Aguarde."
  fim 0
fi
date > publicador.lock
trap 'rm -f "$BASE/publicador.lock"' EXIT

CFG=prospector-config.json
[ -f $CFG ] || { log "ERRO: prospector-config.json nao encontrado."; fim 1; }
cfg(){ python3 -c "import json;print(json.load(open('$CFG')).get('vercel',{}).get('$1',''))"; }
TOKEN=$(cfg token); PROJETO=$(cfg projeto); ESCOPO=$(cfg escopo)
[ -n "$TOKEN" ] && [ -n "$PROJETO" ] || { log "ERRO: preencha a conexao Vercel no dashboard (Configuracoes), incluindo o token."; fim 1; }
command -v vercel >/dev/null 2>&1 || { log "ERRO: Vercel CLI nao encontrada. Instale o Node.js (nodejs.org) e rode no Terminal: npm i -g vercel"; fim 1; }

# pasta acumulada: TODOS os sites ja publicados ficam aqui (cada deploy envia a pasta inteira)
SITE="$BASE/vercel-site"; mkdir -p "$SITE"
OK=0; FALHA=0
while IFS='|' read -r LOCAL REMOTO || [ -n "$LOCAL" ]; do
  LOCAL=$(printf '%s' "$LOCAL" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  REMOTO=$(printf '%s' "$REMOTO" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  REMOTO="${REMOTO#public_html/}"; REMOTO="${REMOTO#/}"
  [ -z "$LOCAL" ] && continue
  case "$REMOTO" in ""|*..*) log "PULOU (destino invalido): $REMOTO"; FALHA=$((FALHA+1)); continue;; esac
  if [ ! -f "$LOCAL" ]; then log "PULOU (nao existe): $LOCAL"; FALHA=$((FALHA+1)); continue; fi
  if mkdir -p "$SITE/$(dirname "$REMOTO")" && cp "$LOCAL" "$SITE/$REMOTO"; then
    log "Preparado: $LOCAL -> $REMOTO"; OK=$((OK+1))
  else
    log "FALHOU ao copiar: $LOCAL"; FALHA=$((FALHA+1))
  fi
done < fila-publicacao.txt
[ $OK -gt 0 ] || { log "Nada para publicar: todas as linhas da fila falharam."; fim 1; }

EXTRA=(); [ -n "$ESCOPO" ] && EXTRA=(--scope "$ESCOPO")
cd "$SITE" || { log "ERRO: nao consegui entrar em vercel-site."; fim 1; }
if [ ! -f .vercel/project.json ]; then
  log "Vinculando o projeto '$PROJETO' na Vercel ..."
  SAIDA=$(vercel link --yes --project "$PROJETO" --token "$TOKEN" "${EXTRA[@]}" 2>&1) || log "  aviso ao vincular: ${SAIDA//"$TOKEN"/***}"
fi
log "Publicando na Vercel (pode levar de 20s a 2 min) ..."
SAIDA=$(vercel deploy --prod --yes --token "$TOKEN" "${EXTRA[@]}" 2>&1); COD=$?
SAIDA="${SAIDA//"$TOKEN"/***}"
cd "$BASE"

if [ $COD -eq 0 ]; then
  log "Concluido: $OK arquivos enviados, $FALHA ignorados."
  log "  Vercel: $SAIDA"
  if [ $FALHA -eq 0 ]; then
    mv fila-publicacao.txt "fila-publicada-$(date '+%Y%m%d-%H%M%S').txt"
    log "Fila concluida. Avise o Claude ('publiquei') para verificar as URLs."
  else
    log "Algumas linhas da fila foram ignoradas: a fila continua la para voce conferir."
  fi
  fim 0
else
  log "FALHOU o deploy (codigo $COD): $SAIDA"
  fim 1
fi
