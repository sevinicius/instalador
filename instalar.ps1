# DelegaAí + Engrama — instalador para Windows (PowerShell 5.1 ou mais novo).
# Instala o que falta (Node.js, git, Claude Code), o Engrama (memória) e o DelegaAí, liga a memória e conecta as IAs.
# Pode rodar de novo: o que já está instalado é só atualizado; a memória existente nunca é apagada.
#
# Opções por variável de ambiente (antes de rodar):
#   DELEGAAI_INSTALADOR_URL   de onde baixar os pacotes (padrão: a última release de github.com/sevinicius/instalador)
#   DELEGAAI_SEM_AUTOSTART=1  não registra a memória para ligar sozinha no login
#   DELEGAAI_INSTALAR_IA=...  instala estas IAs (claude, codex, gemini, opencode; separadas por vírgula)
#   DELEGAAI_SEM_CLAUDE=1     sem nenhuma IA na máquina, não instala o Claude Code

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }

$Base = if ($env:DELEGAAI_INSTALADOR_URL) { $env:DELEGAAI_INSTALADOR_URL.TrimEnd('/') } else { 'https://github.com/sevinicius/instalador/releases/latest/download' }

function Passo([string]$t) { Write-Host ''; Write-Host "==> $t" -ForegroundColor Cyan }
function Ok([string]$t) { Write-Host "  ok  $t" -ForegroundColor Green }
function Aviso([string]$t) { Write-Host "  !   $t" -ForegroundColor Yellow }
function Falha([string]$t) { Write-Host ''; Write-Host "ERRO: $t" -ForegroundColor Red; exit 1 }
function Tem([string]$cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function AtualizarPath {
  $maq = [Environment]::GetEnvironmentVariable('Path', 'Machine')
  $usr = [Environment]::GetEnvironmentVariable('Path', 'User')
  $env:Path = "$maq;$usr;$env:Path"
}
function Rodar([string]$descricao, [scriptblock]$bloco) {
  & $bloco
  if ($LASTEXITCODE -ne 0) { Falha "$descricao (código $LASTEXITCODE)" }
}
function InstalarComWinget([string]$id, [string]$nome) {
  if (-not (Tem 'winget')) { Falha "$nome não está instalado e o winget não existe nesta máquina. Instale o $nome à mão e rode este instalador de novo." }
  Write-Host "  ... instalando $nome pelo winget"
  winget install --id $id -e --silent --accept-package-agreements --accept-source-agreements | Out-Host
  AtualizarPath
}

Write-Host ''
Write-Host 'DelegaAí + Engrama — instalação' -ForegroundColor White
Write-Host 'Você delega a tarefa; a IA planeja, testa, implementa, revisa e abre o PR. O Engrama é a memória do projeto.'

# 1. Node.js 20+
Passo 'Node.js 20 ou mais novo'
$versaoNode = $null
if (Tem 'node') { $versaoNode = (node -p "process.versions.node") 2>$null }
if (-not $versaoNode -or [int]($versaoNode.Split('.')[0]) -lt 20) {
  InstalarComWinget 'OpenJS.NodeJS.LTS' 'Node.js'
  if (-not (Tem 'node')) { Falha 'O Node.js foi instalado, mas ainda não aparece nesta janela. Feche o PowerShell, abra de novo e rode o instalador outra vez.' }
  $versaoNode = (node -p "process.versions.node")
}
Ok "Node.js $versaoNode"

# 2. git
Passo 'git'
if (-not (Tem 'git')) {
  InstalarComWinget 'Git.Git' 'git'
  if (-not (Tem 'git')) { Falha 'O git foi instalado, mas ainda não aparece nesta janela. Feche o PowerShell, abra de novo e rode o instalador outra vez.' }
}
Ok ((git --version) -join ' ')

# 3. A IA da pessoa (Claude Code, Codex, Gemini CLI, OpenCode ou Cursor)
Passo 'Sua IA (Claude Code, Codex, Gemini CLI, OpenCode ou Cursor)'
$pacotesIa = @{ claude = '@anthropic-ai/claude-code'; codex = '@openai/codex'; gemini = '@google/gemini-cli'; opencode = 'opencode-ai' }
if ($env:DELEGAAI_INSTALAR_IA) {
  foreach ($ia in ($env:DELEGAAI_INSTALAR_IA -split ',') | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ }) {
    if (-not $pacotesIa.ContainsKey($ia)) { Aviso "IA desconhecida em DELEGAAI_INSTALAR_IA: $ia (use claude, codex, gemini ou opencode)"; continue }
    if (Tem $ia) { Ok "$ia já instalado"; continue }
    $pkg = $pacotesIa[$ia]
    Rodar "instalação de $pkg" { npm i -g $pkg --no-audit --no-fund --loglevel=error | Out-Host }
    AtualizarPath
    Ok "$ia instalado (na primeira vez, abra e faça o login)"
  }
}
$achadas = @('claude', 'codex', 'gemini', 'opencode', 'cursor') | Where-Object { Tem $_ }
if (-not $achadas) {
  if ($env:DELEGAAI_SEM_CLAUDE -eq '1') {
    Aviso 'nenhuma IA encontrada; instale uma depois e rode "delegaai update" no projeto'
  } else {
    # nenhuma IA na máquina: o Claude Code é a que tem a integração mais completa
    Rodar 'instalação do Claude Code' { npm i -g @anthropic-ai/claude-code --no-audit --no-fund --loglevel=error | Out-Host }
    AtualizarPath
    Ok 'Claude Code instalado (na primeira vez, rode "claude" e faça o login)'
    $achadas = @('claude')
  }
}
if ($achadas) { Ok ("IAs nesta máquina: " + ($achadas -join ', ')) }

# 4. Pacotes
Passo 'Baixando o Engrama e o DelegaAí'
$tmp = Join-Path $env:TEMP ("delegaai-instalador-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
foreach ($p in @('engrama.tgz', 'delegaai.tgz')) {
  try { Invoke-WebRequest -UseBasicParsing -Uri "$Base/$p" -OutFile (Join-Path $tmp $p) }
  catch { Falha "não consegui baixar $Base/$p ($($_.Exception.Message))" }
}
Ok "pacotes em $tmp"

# 5. Engrama (memória)
Passo 'Engrama — memória do projeto'
$env:MENTE_SKIP_POSTINSTALL = '1'
Rodar 'instalação do Engrama' { npm i -g (Join-Path $tmp 'engrama.tgz') --no-audit --no-fund --loglevel=error | Out-Host }
Remove-Item Env:MENTE_SKIP_POSTINSTALL -ErrorAction SilentlyContinue
AtualizarPath
Rodar 'preparação do banco da memória' { engrama init --armazenamento=pglite --extensoes=esteira | Out-Host }
Rodar 'ligar a memória' { engrama daemons up | Out-Host }
if ($env:DELEGAAI_SEM_AUTOSTART -eq '1') {
  Aviso 'auto-start pulado (DELEGAAI_SEM_AUTOSTART=1): ligue com "engrama daemons up" quando precisar'
} else {
  engrama autostart install | Out-Host
  if ($LASTEXITCODE -ne 0) { Aviso 'não consegui registrar o auto-start; ligue a memória com "engrama daemons up" depois de reiniciar' }
}
# Claude Code recém-instalado só cria a pasta de config na 1ª execução; sem ela o "engrama connect" acha que não está
# instalado. Criar a pasta vazia é o mesmo que o Claude Code faz.
$pastasIa = @{
  claude = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' })
  codex = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' })
  gemini = (Join-Path $env:USERPROFILE '.gemini')
  opencode = (Join-Path (Join-Path $env:USERPROFILE '.config') 'opencode')
}
foreach ($ia in $pastasIa.Keys) {
  if ((Tem $ia) -and -not (Test-Path $pastasIa[$ia])) { New-Item -ItemType Directory -Force -Path $pastasIa[$ia] | Out-Null }
}
engrama connect | Out-Host
if ($LASTEXITCODE -ne 0) { Aviso 'não consegui conectar alguma IA; rode "engrama connect" depois' }
Ok 'memória no ar'

# 6. DelegaAí
Passo 'DelegaAí'
Rodar 'instalação do DelegaAí' { npm i -g (Join-Path $tmp 'delegaai.tgz') --no-audit --no-fund --loglevel=error | Out-Host }
AtualizarPath
Ok ("DelegaAí " + ((delegaai versao) -join ''))

# 7. Conferência
Passo 'Conferindo'
delegaai doctor | Out-Host
Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue

Write-Host ''
Write-Host 'Pronto. Para usar num projeto:' -ForegroundColor Green
Write-Host '  1. cd <pasta do seu projeto>        (um repositório git)'
Write-Host '  2. delegaai init'
Write-Host '  3. abra a sua IA nessa pasta e peça:  /delega <o que você quer>   (no Codex: $delega <o que você quer>)'
Write-Host ''
Write-Host 'Memória: painel em http://127.0.0.1:7474/painel  ·  ajuda: delegaai ajuda  ·  engrama help'
