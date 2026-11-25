# Instalador do DelegaAí + Engrama

**DelegaAí**: você descreve a tarefa e a IA entrega pronta — plano, testes, código, revisão e PR aberto.
**Engrama**: a memória do projeto. Guarda as decisões de cada tarefa e entrega na próxima, para a IA não esquecer
o que já foi combinado.

Os dois rodam na sua máquina, com a IA que você já usa: **Claude Code, Codex, Gemini CLI, Cursor ou OpenCode**.

## Instalar

### Windows

Baixe e dê **clique duplo** em
[`Instalar-DelegaAi.cmd`](https://github.com/sevinicius/instalador/releases/latest/download/Instalar-DelegaAi.cmd).

Ou, no PowerShell:

```powershell
irm https://github.com/sevinicius/instalador/releases/latest/download/instalar.ps1 -OutFile $env:TEMP\instalar-delegaai.ps1; powershell -ExecutionPolicy Bypass -File $env:TEMP\instalar-delegaai.ps1
```

### macOS e Linux

```bash
curl -fsSL https://github.com/sevinicius/instalador/releases/latest/download/instalar.sh | bash
```

## O que o instalador faz

1. Confere o **Node.js 20+** e o **git** (no Windows, instala pelo `winget` se faltar).
2. Procura a sua IA (Claude Code, Codex, Gemini CLI, OpenCode, Cursor). Se não achar nenhuma, instala o Claude Code.
3. Instala o **Engrama**, cria o banco da memória (embutido, sem Docker), liga e deixa ligando sozinho no login.
4. Conecta o Engrama às IAs que encontrar.
5. Instala o **DelegaAí** e confere tudo (`delegaai doctor`).

Pode rodar de novo quando quiser: atualiza o que já está instalado e **nunca apaga a memória**.

## Depois de instalar

1. Na primeira vez, abra a sua IA e faça o login nela.
2. Em cada projeto (uma pasta com git):
   ```bash
   cd minha-pasta-do-projeto
   delegaai init
   ```
   O `init` prepara o projeto para todas as IAs instaladas na máquina (ou só as que você escolher:
   `delegaai init --ias codex,gemini`).
3. Abra a sua IA nessa pasta e peça:

   | IA | Como pedir |
   |---|---|
   | Claude Code, Gemini CLI, Cursor, OpenCode | `/delega adicionar filtro por status na lista de tarefas` |
   | Codex | `$delega adicionar filtro por status na lista de tarefas` |

   Na primeira vez, o Codex pede para marcar o projeto como confiável e aprovar os hooks do DelegaAí (`/hooks`), e
   o Gemini mostra os hooks novos do projeto: aceite os `delegaai-*`. No Cursor, deixe ligado *Include Third-Party
   Plugins, Skills, and Other Configs* (Settings).

Comandos úteis: `delegaai doctor` (confere tudo), `delegaai ajuda`, `engrama daemons status` (a memória está ligada?),
painel da memória em <http://127.0.0.1:7474/painel>.

## Opções do instalador

Defina antes de rodar (PowerShell: `$env:NOME='1'`; bash: `NOME=1 bash`):

| Variável | Efeito |
|---|---|
| `DELEGAAI_INSTALAR_IA=codex` | instala também estas IAs: `claude`, `codex`, `gemini`, `opencode` (separe por vírgula) |
| `DELEGAAI_SEM_AUTOSTART=1` | não liga a memória sozinha no login (ligue com `engrama daemons up`) |
| `DELEGAAI_SEM_CLAUDE=1` | se não houver nenhuma IA na máquina, não instala o Claude Code |

Exemplo (macOS/Linux, instalando junto o Codex):
`curl -fsSL https://github.com/sevinicius/instalador/releases/latest/download/instalar.sh | DELEGAAI_INSTALAR_IA=codex bash`

## Observações por IA

- **Gemini CLI:** o Google não aceita mais o login de conta pessoal no Gemini CLI. Use uma chave de API
  (`GEMINI_API_KEY`, em <https://aistudio.google.com/apikey>) ou uma conta Google Workspace/Code Assist.
- **OpenCode:** se a sua config global (`~/.config/opencode/opencode.jsonc`) tiver comentários, o `engrama connect`
  não mexe nela. Acrescente o Engrama à mão: `opencode mcp add engrama --global --url "http://127.0.0.1:7474/mcp?ia=opencode"`.
- **Cursor:** os comandos e as travas vêm pela pasta `.claude/` do projeto; a opção de configs de terceiros precisa
  estar ligada.

## Desinstalar

```bash
engrama disconnect      # tira o Engrama das IAs
engrama autostart uninstall
engrama daemons down
npm uninstall -g engrama @sevinicius/delegaai
# em cada projeto, para tirar os arquivos das outras IAs: delegaai update --ias claude
```

A memória fica em `~/.ia-mente` (apague a pasta só se quiser perder tudo).

---

Software proprietário, distribuído para teste. Uso e redistribuição só com autorização do autor.
