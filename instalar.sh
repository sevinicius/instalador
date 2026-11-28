#!/usr/bin/env bash
# Instalador do DelegaAí + Engrama para macOS e Linux.
#
#   curl -fsSL https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.sh | bash
#
# Só instala com o código de acesso (ENGA1.…) gerado no portal de licenças: os pacotes ficam num registro PRIVADO
# (GitHub Packages) e a credencial que os baixa vem dentro do código. Este script não tem link de pacote nem
# credencial: lido ou editado, não serve para baixar nada sem um código válido.
#
# Instalação silenciosa: exporte ENGRAMA_ACESSO com o código de acesso antes de rodar.
# Opções: DELEGAAI_INSTALAR_IA=claude,codex,gemini,opencode instala essas IAs; DELEGAAI_SEM_CLAUDE=1 não instala o
#   Claude Code quando não há nenhuma IA; DELEGAAI_SEM_AUTOSTART=1 não registra a memória para ligar sozinha.
#
# Etapas (cada uma mostra uma linha; em falha, o que falhou, se algo mudou e como retomar):
#   1. Node.js 20 ou mais novo e git (aqui não são instalados: se faltar, explica e para).
#   2. Código de acesso (de ENGRAMA_ACESSO ou digitado sem aparecer na tela): credencial num arquivo npm temporário
#      (o ~/.npmrc não é tocado; apagado no fim), as versões fixadas abaixo no registro e a licença com o
#      verificar-acesso dessa versão. Até aqui nada na máquina muda. Limite: depois de um código recusado espera 2 s,
#      depois do 2º 10 s; no 3º seguido, bloqueia por 15 minutos (arquivo de tentativas na pasta do usuário).
#   3. A IA da pessoa: Claude Code, Codex, Gemini CLI, OpenCode ou Cursor (sem nenhuma, instala o Claude Code).
#   4. Para os daemons e tira do npm global o pacote antigo que fornece os mesmos comandos (dados e Docker ficam).
#   5. Instala @sevinicius/engrama e @sevinicius/delegaai nas versões fixadas, só do registro privado.
#   6. engrama instalar-acesso: transfere a Mente antiga local, ativa a licença, sobe a memória (banco embutido) e
#      conecta as IAs; registra a memória para ligar sozinha.
#   7. delegaai instalar (o DelegaAí dentro das IAs) e delegaai doctor (conferência).
#
# O código vai para os comandos só pela entrada padrão (printf é embutido do bash: não aparece na lista de processos).

set -u

COMANDO="${ENGRAMA_INSTALADOR_COMANDO:-curl -fsSL https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.sh | bash}"
# Versões fixadas desta edição do instalador (as mesmas do install.ps1; o teste do repositório confere).
PACOTES=('@sevinicius/engrama@0.14.0-alpha.3' '@sevinicius/delegaai@0.3.0')
# Limite de tentativas (a mesma regra do install.ps1 e de scripts/licenca/limite-tentativas.cjs).
ESPERAS=(2 10)
MAX_FALHAS=3
BLOQUEIO_S=900
ESQUECE_S=900
ARQ_TENTATIVAS="${ENGRAMA_INSTALADOR_ESTADO:-${XDG_STATE_HOME:-$HOME/.local/state}/engrama/instalador-tentativas}"

# Trechos de Node idênticos aos do install.ps1 (o teste do repositório confere).

# Lê o código da entrada padrão, confere a credencial de distribuição contra a lista permitida (registro
# https://npm.pkg.github.com, escopo @sevinicius, pacotes @sevinicius/nome, token só com letras, números, _ e -: a
# mesma de scripts/licenca/acesso.cjs) e grava o npmrc em argv[1]. Pontas tiradas: as mesmas de formato.normalizarChave.
# Sai 0 (gravou), 2 (código fora do formato), 3 (credencial inválida ou forjada) ou 4 (não gravou). Não imprime nada.
IFS= read -r -d '' JS_LER_DIST <<'FIM_JS' || true
const fs = require('fs');
let texto = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (parte) => { texto += parte; });
process.stdin.on('end', () => {
  const REGISTRO = 'https://npm.pkg.github.com';
  const ESCOPO = '@sevinicius';
  const TOKEN = /^[A-Za-z0-9_-]+$/;
  const PACOTE = /^@sevinicius\/[a-z0-9][a-z0-9._-]*$/;
  const INVISIVEIS = /[\s\u200b-\u200d\ufeff]+/g;
  const ENVOLTURA = /^[\s\x22'\x60<>\u201c\u201d\u2018\u2019\u00ab\u00bb.,;:!?*()_[\]{}]+|[\s\x22'\x60<>\u201c\u201d\u2018\u2019\u00ab\u00bb.,;:!?*()_[\]{}]+$/g;
  const objeto = (x) => x !== null && typeof x === 'object' && !Array.isArray(x);
  const codigo = texto.replace(INVISIVEIS, '').replace(ENVOLTURA, '');
  const ponto = codigo.indexOf('.');
  const corpo = codigo.slice(ponto + 1);
  if (ponto < 0 || codigo.slice(0, ponto) !== 'ENGA1' || !/^[A-Za-z0-9_-]+$/.test(corpo)) process.exit(2);
  let carga = null;
  try { carga = JSON.parse(Buffer.from(corpo, 'base64url').toString('utf8')); } catch (_) { process.exit(2); }
  if (!objeto(carga) || carga.v !== 1 || !objeto(carga.dist)) process.exit(2);
  const { tipo, registro, escopo, token } = carga.dist;
  const pacotes = carga.pacotes;
  if (tipo !== 'npm' || registro !== REGISTRO || escopo !== ESCOPO) process.exit(3);
  if (typeof token !== 'string' || token.length > 1000 || !TOKEN.test(token)) process.exit(3);
  if (!Array.isArray(pacotes) || !pacotes.length || !pacotes.every((p) => typeof p === 'string' && PACOTE.test(p))) process.exit(3);
  try {
    fs.writeFileSync(process.argv[1], ESCOPO + ':registry=' + REGISTRO + '\n//npm.pkg.github.com/:_authToken=' + token + '\n', { mode: 0o600 });
  } catch (_) { process.exit(4); }
});
FIM_JS

# Lê o JSON de `npm ls -g --json --depth=0` da entrada padrão e imprime, um por linha, os pacotes da pasta global
# argv[1] (exceto @sevinicius/engrama) cujo package.json declara o comando mente-global ou engrama.
IFS= read -r -d '' JS_PACOTES_ANTIGOS <<'FIM_JS' || true
const fs = require('fs');
const path = require('path');
let texto = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (parte) => { texto += parte; });
process.stdin.on('end', () => {
  const NOME = /^(@[a-z0-9][a-z0-9._~-]*\/)?[a-z0-9][a-z0-9._~-]*$/;
  let dependencias = {};
  try { dependencias = JSON.parse(texto).dependencies; } catch (_) { dependencias = {}; }
  if (!dependencias || typeof dependencias !== 'object' || Array.isArray(dependencias)) dependencias = {};
  const antigos = [];
  for (const nome of Object.keys(dependencias)) {
    if (nome === '@sevinicius/engrama' || !NOME.test(nome)) continue;
    let pacote = null;
    try { pacote = JSON.parse(fs.readFileSync(path.join(process.argv[1], nome, 'package.json'), 'utf8')); } catch (_) { continue; }
    const bin = pacote && pacote.bin;
    const comandos = typeof bin === 'string' ? [nome.split('/').pop()] : (bin && typeof bin === 'object' ? Object.keys(bin) : []);
    if (comandos.includes('mente-global') || comandos.includes('engrama')) antigos.push(nome);
  }
  if (antigos.length) process.stdout.write(antigos.join('\n') + '\n');
});
FIM_JS

codigo=''
pasta_npmrc=''
npmrc=''

limpar() {
  if [ -n "$pasta_npmrc" ]; then rm -rf "$pasta_npmrc"; fi
  codigo=''
}
trap limpar EXIT
trap 'limpar; exit 130' INT TERM

etapa() { printf '[%s/7] %s\n' "$1" "$2"; }
aviso() { printf '  Aviso: %s\n' "$1"; }
tem() { command -v "$1" >/dev/null 2>&1; }

falha() {
  printf '\nFalhou: %s\n' "$1" >&2
  if [ -n "${2:-}" ]; then printf '%s\n' "$2" >&2; fi
  if [ -n "${3:-}" ]; then printf 'Para retomar: %s\n' "$3" >&2; fi
}

entregar_codigo() { printf '%s\n' "$codigo"; }

# ── Tentativas: uma linha "v1 <falhas> <última falha> <bloqueado até>" (segundos desde 1970) ────────────────────────
agora() { date +%s; }
ler_tentativas() {
  t_falhas=0; t_ultima=0; t_ate=0
  local v='' a='' b='' c=''
  if [ -r "$ARQ_TENTATIVAS" ]; then
    # sem quebra de linha no fim o read sai com erro, mas lê os campos
    read -r v a b c < "$ARQ_TENTATIVAS" 2>/dev/null || true
    if [ "$v" = 'v1' ] && [[ "$a" =~ ^[0-9]+$ && "$b" =~ ^[0-9]+$ && "$c" =~ ^[0-9]+$ ]]; then t_falhas=$a; t_ultima=$b; t_ate=$c; fi
  fi
}
gravar_tentativas() {
  mkdir -p "$(dirname "$ARQ_TENTATIVAS")" 2>/dev/null || true
  printf 'v1 %s %s %s\n' "$1" "$2" "$3" > "$ARQ_TENTATIVAS" 2>/dev/null || true
}
# Imprime os segundos até poder tentar: 0 = agora; positivo = espera curta; negativo = bloqueado (o que falta).
espera_tentativa() {
  ler_tentativas
  local t
  t=$(agora)
  if [ "$t_ate" -gt "$t" ]; then printf '%s\n' "$((t - t_ate))"; return; fi
  if [ "$t_falhas" -le 0 ] || [ $((t - t_ultima)) -ge "$ESQUECE_S" ]; then printf '0\n'; return; fi
  local i=$((t_falhas - 1))
  if [ "$i" -ge "${#ESPERAS[@]}" ]; then i=$((${#ESPERAS[@]} - 1)); fi
  local falta=$((t_ultima + ESPERAS[i] - t))
  if [ "$falta" -gt 0 ]; then printf '%s\n' "$falta"; else printf '0\n'; fi
}
# Registra uma recusa. Imprime a espera antes da próxima tentativa ou -1 quando acabou de bloquear.
registrar_falha() {
  ler_tentativas
  local t falhas=1
  t=$(agora)
  if [ "$t_falhas" -gt 0 ] && [ $((t - t_ultima)) -lt "$ESQUECE_S" ]; then falhas=$((t_falhas + 1)); fi
  if [ "$falhas" -ge "$MAX_FALHAS" ]; then
    gravar_tentativas 0 "$t" $((t + BLOQUEIO_S))
    printf -- '-1\n'
    return
  fi
  gravar_tentativas "$falhas" "$t" 0
  printf '%s\n' "${ESPERAS[$((falhas - 1))]}"
}
limpar_tentativas() { rm -f "$ARQ_TENTATIVAS" 2>/dev/null || true; }

ler_codigo() {
  codigo="${ENGRAMA_ACESSO:-}"
  if [ -n "$codigo" ]; then return 0; fi
  if ! { printf 'Cole o código de acesso e tecle Enter (ele não aparece na tela): ' > /dev/tty; } 2>/dev/null; then
    falha 'não há um terminal para digitar o código.' 'Nada foi alterado.' "exporte ENGRAMA_ACESSO com o código e rode de novo: $COMANDO"
    return 1
  fi
  IFS= read -rs codigo < /dev/tty || true
  printf '\n' > /dev/tty
  return 0
}

# Confere o código: 0 = aceito; 10 formato; 11 credencial; 12 acesso negado no registro; 13 sem rede;
# 14 versão fixada ausente; 15 pasta temporária; 16 licença recusada pelo verificar-acesso. Deixa a pasta atual na
# pasta do npmrc (um .npmrc de projeto na pasta da pessoa venceria o --userconfig).
conferir_acesso() {
  case "$codigo" in *ENGA1.*) ;; *) return 10 ;; esac
  if [ -z "$pasta_npmrc" ]; then
    if ! pasta_npmrc=$(mktemp -d "${TMPDIR:-/tmp}/engrama-instalador.XXXXXX"); then pasta_npmrc=''; return 15; fi
    chmod 700 "$pasta_npmrc"
    npmrc="$pasta_npmrc/npmrc"
  fi
  rm -f "$npmrc"
  entregar_codigo | node -e "$JS_LER_DIST" "$npmrc"
  case $? in 0) ;; 2) return 10 ;; 3) return 11 ;; *) return 15 ;; esac
  cd "$pasta_npmrc" || return 15
  local alvo vista erro="$pasta_npmrc/erro"
  for alvo in "${PACOTES[@]}"; do
    vista=$(npm view "$alvo" version --userconfig "$npmrc" 2>"$erro") || vista=''
    vista=$(printf '%s\n' "$vista" | sed '/^[[:space:]]*$/d' | tail -n 1 | tr -d '[:space:]')
    if [ -z "$vista" ]; then
      if grep -Eq 'E40[134]|40[134] ' "$erro" 2>/dev/null; then return 12; fi
      return 13
    fi
    if [ "$vista" != "${alvo##*@}" ]; then return 14; fi
  done
  if ! entregar_codigo | npx --userconfig "$npmrc" -y -p "${PACOTES[0]}" engrama verificar-acesso; then return 16; fi
  return 0
}

principal() {
  printf '\nInstalador do DelegaAí + Engrama\n\n'
  local pasta_inicial
  pasta_inicial=$(pwd)

  # 1. Node.js e git (só confere)
  etapa 1 'Conferindo o Node.js (versão 20 ou mais nova) e o git...'
  local maior=0
  if tem node; then
    maior=$(node -v 2>/dev/null)
    maior=${maior#v}
    maior=${maior%%.*}
    case "$maior" in '' | *[!0-9]*) maior=0 ;; esac
  fi
  if [ "$maior" -lt 20 ]; then
    falha 'o Node.js 20 ou mais novo não foi encontrado.' 'Nada foi alterado.' \
      "instale o Node.js LTS (https://nodejs.org, o nvm ou o gerenciador de pacotes do sistema) e rode de novo: $COMANDO"
    return 1
  fi
  if ! tem npm || ! tem npx; then
    falha 'o npm não foi encontrado junto do Node.js.' 'Nada foi alterado.' "instale o npm e rode de novo: $COMANDO"
    return 1
  fi
  if ! tem git; then
    falha 'o git não foi encontrado.' 'Nada foi alterado.' \
      "instale o git (macOS: xcode-select --install; Debian/Ubuntu: sudo apt install git) e rode de novo: $COMANDO"
    return 1
  fi
  printf '  Node.js %s e git prontos.\n' "$maior"

  # 2. Código de acesso e licença, conferidos antes de qualquer mudança
  etapa 2 'Conferindo o código de acesso e a licença (nada na máquina muda nesta etapa)...'
  # O npx também instala o pacote (no cache dele): sem isto, o postinstall criaria um banco e subiria daemons.
  export MENTE_SKIP_POSTINSTALL=1
  local espera motivo texto proxima
  while :; do
    espera=$(espera_tentativa)
    if [ "$espera" -lt 0 ]; then
      falha "muitos códigos recusados seguidos. Por segurança, o instalador fica bloqueado por mais $(((59 - espera) / 60)) minuto(s)." \
        'Nada foi alterado.' "confira o código que você recebeu e, passado esse tempo, rode de novo: $COMANDO"
      return 1
    fi
    if [ "$espera" -gt 0 ]; then
      printf '  Aguardando %s s antes de conferir outro código...\n' "$espera"
      sleep "$espera"
    fi
    ler_codigo || return 1
    conferir_acesso
    motivo=$?
    case $motivo in
      0) break ;;
      13)
        falha 'não consegui falar com o registro de pacotes (https://npm.pkg.github.com).' 'Nada foi alterado.' \
          "confira a internet (e o proxy, se houver) e rode de novo: $COMANDO"
        return 1
        ;;
      14)
        falha 'o código foi aceito, mas a versão que este instalador fixa não está no registro.' 'Nada foi alterado.' \
          "avise quem enviou o seu acesso; depois rode de novo: $COMANDO"
        return 1
        ;;
      15)
        falha 'não consegui usar a pasta temporária.' 'Nada foi alterado.' "confira o espaço em ${TMPDIR:-/tmp} e rode de novo: $COMANDO"
        return 1
        ;;
      11) texto='o código de acesso traz uma credencial de download inválida. Peça um código novo.' ;;
      12) texto='acesso inválido ou credencial trocada. Peça um código novo a quem enviou o seu acesso.' ;;
      16) texto='a licença foi recusada (o motivo está na linha acima).' ;;
      *) texto='isto não é um código de acesso válido (ele começa com ENGA1). Copie o código inteiro da mensagem que você recebeu.' ;;
    esac
    codigo=''
    proxima=$(registrar_falha)
    if [ "$proxima" -lt 0 ]; then
      falha "$texto Foram 3 códigos recusados seguidos: o instalador fica bloqueado por 15 minutos." 'Nada foi alterado.' \
        "com o código certo, depois de 15 minutos, rode de novo: $COMANDO"
      return 1
    fi
    if [ -n "${ENGRAMA_ACESSO:-}" ]; then
      falha "$texto" 'Nada foi alterado.' "com o código certo, rode de novo: $COMANDO"
      return 1
    fi
    printf '  %s\n  Tente de novo.\n' "$texto"
  done
  limpar_tentativas
  printf '  Código aceito.\n'

  # npm global sem sudo: se a pasta global não é gravável, usa ~/.npm-global (e avisa para pôr no PATH).
  local prefixo raiz
  prefixo=$(npm prefix -g 2>/dev/null) || prefixo=''
  if [ -n "$prefixo" ] && [ ! -w "$prefixo/lib" ] && [ ! -w "$prefixo" ]; then
    prefixo="$HOME/.npm-global"
    mkdir -p "$prefixo"
    npm config set prefix "$prefixo" --location=user >/dev/null 2>&1 || true
    export PATH="$prefixo/bin:$PATH"
    aviso "pacotes globais do npm em $prefixo: acrescente  export PATH=\"$prefixo/bin:\$PATH\"  ao seu ~/.bashrc ou ~/.zshrc"
  fi

  # 3. A IA da pessoa
  etapa 3 'Procurando a sua IA (Claude Code, Codex, Gemini CLI, OpenCode ou Cursor)...'
  local ia pkg achadas=''
  pacote_da_ia() {
    case "$1" in
      claude) printf '@anthropic-ai/claude-code' ;;
      codex) printf '@openai/codex' ;;
      gemini) printf '@google/gemini-cli' ;;
      opencode) printf 'opencode-ai' ;;
    esac
  }
  for ia in $(printf '%s' "${DELEGAAI_INSTALAR_IA:-}" | tr ',' ' ' | tr '[:upper:]' '[:lower:]'); do
    pkg=$(pacote_da_ia "$ia")
    if [ -z "$pkg" ]; then aviso "IA desconhecida em DELEGAAI_INSTALAR_IA: $ia (use claude, codex, gemini ou opencode)"; continue; fi
    if tem "$ia"; then continue; fi
    npm install -g "$pkg" --prefix "$prefixo" --no-audit --no-fund --loglevel=error || aviso "não consegui instalar $pkg; instale depois e rode: delegaai instalar"
  done
  for ia in claude codex gemini opencode cursor; do if tem "$ia"; then achadas="$achadas $ia"; fi; done
  if [ -z "$achadas" ]; then
    if [ "${DELEGAAI_SEM_CLAUDE:-}" = '1' ]; then
      aviso 'nenhuma IA encontrada; instale uma depois e rode: delegaai instalar'
    else
      # Nenhuma IA na máquina: o Claude Code é a que tem a integração mais completa.
      printf '  Nenhuma IA encontrada; instalando o Claude Code...\n'
      if npm install -g @anthropic-ai/claude-code --prefix "$prefixo" --no-audit --no-fund --loglevel=error; then achadas=' claude'
      else aviso 'não consegui instalar o Claude Code; instale uma IA depois e rode: delegaai instalar'; fi
    fi
  fi
  if [ -n "$achadas" ]; then printf '  IAs nesta máquina:%s (na primeira vez, abra e faça o login).\n' "$achadas"; fi

  # 4. Tira do caminho o que fornece os mesmos comandos (dados, pastas e Docker não são tocados)
  etapa 4 'Tirando do caminho a instalação anterior (dados, pastas e Docker não são tocados)...'
  local comando
  for comando in engrama mente-global; do
    if tem "$comando"; then "$comando" daemons down >/dev/null 2>&1 || true; fi
  done
  local antigos nome removidos=0
  raiz=$(npm root -g 2>/dev/null) || raiz=''
  prefixo=$(npm prefix -g 2>/dev/null) || prefixo=''
  if [ -z "$raiz" ] || [ -z "$prefixo" ]; then
    falha 'não consegui descobrir a pasta global do npm.' \
      'Nada foi removido; se havia uma Mente rodando, ela só foi pausada (religue com: engrama daemons up ou mente-global daemons up).' \
      "rode de novo: $COMANDO"
    return 1
  fi
  antigos=$(npm ls -g --json --depth=0 2>/dev/null | node -e "$JS_PACOTES_ANTIGOS" "$raiz")
  while IFS= read -r nome; do
    [ -z "$nome" ] && continue
    printf '  Removendo do npm global: %s\n' "$nome"
    if ! npm uninstall -g "$nome"; then
      falha "não consegui remover o pacote antigo $nome." 'Seus dados não foram tocados; a Mente antiga ficou pausada.' \
        "se o erro for de permissão (EACCES), use o Node do nvm ou um prefixo do npm na sua pasta; depois rode de novo: $COMANDO"
      return 1
    fi
    removidos=$((removidos + 1))
  done <<< "$antigos"
  if [ "$removidos" -eq 0 ]; then printf '  Nenhuma instalação anterior para remover.\n'; fi

  # 5. Instala os pacotes, só do registro privado (sem o postinstall: a configuração vem na etapa 6)
  etapa 5 "Instalando ${PACOTES[*]}..."
  if ! npm install -g "${PACOTES[@]}" --userconfig "$npmrc" --prefix "$prefixo" --no-audit --no-fund; then
    falha 'a instalação dos pacotes pelo npm falhou (detalhes acima).' \
      'A instalação anterior pode já ter sido removida; seus dados não foram tocados.' \
      "confira a internet (e, se o erro for de permissão, use o Node do nvm) e rode de novo: $COMANDO"
    return 1
  fi
  unset MENTE_SKIP_POSTINSTALL
  # De volta à pasta da pessoa: os daemons que o instalar-acesso sobe não podem ficar presos na pasta temporária.
  cd "$pasta_inicial" 2>/dev/null || cd "$HOME" || true

  # 6. Mente antiga, licença, memória e conexão das IAs: tudo no próprio Engrama
  etapa 6 'Configurando: Mente antiga, licença, memória e conexão das IAs...'
  local engrama="$prefixo/bin/engrama" delegaai="$prefixo/bin/delegaai"
  if [ ! -x "$engrama" ] || [ ! -x "$delegaai" ]; then
    falha 'os comandos engrama e delegaai não apareceram depois da instalação.' 'Os pacotes foram instalados; seus dados não foram tocados.' \
      "abra um terminal novo e rode de novo: $COMANDO"
    return 1
  fi
  # IA recém-instalada só cria a pasta de config na 1ª execução (sem ela o connect acha que não está instalada); o
  # DelegaAí instalado tem a pasta dele, que liga a extensão da esteira na memória.
  if tem claude; then mkdir -p "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; fi
  if tem codex; then mkdir -p "${CODEX_HOME:-$HOME/.codex}"; fi
  if tem gemini; then mkdir -p "$HOME/.gemini"; fi
  if tem opencode; then mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}/opencode"; fi
  mkdir -p "${DELEGAAI_HOME:-$HOME/.delegaai}"
  entregar_codigo | "$engrama" instalar-acesso
  local configurado=$?
  codigo=''
  if [ "$configurado" -ne 0 ]; then
    falha 'a configuração terminou com erro (detalhes acima).' 'Os pacotes já estão instalados; seus dados não foram tocados.' \
      "rode de novo (repetir é seguro): $COMANDO"
    return "$configurado"
  fi
  if [ "${DELEGAAI_SEM_AUTOSTART:-}" = '1' ]; then
    printf '  Auto-start pulado (DELEGAAI_SEM_AUTOSTART=1): ligue a memória com engrama daemons up.\n'
  elif ! "$engrama" autostart install >/dev/null 2>&1; then
    aviso 'não consegui registrar a memória para ligar sozinha; depois de reiniciar, rode: engrama daemons up'
  fi

  # 7. DelegaAí nas IAs e conferência
  etapa 7 'Colocando o DelegaAí nas suas IAs e conferindo tudo...'
  "$delegaai" instalar || aviso 'não consegui colocar o DelegaAí nas IAs; rode depois: delegaai instalar'
  "$delegaai" doctor || true

  printf '\nPronto. Abra um terminal novo e a sua IA em qualquer projeto (uma pasta com git) e peça o que quer.\n'
  printf 'Painel da memória: http://127.0.0.1:7474/painel  -  ajuda: delegaai ajuda e engrama help\n'
  return 0
}

# Tudo dentro de uma função chamada só na última linha: um download pela metade (curl | bash) não executa nada.
principal "$@"
