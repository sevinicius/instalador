# Instalador do DelegaAí + Engrama

**DelegaAí**: você descreve a tarefa e a IA entrega pronta: plano, testes, código, revisão e PR aberto.
**Engrama**: a memória do projeto. Guarda as decisões de cada tarefa e entrega na próxima, para a IA não esquecer
o que já foi combinado.

Os dois rodam na sua máquina, com a IA que você já usa: **Claude Code, Codex, Gemini CLI, Cursor ou OpenCode**.

Este repositório tem só o instalador. O produto é distribuído para quem tem um **código de acesso** (começa com
`ENGA1`), enviado junto com a licença. Sem um código válido, o instalador não baixa nada e não muda nada na máquina.

## Instalar

### Windows

Baixe e dê **clique duplo** em
[`Instalar-DelegaAi.cmd`](https://github.com/sevinicius/instalador/releases/latest/download/Instalar-DelegaAi.cmd).

Ou abra o PowerShell (não precisa ser como administrador) e rode:

```powershell
irm https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.ps1 | iex
```

Quando ele pedir, cole o código de acesso e tecle Enter. O código não aparece na tela.

### macOS e Linux

Precisa do Node.js 20 ou mais novo (por exemplo, pelo [nvm](https://github.com/nvm-sh/nvm)) e do git. Depois:

```bash
curl -fsSL https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.sh | bash
```

## O que o instalador faz

1. Pede o código de acesso (sem mostrar na tela) e confere com o registro de pacotes se ele dá acesso. Até aqui
   nada na máquina muda.
2. Confere o Node.js 20 ou mais novo e o git. No Windows, se faltar, instala pelo `winget`.
3. Guarda a credencial de download num arquivo temporário, que é apagado no fim, com ou sem erro (o seu `.npmrc`
   não é tocado), e confere a licença.
4. Procura a sua IA (Claude Code, Codex, Gemini CLI, OpenCode, Cursor). Se não achar nenhuma, instala o Claude Code.
5. Para a Mente anterior, se houver, e remove do npm global o pacote antigo que fornece os mesmos comandos. Os seus
   dados, pastas e o Docker não são tocados.
6. Instala o Engrama e o DelegaAí, nas versões que esta edição do instalador fixa.
7. Traz as memórias da Mente anterior (quando ela é local), ativa a licença, cria o banco da memória (embutido, sem
   Docker), liga a memória, deixa ligando sozinha no login e conecta as suas IAs.
8. Coloca o DelegaAí dentro das suas IAs (`delegaai instalar`): skills, sub-agentes, travas e instruções sempre
   ativas, para **todos os projetos**. E confere tudo (`delegaai doctor`).

Pode rodar de novo quando quiser: atualiza o que já está instalado e **nunca apaga a memória**.

### Limite de tentativas

Se o código for recusado, o instalador pede de novo, esperando 2 segundos depois do primeiro erro e 10 segundos
depois do segundo. No terceiro código recusado seguido, ele fica bloqueado por 15 minutos. Confira se copiou o
código inteiro da mensagem que você recebeu.

## Depois de instalar

1. Na primeira vez, abra a sua IA e faça o login nela.
2. Abra a IA em qualquer projeto (uma pasta com git) e peça o que quer, **em linguagem normal**:

   > adiciona filtro por status na lista de tarefas
   >
   > o login quebra quando o e-mail tem letra maiúscula

   A IA segue a esteira sozinha: consulta a memória, planeja, escreve o teste antes do código, implementa, revisa e
   abre o PR. Atalhos, se quiser: `/delega <pedido>` e `/corrige <bug>` (no Codex: `$delega`, `$corrige`).

   Na primeira vez, o Codex pede para aprovar os hooks do DelegaAí (`/hooks`). No Cursor, deixe ligado *Include
   Third-Party Plugins, Skills, and Other Configs* (Settings).

Comandos úteis: `engrama atualizar` (atualiza), `delegaai doctor` (confere tudo), `delegaai ajuda`,
`engrama daemons status` (a memória está ligada?). Painel da memória: <http://127.0.0.1:7474/painel>.

## Opções do instalador

Defina antes de rodar (PowerShell: `$env:NOME='1'`; bash: `NOME=1 bash`):

| Variável | Efeito |
|---|---|
| `DELEGAAI_INSTALAR_IA=codex` | instala também estas IAs: `claude`, `codex`, `gemini`, `opencode` (separe por vírgula) |
| `DELEGAAI_SEM_AUTOSTART=1` | não liga a memória sozinha no login (ligue com `engrama daemons up`) |
| `DELEGAAI_SEM_CLAUDE=1` | se não houver nenhuma IA na máquina, não instala o Claude Code |

## Instalação silenciosa (scripts e ferramentas de implantação)

Para instalar à mão, use o comando normal acima: o código é pedido sem aparecer na tela e não fica guardado em lugar
nenhum. A variável `ENGRAMA_ACESSO` existe para scripts e ferramentas de implantação, que a recebem do cofre de
segredos delas.

**Nunca digite o código numa linha de comando**, nem para preencher a variável: o PowerShell guarda tudo o que você
digita no arquivo de histórico (`ConsoleHost_history.txt`, do PSReadLine) e o bash guarda em `~/.bash_history`, em
texto puro.

No bash, a variável pode ser preenchida sem eco e sem passar pelo histórico:

```bash
read -rs ENGRAMA_ACESSO; export ENGRAMA_ACESSO
curl -fsSL https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.sh | bash
unset ENGRAMA_ACESSO
```

No PowerShell, leia o código de um arquivo protegido (só o seu usuário tem acesso, por exemplo salvo pelo Bloco de
Notas na sua pasta) e apague o arquivo depois:

```powershell
$env:ENGRAMA_ACESSO = (Get-Content -Raw 'C:\caminho\protegido\acesso.txt').Trim()
irm https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.ps1 | iex
Remove-Item Env:ENGRAMA_ACESSO
```

Se o código já foi digitado num prompt, ele ficou no histórico. Para tirar de lá:

- PowerShell: abra o arquivo indicado por `(Get-PSReadLineOption).HistorySavePath`, apague a linha com o código e
  salve; depois rode `Clear-History`.
- bash: `history -c` limpa a sessão atual; depois apague a linha do arquivo `~/.bash_history`.

O código de acesso é pessoal: não o publique nem o cole em lugares compartilhados.

## Observações por IA

- **Gemini CLI:** o Google não aceita mais o login de conta pessoal no Gemini CLI. Use uma chave de API
  (`GEMINI_API_KEY`, em <https://aistudio.google.com/apikey>) ou uma conta Google Workspace/Code Assist.
- **OpenCode:** se a sua config global (`~/.config/opencode/opencode.jsonc`) tiver comentários, o `engrama connect`
  não mexe nela. Acrescente o Engrama à mão: `opencode mcp add engrama --global --url "http://127.0.0.1:7474/mcp?ia=opencode"`.
- **Cursor:** os comandos e as travas vêm pela pasta `.claude/` do projeto; a opção de configs de terceiros precisa
  estar ligada.

## Se algo der errado

Cada etapa mostra uma linha. Em caso de falha, o instalador diz o que falhou, se algo mudou e como retomar; na maioria
das vezes basta rodar o mesmo comando de novo. Se ele disser "acesso inválido ou credencial trocada", peça um código
novo.

Para ler o script antes de rodar (recomendado), abra o `install.ps1` ou o `install.sh` deste repositório. Para rodar
uma cópia baixada no Windows PowerShell 5.1, use `Get-Content -Raw -Encoding UTF8 .\install.ps1 | iex` (assim os
acentos das mensagens aparecem certos).

## Desinstalar

```bash
delegaai desinstalar    # tira o DelegaAí das IAs (skills, travas, instruções); o que você alterou fica
engrama disconnect      # tira o Engrama das IAs
engrama autostart uninstall
engrama daemons down
npm uninstall -g @sevinicius/engrama @sevinicius/delegaai
```

A memória fica em `~/.ia-mente` (apague a pasta só se quiser perder tudo).

---

Software proprietário. Uso e redistribuição só com autorização do autor.
