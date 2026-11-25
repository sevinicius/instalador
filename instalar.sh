#!/usr/bin/env bash
# DelegaAí + Engrama — instalador para macOS e Linux.
# Confere o que falta (Node.js 20+, git), instala o Claude Code, o Engrama (memória) e o DelegaAí, liga a memória e
# conecta as IAs. Pode rodar de novo: o que já está instalado é só atualizado; a memória existente nunca é apagada.
#
# Opções por variável de ambiente:
#   DELEGAAI_INSTALADOR_URL   de onde baixar os pacotes (padrão: a última release de github.com/sevinicius/instalador)
#   DELEGAAI_SEM_AUTOSTART=1  não registra a memória para ligar sozinha
#   DELEGAAI_SEM_CLAUDE=1     não instala o Claude Code
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

passo 'Claude Code'
if [ "${DELEGAAI_SEM_CLAUDE:-}" = "1" ]; then
  aviso 'pulado (DELEGAAI_SEM_CLAUDE=1)'
elif tem claude; then
  ok "$(claude --version 2>/dev/null | head -1)"
else
  npm i -g @anthropic-ai/claude-code --no-audit --no-fund || falha 'não consegui instalar o Claude Code'
  ok 'Claude Code instalado (na primeira vez, rode "claude" e faça o login)'
fi

passo 'Baixando o Engrama e o DelegaAí'
TMP="$(mktemp -d "${TMPDIR:-/tmp}/delegaai-instalador.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
for p in engrama.tgz delegaai.tgz; do
  curl -fsSL "$BASE/$p" -o "$TMP/$p" || falha "não consegui baixar $BASE/$p"
done
ok "pacotes em $TMP"

passo 'Engrama — memória do projeto'
MENTE_SKIP_POSTINSTALL=1 npm i -g "$TMP/engrama.tgz" --no-audit --no-fund || falha 'não consegui instalar o Engrama'
engrama init --armazenamento=pglite --extensoes=esteira || falha 'não consegui preparar o banco da memória'
engrama daemons up || falha 'não consegui ligar a memória'
if [ "${DELEGAAI_SEM_AUTOSTART:-}" = "1" ]; then
  aviso 'auto-start pulado (DELEGAAI_SEM_AUTOSTART=1): ligue com "engrama daemons up" quando precisar'
else
  engrama autostart install || aviso 'não consegui registrar o auto-start; ligue a memória com "engrama daemons up" depois de reiniciar'
fi
# Claude Code recém-instalado só cria a pasta de config na 1ª execução; sem ela o "engrama connect" acha que não está
# instalado. Criar a pasta vazia é o mesmo que o Claude Code faz.
if tem claude; then mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; fi
engrama connect || aviso 'não consegui conectar alguma IA; rode "engrama connect" depois'
ok 'memória no ar'

passo 'DelegaAí'
npm i -g "$TMP/delegaai.tgz" --no-audit --no-fund || falha 'não consegui instalar o DelegaAí'
ok "DelegaAí $(delegaai versao)"

passo 'Conferindo'
delegaai doctor || true

printf '\n\033[32mPronto. Para usar num projeto:\033[0m\n'
printf '  1. cd <pasta do seu projeto>        (um repositório git)\n'
printf '  2. delegaai init\n'
printf '  3. abra o Claude Code nessa pasta (claude) e peça:  /delega <o que você quer>\n\n'
printf 'Memória: painel em http://127.0.0.1:7474/painel  ·  ajuda: delegaai ajuda  ·  engrama help\n'
