#!/usr/bin/env bash
# DelegaAí + Engrama — instalador para macOS e Linux.
# Confere o que falta (Node.js 20+, git), instala o Claude Code, o Engrama (memória) e o DelegaAí, liga a memória e
# conecta as IAs. Pode rodar de novo: o que já está instalado é só atualizado; a memória existente nunca é apagada.
#
# Opções por variável de ambiente:
#   DELEGAAI_INSTALADOR_URL   de onde baixar os pacotes (padrão: a última release de github.com/sevinicius/instalador)
#   DELEGAAI_SEM_AUTOSTART=1  não registra a memória para ligar sozinha
#   DELEGAAI_INSTALAR_IA=...  instala estas IAs (claude, codex, gemini, opencode; separadas por vírgula)
#   DELEGAAI_SEM_CLAUDE=1     sem nenhuma IA na máquina, não instala o Claude Code
set -euo pipefail

BASE="${DELEGAAI_INSTALADOR_URL:-https://github.com/sevinicius/instalador/releases/latest/download}"
BASE="${BASE%/}"

passo() { printf '\n\033[36m==> %s\033[0m\n' "$1"; }
ok() { printf '  \033[32mok\033[0m  %s\n' "$1"; }
aviso() { printf '  \033[33m!\033[0m   %s\n' "$1"; }
falha() { printf '\n\033[31mERRO: %s\033[0m\n' "$1" >&2; exit 1; }
tem() { command -v "$1" >/dev/null 2>&1; }

printf '\nDelegaAí + Engrama — instalação\n'
printf 'Você delega a tarefa; a IA planeja, testa, implementa, revisa e abre o PR. O Engrama é a memória do projeto.\n'

passo 'Node.js 20 ou mais novo'
if ! tem node || [ "$(node -p 'process.versions.node.split(".")[0]')" -lt 20 ]; then
  falha 'preciso do Node.js 20 ou mais novo. Instale em https://nodejs.org (ou com nvm: nvm install --lts) e rode de novo.'
fi
ok "Node.js $(node -p 'process.versions.node')"

passo 'git'
tem git || falha 'preciso do git (macOS: xcode-select --install · Debian/Ubuntu: sudo apt install git) e rode de novo.'
ok "$(git --version)"

# npm global sem sudo: se a pasta global não é gravável, usa ~/.npm-global (e avisa para pôr no PATH)
NPM_PREFIXO="$(npm config get prefix)"
if [ ! -w "$NPM_PREFIXO/lib" ] && [ ! -w "$NPM_PREFIXO" ]; then
  NPM_PREFIXO="$HOME/.npm-global"
  mkdir -p "$NPM_PREFIXO"
  npm config set prefix "$NPM_PREFIXO"
  export PATH="$NPM_PREFIXO/bin:$PATH"
  aviso "pacotes globais do npm em $NPM_PREFIXO — acrescente  export PATH=\"$NPM_PREFIXO/bin:\$PATH\"  ao seu ~/.bashrc ou ~/.zshrc"
fi

passo 'Sua IA (Claude Code, Codex, Gemini CLI, OpenCode ou Cursor)'
pacote_da_ia() {
  case "$1" in
    claude) echo '@anthropic-ai/claude-code' ;;
    codex) echo '@openai/codex' ;;
    gemini) echo '@google/gemini-cli' ;;
    opencode) echo 'opencode-ai' ;;
    *) echo '' ;;
  esac
}
PEDIDAS="${DELEGAAI_INSTALAR_IA:-}"
for ia in $(printf '%s' "$PEDIDAS" | tr ',' ' '); do
  pkg="$(pacote_da_ia "$ia")"
  if [ -z "$pkg" ]; then aviso "IA desconhecida em DELEGAAI_INSTALAR_IA: $ia (use claude, codex, gemini ou opencode)"; continue; fi
  if tem "$ia"; then ok "$ia já instalado"; continue; fi
  npm i -g "$pkg" --no-audit --no-fund --loglevel=error || falha "não consegui instalar $pkg"
  ok "$ia instalado (na primeira vez, abra e faça o login)"
done
ACHADAS=''
for ia in claude codex gemini opencode cursor; do tem "$ia" && ACHADAS="$ACHADAS $ia"; done
if [ -z "$ACHADAS" ]; then
  if [ "${DELEGAAI_SEM_CLAUDE:-}" = "1" ]; then
    aviso 'nenhuma IA encontrada; instale uma depois e rode "delegaai update" no projeto'
  else
    # nenhuma IA na máquina: o Claude Code é a que tem a integração mais completa
    npm i -g @anthropic-ai/claude-code --no-audit --no-fund --loglevel=error || falha 'não consegui instalar o Claude Code'
    ok 'Claude Code instalado (na primeira vez, rode "claude" e faça o login)'
    ACHADAS=' claude'
  fi
fi
[ -n "$ACHADAS" ] && ok "IAs nesta máquina:$ACHADAS"

passo 'Baixando o Engrama e o DelegaAí'
TMP="$(mktemp -d "${TMPDIR:-/tmp}/delegaai-instalador.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
for p in engrama.tgz delegaai.tgz; do
  curl -fsSL "$BASE/$p" -o "$TMP/$p" || falha "não consegui baixar $BASE/$p"
done
ok "pacotes em $TMP"

passo 'Engrama — memória do projeto'
MENTE_SKIP_POSTINSTALL=1 npm i -g "$TMP/engrama.tgz" --no-audit --no-fund --loglevel=error || falha 'não consegui instalar o Engrama'
engrama init --armazenamento=pglite --extensoes=esteira || falha 'não consegui preparar o banco da memória'
engrama daemons up || falha 'não consegui ligar a memória'
if [ "${DELEGAAI_SEM_AUTOSTART:-}" = "1" ]; then
  aviso 'auto-start pulado (DELEGAAI_SEM_AUTOSTART=1): ligue com "engrama daemons up" quando precisar'
else
  engrama autostart install || aviso 'não consegui registrar o auto-start; ligue a memória com "engrama daemons up" depois de reiniciar'
fi
# IA recém-instalada só cria a pasta de config na 1ª execução; sem ela o "engrama connect" acha que não está
# instalada. Criar a pasta vazia é o mesmo que a IA faz.
if tem claude; then mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; fi
if tem codex; then mkdir -p "${CODEX_HOME:-$HOME/.codex}"; fi
if tem gemini; then mkdir -p "$HOME/.gemini"; fi
if tem opencode; then mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/opencode"; fi
engrama connect || aviso 'não consegui conectar alguma IA; rode "engrama connect" depois'
ok 'memória no ar'

passo 'DelegaAí'
npm i -g "$TMP/delegaai.tgz" --no-audit --no-fund --loglevel=error || falha 'não consegui instalar o DelegaAí'
ok "DelegaAí $(delegaai versao)"

passo 'Conferindo'
delegaai doctor || true

printf '\n\033[32mPronto. Para usar num projeto:\033[0m\n'
printf '  1. cd <pasta do seu projeto>        (um repositório git)\n'
printf '  2. delegaai init\n'
printf '  3. abra a sua IA nessa pasta e peça:  /delega <o que você quer>   (no Codex: $delega <o que você quer>)\n\n'
printf 'Memória: painel em http://127.0.0.1:7474/painel  ·  ajuda: delegaai ajuda  ·  engrama help\n'
