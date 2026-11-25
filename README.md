# Instalador do DelegaAí + Engrama

**DelegaAí**: você descreve a tarefa e a IA entrega pronta — plano, testes, código, revisão e PR aberto.
**Engrama**: a memória do projeto. Guarda as decisões de cada tarefa e entrega na próxima, para a IA não esquecer
o que já foi combinado.

Os dois rodam na sua máquina, com o [Claude Code](https://claude.com/claude-code).

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
2. Instala o **Claude Code**, se ainda não tiver.
3. Instala o **Engrama**, cria o banco da memória (embutido, sem Docker), liga e deixa ligando sozinho no login.
4. Conecta o Engrama às IAs que encontrar (Claude Code e outras).
5. Instala o **DelegaAí** e confere tudo (`delegaai doctor`).

Pode rodar de novo quando quiser: atualiza o que já está instalado e **nunca apaga a memória**.

## Depois de instalar

1. Na primeira vez, abra o terminal, rode `claude` e faça o login na sua conta.
2. Em cada projeto (uma pasta com git):
   ```bash
   cd minha-pasta-do-projeto
   delegaai init
   claude
   ```
3. Dentro do Claude Code, peça: `/delega adicionar filtro por status na lista de tarefas` (ou o que você quiser).

Comandos úteis: `delegaai doctor` (confere tudo), `delegaai ajuda`, `engrama daemons status` (a memória está ligada?),
painel da memória em <http://127.0.0.1:7474/painel>.

## Opções do instalador

Defina antes de rodar (PowerShell: `$env:NOME='1'`; bash: `NOME=1 bash`):

| Variável | Efeito |
|---|---|
| `DELEGAAI_SEM_AUTOSTART=1` | não liga a memória sozinha no login (ligue com `engrama daemons up`) |
| `DELEGAAI_SEM_CLAUDE=1` | não instala o Claude Code |

## Desinstalar

```bash
engrama disconnect      # tira o Engrama das IAs
engrama autostart uninstall
engrama daemons down
npm uninstall -g engrama @sevinicius/delegaai
```

A memória fica em `~/.ia-mente` (apague a pasta só se quiser perder tudo).

---

Software proprietário, distribuído para teste. Uso e redistribuição só com autorização do autor.
