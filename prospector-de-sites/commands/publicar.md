---
description: Publica as páginas redesenhadas na Vercel (um projeto por lead) e retorna as URLs públicas
argument-hint: "[nome do cliente ou todos]"
---

Publique páginas na Vercel seguindo a skill `deploy-vercel`: cada lead vira um projeto próprio.

## Passos

1. Leia `prospector-config.json`. Se o token da Vercel não estiver preenchido, oriente o usuário a preenchê-lo direto no dashboard (Configurações → Conexão Vercel) — nunca pelo chat — e não prossiga sem ele.
2. Determine o que publicar: `$ARGUMENTS` (um cliente ou "todos"), ou liste as páginas com status `redesenhado` em `leads.md` e pergunte. Lembre o limite do Hobby (200 projetos, 100 deploys/dia) se o lote for grande.
3. **Gere a página-capa de cada cliente**: preencha `references/capa-proposta-template.html` (skill `proposta-email`) com os dados do lead + assinatura do config e salve como `sites/[slug]/proposta.html`. A capa carrega a página nova por caminho relativo e mostra o endereço real sozinha — não há URL para preencher.
4. **Publique seguindo a skill `deploy-vercel`**, nesta ordem: se o sandbox tiver a Vercel CLI e rede, publique direto; senão use o publicador automático local — garanta os arquivos do publicador na pasta, monte a `fila-publicacao.txt` com página e capa de cada lead (`sites/[slug]/index.html|[slug]/index.html` e `sites/[slug]/proposta.html|[slug]/proposta.html`) e aguarde 1–3 min: a tarefa agendada cria/vincula o projeto de cada lead, faz o deploy e grava o resultado em `publicacoes.txt` (confira também o `publicador-log.txt`). Se a tarefa ainda não foi instalada, peça o duplo clique único no `instalar-publicador.bat`. Sem login, token só no config.
5. **Verificação (bloqueante)**: para cada lead, leia `publicacoes.txt`. Só o estado `OK` está pronto; `VERIFICAR` segue a seção "Verificação" da skill `deploy-vercel` (endereço com sufixo, tela de login, HTTP diferente de 200). Abra a página e a capa em https, de preferência em janela anônima. Link `http://`, com tela de login ou com endereço técnico NUNCA vai para cliente.
6. Atualize `leads.md` e o banco do dashboard: status `publicado` + a URL de `publicacoes.txt` (a URL real, nunca a que o `vercel deploy` imprime).

## Saída

Liste, por cliente: URL da página nova e URL da capa (`.../proposta.html`), ambas testadas em https. Sugira o próximo passo: `/proposta` para enviar os e-mails.
