---
description: Publica as páginas redesenhadas na Vercel e retorna as URLs públicas
argument-hint: "[nome do cliente ou todos]"
---

Publique páginas na Vercel seguindo a skill `deploy-vercel`.

## Passos

1. Leia `prospector-config.json`. Se os dados da Vercel não estiverem preenchidos, colete-os agora (nome do projeto, domínio público, escopo opcional — e oriente o usuário a preencher o token direto no dashboard/config, nunca no chat) — não prossiga sem eles.
2. Determine o que publicar: `$ARGUMENTS` (um cliente ou "todos"), ou liste as páginas com status `redesenhado` em `leads.md` e pergunte.
3. **Gere a página-capa de cada cliente**: preencha `references/capa-proposta-template.html` (skill `proposta-email`) com os dados do lead + assinatura do config e salve como `sites/[slug]/proposta.html`. É ela que vai no e-mail de proposta.
4. **Publique seguindo a skill `deploy-vercel`**, nesta ordem: se o sandbox tiver a Vercel CLI e rede, publique direto; senão use o publicador automático local — garanta os arquivos do publicador na pasta, monte a `fila-publicacao.txt` com página (`index.html`) e capa (`proposta.html`) de cada cliente e aguarde ~2 min: a tarefa agendada copia os arquivos para a pasta `vercel-site/` (que acumula TODOS os sites já publicados) e faz o deploy sozinha (confira a fila renomeada e o `publicador-log.txt`). Se a tarefa ainda não foi instalada, peça o duplo clique único no `instalar-publicador.bat`. Sem login, token só no config.
5. **Verificação HTTPS (bloqueante)**: abra cada URL com `https://` e confirme que carrega com cadeado válido **e sem tela de login da Vercel** (Deployment Protection). Se aparecer login ou erro de certificado/domínio, siga a seção "Verificação" da skill `deploy-vercel` antes de considerar publicado — link `http://` ou com tela de login NUNCA vai para cliente.
6. Atualize `leads.md` e o banco do dashboard: status `publicado` + URL pública nova.

## Saída

Liste, por cliente: URL da página nova e URL da capa (`.../proposta.html`), ambas testadas em https. Sugira o próximo passo: `/proposta` para enviar os e-mails.
