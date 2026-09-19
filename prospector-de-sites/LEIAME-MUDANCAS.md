# Prospector de Sites: publicação na Vercel (em vez da HostGator)

## Decisão de desenho

Um único projeto estático da Vercel, com cada cliente numa subpasta: `https://[dominio]/[pastaBase]/[slug]/`. É o mesmo padrão de URL da HostGator, então `/proposta`, `/contrato`, a checklist de e-mail e o dashboard continuam funcionando sem mudança de lógica. A pasta `vercel-site/` (na pasta conectada) acumula todos os sites já publicados, porque cada deploy da Vercel substitui o site inteiro. **Nunca apague essa pasta.**

## O que muda no fork

Os caminhos abaixo assumem `commands/` para os comandos e `skills/` para as skills. Se o seu fork usar outra organização, mantenha os nomes dos arquivos e ajuste as pastas.

| Arquivo no pacote | Ação no fork |
|---|---|
| `skills/deploy-vercel/` (SKILL.md + references/) | **Novo.** Substitui `skills/deploy-hostgator/`, que deve ser **apagada**. |
| `commands/setup.md` | Substitui. Passo 4 (conexão), JSON do config, teste e entrega dos scripts agora são da Vercel. |
| `commands/publicar.md` | Substitui. |
| `commands/proposta.md` | Substitui (só a referência à skill de deploy mudou). |
| `skills/proposta-email/SKILL.md` | Substitui (só o item "Domínio limpo e humano" mudou). |
| `skills/dashboard-leads/references/dashboard-server.py` | Substitui. A API agora usa o bloco `vercel` e nunca devolve o token. |
| `skills/dashboard-leads/references/dashboard-template.html` | Substitui. A seção "Conexão Vercel" tem os campos projeto, domínio, pasta base, escopo e token. |

Não mudam: `contrato-servico` (o texto de hospedagem já é genérico), `redesenhar`, `prospectar`, `respostas`, `followup`, `editor`.

## Depois de copiar

1. Rode `grep -ri hostgator .` na raiz do fork. Devem sobrar itens que eu não consegui ver: `manual.html`, README, e as descrições do `plugin.json` / `marketplace.json`. Ajuste o texto.
2. Aumente o campo `version` no `plugin.json` (se ele existir). Sem isso a atualização pode não chegar.
3. Faça commit e push, depois atualize o plugin (`/plugin marketplace update` no Claude Code, ou atualize/reinstale pelo Cowork).
4. Na pasta conectada: use o `prospector-config.json` novo (bloco `vercel` em vez de `hostgator`) e rode `/setup` de novo para copiar os scripts novos por cima dos antigos. A tarefa agendada `ProspectorPublicador` continua valendo (o caminho dos arquivos é o mesmo), mas rodar o `instalar-publicador` outra vez é inofensivo.
5. **Nunca versione o `prospector-config.json`**: ele guarda o token da Vercel.

## Pré-requisitos do usuário

- Conta na Vercel. O plano Hobby é restrito a uso pessoal/não comercial pelos termos deles; para prospecção e venda de sites o indicado é o Pro. Confirme termos e preços atuais.
- Node.js e `npm i -g vercel`.
- Um endereço limpo para os links: domínio próprio adicionado ao projeto (Settings → Domains) ou `[projeto].vercel.app`.
- Token criado em vercel.com/account/tokens, colado só na aba Configurações do dashboard.

## Primeiro teste

`/setup` → preencher a Conexão Vercel no dashboard → "salvei" → o teste publica `clientes/teste/index.html`. Abra a URL em janela anônima: tem que carregar em https, **sem tela de login da Vercel**. Se aparecer login, ajuste Deployment Protection no projeto.

## O que foi e o que não foi testado

Testado aqui:
- Publicador do Mac, com uma Vercel CLI simulada: cópia para `vercel-site`, acúmulo entre rodadas, falha de deploy (fila preservada), trava contra execução dupla, bloqueio de `..` no destino, mascaramento do token no log e ausência de log dentro da pasta publicada.
- `dashboard-server.py`: o token nunca sai pela API e em branco mantém o atual.
- Tela de configuração do dashboard, rodada em Node.

**Não testado:**
- `publicar-agora.ps1` no Windows (não havia PowerShell aqui). Foi revisado à mão, mas é o primeiro lugar para olhar se algo falhar.
- A Vercel CLI de verdade: os comandos usados são `vercel link --yes --project [projeto] --token ... [--scope ...]` e `vercel deploy --prod --yes --token ... [--scope ...]`. Confira se as flags batem com a versão instalada (`vercel --help`).
- A publicação real, o certificado do domínio e o comportamento de Deployment Protection na sua conta.

## Reverter

Como tudo está no fork, basta voltar o commit. A HostGator não foi apagada do histórico.
