---
description: Configura o plugin — assinatura, preferências e conexão com a Vercel (roda uma vez)
---

Configure o ambiente do Prospector de Sites. Siga esta ordem:

## 1. Pasta de trabalho

Verifique se há uma pasta do usuário conectada. Se não houver, peça para conectar uma pasta (ex.: "Clientes") usando a ferramenta de solicitação de pasta — tudo (config, leads e sites criados) será salvo nela para persistir entre sessões.

## 2. Verificar config existente

Procure `prospector-config.json` na pasta conectada. Se existir, mostre um resumo (sem exibir a senha) e pergunte o que o usuário quer atualizar. Se não existir, colete os dados abaixo.

## 3. Dados do usuário (perguntar via AskUserQuestion / formulário)

Colete:

- **Assinatura da proposta**: nome completo, como quer se apresentar (ex.: "Designer de páginas de alta conversão") e WhatsApp/telefone de contato.
- **Nichos padrão de prospecção**: sugira nutricionistas, psicólogos, advogados e psiquiatras como ponto de partida, mas deixe o usuário editar livremente.
- **Cidade/região padrão**.
- **Leads qualificados por busca**: padrão 10.
- **Modo de envio da proposta**: padrão "criar rascunho no Gmail para revisão" (recomendado). Alternativa: enviar direto.

## 4. Conexão com a Vercel

Cada lead ganha um projeto PRÓPRIO na Vercel (criado automaticamente na primeira publicação). Pergunte se o usuário já tem conta na Vercel e se já tem o Node.js instalado na máquina.

- **Se ainda não tem**: explique brevemente o que ele precisa antes de publicar: (1) conta na Vercel — o plano gratuito (Hobby) é restrito a uso pessoal/não comercial pelos termos da Vercel (uso comercial pede o Pro; a decisão é dele — informe o risco de termos uma vez, sem insistir) e limita a 200 projetos, 100 deploys por dia; (2) Node.js (nodejs.org) e, no terminal, `npm i -g vercel`. Diga que, depois de resolver isso, ele deve voltar e rodar `/setup` de novo. Salve o config parcial e encerre.
- **Se já tem**: NÃO colete nenhum dado da Vercel pelo chat — e JAMAIS o token. Tudo vai num lugar só, a aba Configurações do dashboard:
  1. Instrua: abra o dashboard (`iniciar-dashboard.bat` na pasta conectada) → aba **Configurações** → seção **Conexão Vercel**.
  2. Lá ele preenche o **token** (criado em vercel.com/account/tokens), o escopo/time da Vercel (opcional — em branco para conta pessoal) e um prefixo para os nomes dos projetos (opcional, ex.: `jl-`; ajuda a evitar nomes já ocupados na Vercel). Clica em "Salvar conexão" → tudo vai do navegador direto pro `prospector-config.json` no computador dele, sem passar pelo chat.
  3. Peça para ele avisar quando salvar ("salvei") — aí você LÊ o config (verificando que o token está preenchido, sem nunca exibi-lo) e roda o teste de conexão.

  Nunca exiba, imprima ou registre o token em nenhuma saída. Se ele preferir, editar o `prospector-config.json` na mão também vale. Lembre que o `prospector-config.json` guarda o token: nunca deve ser enviado a um repositório.

## 5. Salvar e testar

Salve tudo em `prospector-config.json` na pasta conectada, neste formato:

```json
{
  "assinatura": { "nome": "", "apresentacao": "", "whatsapp": "" },
  "prospeccao": { "nichos": ["nutricionistas", "psicologos", "advogados", "psiquiatras"], "cidade": "", "leadsPorBusca": 10 },
  "envio": { "modo": "rascunho" },
  "vercel": { "escopo": "", "prefixo": "", "token": "" }
}
```

Se o token da Vercel foi informado, teste a conexão seguindo a skill `deploy-vercel`: publique uma página `teste.html` simples como `teste/index.html` (vira o projeto `[prefixo]teste`) e leia a URL em `publicacoes.txt` — ela deve abrir em https, sem tela de login da Vercel. Se o teste falhar, diagnostique (token, escopo, Vercel CLI instalada) antes de concluir. O projeto de teste pode ser apagado depois na Vercel.

## 6. Dashboard inicial

Siga a seção "Setup" da skill `dashboard-leads`: copie `dashboard-server.py` e `iniciar-dashboard.bat` para a raiz da pasta conectada, crie o banco `prospector.db` (schema da skill) e gere o `dashboard.html` do template. Explique ao usuário: duplo clique em `iniciar-dashboard.bat` abre o painel completo em http://localhost:8765 com edição/exclusão salvando no banco (requer Python no Windows; sem ele, o dashboard.html abre no modo leitura).

## 7B. Entregar o manual e os scripts

Copie da pasta do plugin para a pasta conectada (sobrescrevendo versões antigas): `manual.html` (manual do usuário) e os arquivos do publicador conforme o sistema do usuário (skill `deploy-vercel`, references) — Windows: `publicar-agora.ps1/.bat`, `publicador-oculto.vbs`, `instalar-publicador.bat` · Mac: `publicar-agora.command`, `instalar-publicador.command` — mais o iniciador do dashboard certo (`iniciar-dashboard.bat` ou `.command`). Peça UM duplo clique no instalador do publicador (registra o publicador automático no Windows — única vez na vida; o teste de conexão do item 5 pode usar esse fluxo). Antes do instalador, confirme que o Node.js e a Vercel CLI (`npm i -g vercel`) estão instalados: o publicador depende deles. Apresente o `manual.html` ao usuário com a frase: "Esse é o seu manual — guarda ele que responde 90% das dúvidas."

## 7. Encerrar

Confirme o que foi salvo e explique o ciclo (guiando SEMPRE o próximo passo ao fim de cada comando): `/prospectar` → `/redesenhar` → `/publicar` → `/proposta`, com `/editor` opcional para ajustes manuais e o `dashboard.html` como painel de controle de tudo.
