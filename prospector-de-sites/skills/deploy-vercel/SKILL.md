---
name: deploy-vercel
description: Esta skill deve ser usada ao publicar páginas na Vercel — publicador automático local (Vercel CLI), pasta acumulada vercel-site, verificação da URL pública, HTTPS e tela de login (Deployment Protection). Acione quando o usuário disser "publicar", "subir o site", "colocar no ar", "deploy", "vercel" ou rodar /publicar ou o teste de conexão do /setup.
---

# Deploy na Vercel

Todas as páginas ficam em UM único projeto estático da Vercel, em subpastas: `[pastaBase]/[slug]/`. A URL pública continua sendo `https://[dominio]/[pastaBase]/[slug]/` (e a capa em `.../proposta.html`) — o mesmo padrão de antes, então `/proposta`, a checklist de e-mail e o dashboard não mudam.

## Como a Vercel funciona aqui (leia antes de mexer)

Cada deploy **substitui o site inteiro** pelo conteúdo da pasta enviada. Por isso o publicador mantém uma pasta acumulada `vercel-site/` na pasta conectada: cada vez que a fila chega, ele COPIA os arquivos novos para dentro dela e só então envia a pasta toda. **Nunca apague nem esvazie a `vercel-site/`** — ela guarda todos os sites já publicados; apagar = derrubar as páginas antigas no próximo deploy.

## Credenciais

Tudo vem de `prospector-config.json` (bloco `vercel`): `projeto`, `dominio`, `pastaBase` (padrão `clientes`), `escopo` (opcional — slug do time/conta na Vercel) e `token`. **O token vive SÓ nesse arquivo, no computador do usuário — nunca é digitado no chat, nunca é exibido em nenhuma saída, log ou comando mostrado ao usuário, e o arquivo nunca vai para repositório.** Se o token estiver vazio, oriente: criar em vercel.com/account/tokens → dashboard → aba Configurações → Conexão Vercel → colar e salvar (ou editar o arquivo na mão). Nunca pelo chat.

## Pré-requisitos (uma vez)

1. **Conta na Vercel com plano adequado.** O plano gratuito (Hobby) é restrito a uso pessoal/não comercial pelos termos da Vercel; páginas para prospectar/vender serviços são uso comercial → plano Pro. Confirmar termos e preços atuais em vercel.com/pricing.
2. **Node.js + Vercel CLI** na máquina do usuário: instalar o Node.js (nodejs.org) e rodar `npm i -g vercel`.
3. **Endereço público limpo** (`dominio` do config): de preferência um domínio próprio adicionado ao projeto (Vercel → Project → Settings → Domains, apontando o DNS como a Vercel indicar); alternativa aceitável: o alias curto `[projeto].vercel.app`. Nunca use o endereço técnico de deploy (cheio de sufixos).
4. O projeto em si NÃO precisa ser criado à mão: o publicador vincula/cria `projeto` na primeira execução.

## Método 1 — Publicador automático local (RECOMENDADO: instala uma vez, nunca mais clica)

A rede do sandbox do Cowork costuma não alcançar a Vercel, e o deploy precisa da CLI instalada na máquina do usuário. A publicação roda na máquina dele via um publicador instalado no agendador: a cada minuto ele verifica a fila e, se houver, publica escondido, lendo as credenciais do config.

1. **Garanta os arquivos do publicador na pasta conectada** (copie de `references/` desta skill, sobrescrevendo versões antigas), conforme o sistema do usuário — pergunte ou detecte:
   - **Windows**: `publicar-agora.ps1`, `publicar-agora.bat`, `publicador-oculto.vbs`, `instalar-publicador.bat`.
   - **Mac**: `publicar-agora.command` e `instalar-publicador.command` (o instalador registra o publicador no launchd, a cada 60s; desinstalar = `launchctl unload` do plist com.prospector.publicador).
   Em dúvida, copie todos — cada sistema ignora os do outro.
2. **Primeira vez**: peça UM duplo clique no `instalar-publicador.bat` (Windows — cria a tarefa "ProspectorPublicador"; erro de permissão = botão direito → Executar como administrador) ou no `instalar-publicador.command` (Mac — se o macOS bloquear: botão direito → Abrir na primeira vez). Só uma vez na vida.
3. **Monte a fila**: escreva `fila-publicacao.txt` na raiz da pasta conectada, uma linha por arquivo: `caminho/local/arquivo.html|[pastaBase]/[slug]/index.html` (o destino é relativo à raiz do site — sem `public_html`). Inclua página (`index.html`) e capa (`proposta.html`) de cada cliente. Em até 1 minuto o publicador copia tudo para `vercel-site/`, faz o deploy e renomeia a fila para `fila-publicada-[data].txt` (o log fica em `publicador-log.txt`). Um arquivo `publicador.lock` evita duas publicações simultâneas.
4. **Aguarde ~2 min e verifique**: confira se a fila foi renomeada e teste as URLs (verificação abaixo). Sem tarefa instalada, o fallback manual é o duplo clique no `publicar-agora.bat` (Windows) ou `publicar-agora.command` (Mac).

## Método 2 — Direto do sandbox (tentar primeiro, silencioso, só se der)

Se o sandbox tiver `vercel` e rede (`command -v vercel` e acesso a api.vercel.com), faça o mesmo que o publicador: copie os arquivos para `vercel-site/` (mantendo o que já existe) e rode `vercel deploy --prod --yes --token [token do config, lido por script — jamais mostrado]` dentro dela (na primeira vez, `vercel link --yes --project [projeto]`). Se algo faltar ou a rede bloquear, caia SEM DRAMA para o Método 1 — não insista em tentativas repetidas.

## Verificação (obrigatória, após qualquer método)

1. Abra `https://[dominio]/[pastaBase]/[slug]/` e a capa `.../proposta.html` — confirme que carregam com o conteúdo certo.
2. **HTTPS obrigatório**: precisa carregar com cadeado válido. A Vercel emite o certificado sozinha; se der erro de certificado num domínio próprio, o DNS ainda não está apontado como a Vercel pede (Project → Settings → Domains mostra o que falta). Enquanto o HTTPS não valida, a publicação NÃO está concluída — link `http://` NUNCA vai para cliente.
3. **Sem tela de login**: abra a URL numa janela anônima. Se aparecer a tela de login da Vercel, o projeto está com Deployment Protection bloqueando o acesso público — ajuste em Project → Settings → Deployment Protection (ou use um domínio próprio de produção) e teste de novo. Link que pede login NUNCA vai para cliente.
4. Atualize `leads.md` + dashboard com status `publicado` e a URL.

## Teste de conexão do /setup

Publique `teste.html` simples ("Funcionou!") como `[pastaBase]/teste/index.html` pelo Método 2; se não der, deixe os scripts do Método 1 copiados na pasta, monte a fila com o teste e peça os 2 cliques — assim o usuário aprende o fluxo logo no setup. Na primeira execução, avise que o deploy pode levar de 20 segundos a 2 minutos.
