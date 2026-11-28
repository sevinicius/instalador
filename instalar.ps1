# Instalador do DelegaAí + Engrama para Windows (PowerShell 5.1 ou mais novo).
#
#   irm https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.ps1 | iex
#   ou clique duplo no Instalar-DelegaAi.cmd (github.com/sevinicius/instalador, última release)
#
# Só instala com o código de acesso (ENGA1.…) gerado no portal de licenças: os pacotes ficam num registro PRIVADO
# (GitHub Packages) e a credencial que os baixa vem dentro do código. Este script não tem link de pacote nem
# credencial: lido ou editado, não serve para baixar nada sem um código válido.
#
# Instalação silenciosa: defina $env:ENGRAMA_ACESSO com o código de acesso antes de rodar.
# Opções (antes de rodar): DELEGAAI_INSTALAR_IA=claude,codex,gemini,opencode instala essas IAs;
#   DELEGAAI_SEM_CLAUDE=1 não instala o Claude Code quando não há nenhuma IA; DELEGAAI_SEM_AUTOSTART=1 não registra a
#   memória para ligar sozinha no login.
#
# Etapas, nesta ordem (cada uma mostra uma linha; em falha, o que falhou, se algo mudou e como retomar):
#   1. Código de acesso: formato, credencial na lista permitida e acesso aos pacotes no registro (só metadados; nada é
#      baixado nem instalado). Limite: depois de um código recusado espera 2 s, depois do 2º 10 s; no 3º seguido, bloqueia
#      por 15 minutos (arquivo de tentativas na pasta do usuário).
#   2. Node.js 20 ou mais novo (instala pelo winget se faltar).
#   3. Credencial num arquivo npm temporário (o .npmrc da pessoa não é tocado; apagado no fim); confere as versões
#      fixadas abaixo no registro e a licença com o verificar-acesso dessa versão. Até aqui nada do produto é instalado.
#   4. git (instala pelo winget se faltar).
#   5. A IA da pessoa: Claude Code, Codex, Gemini CLI, OpenCode ou Cursor (sem nenhuma, instala o Claude Code).
#   6. Para os daemons e tira do npm global o pacote antigo que fornece os mesmos comandos (dados e Docker ficam).
#   7. Instala @sevinicius/engrama e @sevinicius/delegaai nas versões fixadas, só do registro privado.
#   8. engrama instalar-acesso: transfere a Mente antiga local, ativa a licença, sobe a memória (banco embutido) e
#      conecta as IAs; registra a memória para ligar sozinha no login.
#   9. delegaai instalar (o DelegaAí dentro das IAs) e delegaai doctor (conferência).
#
# O código vai para os comandos só pela entrada padrão: nunca como argumento (apareceria na lista de processos)
# nem na tela. Arquivo em UTF-8 sem BOM: com BOM, o irm | iex quebraria o primeiro comando.

$engramaResultado = & {
    $ErrorActionPreference = 'Stop'
    $COMANDO = 'irm https://raw.githubusercontent.com/sevinicius/engrama-instalador/main/install.ps1 | iex'
    if ($env:ENGRAMA_INSTALADOR_COMANDO) { $COMANDO = $env:ENGRAMA_INSTALADOR_COMANDO }
    # Versões fixadas desta edição do instalador (o publicar.cjs confere que a do Engrama é a do package.json).
    $VERSOES = [ordered]@{ '@sevinicius/engrama' = '0.14.0-alpha.3'; '@sevinicius/delegaai' = '0.3.0' }
    $REGISTRO = 'https://npm.pkg.github.com'
    $IAS = [ordered]@{ claude = '@anthropic-ai/claude-code'; codex = '@openai/codex'; gemini = '@google/gemini-cli'; opencode = 'opencode-ai' }
    # Limite de tentativas: espera depois da 1ª e da 2ª recusa; na 3ª seguida, bloqueio. Falhas com mais de 15 min são
    # esquecidas. A mesma regra de scripts/licenca/limite-tentativas.cjs e do install.sh.
    $ESPERAS = @(2, 10)
    $MAX_FALHAS = 3
    $BLOQUEIO_S = 900
    $ESQUECE_S = 900
    $pastaEstado = $env:LOCALAPPDATA
    if (-not $pastaEstado) { $pastaEstado = $env:TEMP }
    if (-not $pastaEstado) { $pastaEstado = [IO.Path]::GetTempPath() }
    $ARQ_TENTATIVAS = Join-Path (Join-Path $pastaEstado 'Engrama') 'instalador-tentativas.txt'
    if ($env:ENGRAMA_INSTALADOR_ESTADO) { $ARQ_TENTATIVAS = $env:ENGRAMA_INSTALADOR_ESTADO }

    # Trechos de Node (idênticos no install.sh; o teste do repositório confere). Sem aspas duplas: o PowerShell 5.1
    # as perde ao passar o argumento para o node.

    # Lê o código da entrada padrão, confere a credencial de distribuição contra a lista permitida (registro
    # https://npm.pkg.github.com, escopo @sevinicius, pacotes @sevinicius/nome, token só com letras, números, _ e -: a
    # mesma de scripts/licenca/acesso.cjs) e grava o npmrc em argv[1]. Pontas tiradas: as mesmas de formato.normalizarChave.
    # Sai 0 (gravou), 2 (código fora do formato), 3 (credencial inválida ou forjada) ou 4 (não gravou). Não imprime nada.
    $JsLerDist = @'
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
'@

    # Lê o JSON de `npm ls -g --json --depth=0` da entrada padrão e imprime, um por linha, os pacotes da pasta global
    # argv[1] (exceto @sevinicius/engrama) cujo package.json declara o comando mente-global ou engrama.
    $JsPacotesAntigos = @'
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
'@

    function Write-Etapa([int]$Numero, [string]$Texto) {
        Write-Host ('[{0}/9] {1}' -f $Numero, $Texto) -ForegroundColor Cyan
    }

    function Write-Falha([string]$OQue, [string]$Situacao, [string]$Retomar) {
        Write-Host ''
        Write-Host ('Falhou: ' + $OQue) -ForegroundColor Red
        if ($Situacao) { Write-Host $Situacao -ForegroundColor Yellow }
        if ($Retomar) { Write-Host ('Para retomar: ' + $Retomar) }
    }

    function Write-Aviso([string]$Texto) { Write-Host ('  Aviso: ' + $Texto) -ForegroundColor Yellow }

    # Roda um programa nativo. O PowerShell 5.1 não para em código de saída de programa nativo (nem com 'Stop') e,
    # com 'Stop', transforma stderr redirecionado em erro: por isso 'Continue' aqui e o código de saída devolvido.
    # -Entrada vai pela entrada padrão (nunca como argumento). Sem -Capturar a saída vai para a tela e volta só o código.
    function Invoke-Nativo {
        param([string]$Programa, [string[]]$Argumentos = @(), [string]$Entrada, [switch]$Capturar)
        $ErrorActionPreference = 'Continue'
        $temEntrada = $PSBoundParameters.ContainsKey('Entrada')
        if ($Capturar) {
            if ($temEntrada) { $saida = $Entrada | & $Programa @Argumentos 2>$null } else { $saida = & $Programa @Argumentos 2>$null }
            return [pscustomobject]@{ Codigo = $LASTEXITCODE; Saida = (@($saida) -join "`n") }
        }
        if ($temEntrada) { $Entrada | & $Programa @Argumentos | Out-Host } else { & $Programa @Argumentos | Out-Host }
        return $LASTEXITCODE
    }

    function Get-VersaoNode {
        $node = Get-Command 'node.exe' -ErrorAction SilentlyContinue
        if (-not $node) { return 0 }
        $r = Invoke-Nativo -Programa $node.Source -Argumentos @('-v') -Capturar
        if ($r.Codigo -eq 0 -and $r.Saida -match 'v(\d+)\.') { return [int]$Matches[1] }
        return 0
    }

    function Update-CaminhoDaSessao {
        $maquina = [Environment]::GetEnvironmentVariable('Path', 'Machine')
        $usuario = [Environment]::GetEnvironmentVariable('Path', 'User')
        $env:Path = (@($maquina, $usuario) | Where-Object { $_ }) -join ';'
    }

    function Install-ComWinget([string]$Id, [string]$Nome) {
        $winget = Get-Command 'winget.exe' -ErrorAction SilentlyContinue
        if (-not $winget) { return $false }
        Write-Host ('  {0} não encontrado; instalando pelo winget...' -f $Nome)
        Invoke-Nativo -Programa $winget.Source -Argumentos @('install', '-e', '--id', $Id, '--accept-source-agreements', '--accept-package-agreements') | Out-Null
        Update-CaminhoDaSessao
        return $true
    }

    # O código só existe em memória: SecureString -> BSTR -> texto, e o BSTR é zerado logo em seguida.
    function Read-CodigoAcesso {
        if ($env:ENGRAMA_ACESSO) { return $env:ENGRAMA_ACESSO }
        $seguro = Read-Host -Prompt 'Cole o código de acesso e tecle Enter (ele não aparece na tela)' -AsSecureString
        $ponteiro = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($seguro)
        try { return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($ponteiro) }
        finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($ponteiro)
            $seguro.Dispose()
        }
    }

    # Lê o código sem o Node (que talvez ainda não esteja instalado): mesmas regras do trecho JsLerDist.
    # Devolve Motivo = 'ok' (com o Token), 'formato' ou 'credencial'. Não imprime nada.
    function Read-CargaAcesso([string]$Texto) {
        $formato = [pscustomobject]@{ Motivo = 'formato'; Token = $null }
        $credencial = [pscustomobject]@{ Motivo = 'credencial'; Token = $null }
        $limpo = [regex]::Replace([string]$Texto, '[\s\u200b-\u200d\ufeff]+', '')
        $m = [regex]::Match($limpo, '^[^A-Za-z0-9]*ENGA1\.([A-Za-z0-9_-]+?)[^A-Za-z0-9-]*$')
        if (-not $m.Success) { return $formato }
        $b64 = $m.Groups[1].Value.Replace('-', '+').Replace('_', '/')
        switch ($b64.Length % 4) { 1 { return $formato } 2 { $b64 += '==' } 3 { $b64 += '=' } }
        try { $carga = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($b64)) | ConvertFrom-Json }
        catch { return $formato }
        if (-not $carga -or $carga -isnot [Management.Automation.PSCustomObject]) { return $formato }
        if (-not (($carga.v -is [int]) -or ($carga.v -is [long])) -or $carga.v -ne 1) { return $formato }
        $dist = $carga.dist
        if (-not $dist -or $dist -isnot [Management.Automation.PSCustomObject]) { return $formato }
        if ($dist.tipo -cne 'npm' -or $dist.registro -cne $REGISTRO -or $dist.escopo -cne '@sevinicius') { return $credencial }
        $token = $dist.token
        if ($token -isnot [string] -or $token.Length -gt 1000 -or $token -cnotmatch '^[A-Za-z0-9_-]+$') { return $credencial }
        $pacotes = $carga.pacotes
        if ($pacotes -isnot [array] -or $pacotes.Count -lt 1) { return $credencial }
        foreach ($p in $pacotes) { if ($p -isnot [string] -or $p -cnotmatch '^@sevinicius/[a-z0-9][a-z0-9._-]*$') { return $credencial } }
        return [pscustomobject]@{ Motivo = 'ok'; Token = $token }
    }

    # Pergunta ao registro privado se a credencial enxerga cada pacote na versão fixada. Só os metadados: nenhum
    # pacote é baixado. Devolve 'ok', 'negado' (401/403/404: código inválido ou credencial trocada), 'versao' (o
    # registro não tem a versão fixada) ou 'rede' (sem resposta).
    function Test-RegistroAcesso([string]$Token) {
        foreach ($par in $VERSOES.GetEnumerator()) {
            $url = $REGISTRO + '/' + $par.Key.Replace('/', '%2F')
            try {
                $resposta = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 60 -Headers @{ Authorization = ('Bearer ' + $Token); Accept = 'application/json' }
            }
            catch {
                $status = 0
                try { $status = [int]$_.Exception.Response.StatusCode } catch { $status = 0 }
                if (@(401, 403, 404) -contains $status) { return 'negado' }
                return 'rede'
            }
            if ([string]$resposta.Content -notmatch ('"' + [regex]::Escape($par.Value) + '"')) { return 'versao' }
        }
        return 'ok'
    }

    # Arquivo de tentativas: uma linha "v1 <falhas> <última falha> <bloqueado até>" (segundos desde 1970).
    function Get-Agora { return [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds() }
    function Get-Tentativas {
        try {
            $partes = ([IO.File]::ReadAllText($ARQ_TENTATIVAS)).Trim() -split '\s+'
            if ($partes.Count -eq 4 -and $partes[0] -eq 'v1') {
                return @{ Falhas = [int64]$partes[1]; Ultima = [int64]$partes[2]; Ate = [int64]$partes[3] }
            }
        } catch { }
        return @{ Falhas = 0; Ultima = 0; Ate = 0 }
    }
    function Save-Tentativas([int64]$Falhas, [int64]$Ultima, [int64]$Ate) {
        try {
            $pasta = Split-Path -Parent $ARQ_TENTATIVAS
            if ($pasta -and -not (Test-Path -LiteralPath $pasta)) { New-Item -ItemType Directory -Path $pasta -Force | Out-Null }
            [IO.File]::WriteAllText($ARQ_TENTATIVAS, ('v1 {0} {1} {2}' -f $Falhas, $Ultima, $Ate))
        } catch { }
    }
    # Segundos até poder tentar: 0 = agora; positivo = espera curta; negativo = bloqueado (o valor é o que falta).
    function Get-EsperaTentativa {
        $e = Get-Tentativas
        $agora = Get-Agora
        if ($e.Ate -gt $agora) { return - ($e.Ate - $agora) }
        if ($e.Falhas -le 0 -or ($agora - $e.Ultima) -ge $ESQUECE_S) { return 0 }
        $espera = $ESPERAS[[Math]::Min([int]$e.Falhas, $ESPERAS.Count) - 1]
        $falta = $e.Ultima + $espera - $agora
        if ($falta -gt 0) { return $falta }
        return 0
    }
    # Registra uma recusa. Devolve a espera antes da próxima tentativa ou -1 quando acabou de bloquear.
    function Add-FalhaTentativa {
        $e = Get-Tentativas
        $agora = Get-Agora
        $falhas = 1
        if ($e.Falhas -gt 0 -and ($agora - $e.Ultima) -lt $ESQUECE_S) { $falhas = $e.Falhas + 1 }
        if ($falhas -ge $MAX_FALHAS) {
            Save-Tentativas 0 $agora ($agora + $BLOQUEIO_S)
            return -1
        }
        Save-Tentativas $falhas $agora 0
        return $ESPERAS[$falhas - 1]
    }
    function Clear-Tentativas { try { Remove-Item -LiteralPath $ARQ_TENTATIVAS -Force -ErrorAction Stop } catch { } }

    function Install-Engrama {
        Write-Host ''
        Write-Host 'Instalador do DelegaAí + Engrama' -ForegroundColor Green
        Write-Host ''

        $codigo = $null
        $pastaNpmrc = $null
        $empurrou = $false
        $skipAntes = $env:MENTE_SKIP_POSTINSTALL
        try {
            # 1. Código de acesso, conferido antes de qualquer mudança (inclusive antes de instalar o Node)
            Write-Etapa 1 'Conferindo o código de acesso (nada na máquina muda nesta etapa)...'
            $conferido = $false
            while (-not $conferido) {
                $espera = Get-EsperaTentativa
                if ($espera -lt 0) {
                    Write-Falha ('muitos códigos recusados seguidos. Por segurança, o instalador fica bloqueado por mais {0} minuto(s).' -f [Math]::Ceiling(- $espera / 60)) 'Nada foi alterado.' ('confira o código que você recebeu e, passado esse tempo, rode de novo: ' + $COMANDO)
                    return 1
                }
                if ($espera -gt 0) {
                    Write-Host ('  Aguardando {0} s antes de conferir outro código...' -f $espera)
                    Start-Sleep -Seconds $espera
                }
                try { $codigo = Read-CodigoAcesso }
                catch {
                    Write-Falha 'não consegui ler o código de acesso neste terminal.' 'Nada foi alterado.' ('defina o código em $env:ENGRAMA_ACESSO e rode de novo: ' + $COMANDO)
                    return 1
                }
                $carga = Read-CargaAcesso $codigo
                $motivo = $carga.Motivo
                if ($motivo -eq 'ok') { $motivo = Test-RegistroAcesso $carga.Token }
                $carga = $null
                if ($motivo -eq 'ok') { $conferido = $true; continue }
                if ($motivo -eq 'rede') {
                    Write-Falha ('não consegui falar com o registro de pacotes ({0}).' -f $REGISTRO) 'Nada foi alterado.' ('confira a internet (e o proxy, se houver) e rode de novo: ' + $COMANDO)
                    return 1
                }
                if ($motivo -eq 'versao') {
                    Write-Falha 'o código foi aceito, mas a versão que este instalador fixa não está no registro.' 'Nada foi alterado.' ('avise quem enviou o seu acesso; depois rode de novo: ' + $COMANDO)
                    return 1
                }
                $texto = 'isto não é um código de acesso válido (ele começa com ENGA1). Copie o código inteiro da mensagem que você recebeu.'
                if ($motivo -eq 'credencial') { $texto = 'o código de acesso traz uma credencial de download inválida. Peça um código novo.' }
                if ($motivo -eq 'negado') { $texto = 'acesso inválido ou credencial trocada. Peça um código novo a quem enviou o seu acesso.' }
                $codigo = $null
                $proxima = Add-FalhaTentativa
                if ($proxima -lt 0) {
                    Write-Falha ($texto + ' Foram 3 códigos recusados seguidos: o instalador fica bloqueado por 15 minutos.') 'Nada foi alterado.' ('com o código certo, depois de 15 minutos, rode de novo: ' + $COMANDO)
                    return 1
                }
                if ($env:ENGRAMA_ACESSO) {
                    Write-Falha $texto 'Nada foi alterado.' ('com o código certo, rode de novo: ' + $COMANDO)
                    return 1
                }
                Write-Host ('  ' + $texto) -ForegroundColor Yellow
                Write-Host '  Tente de novo.'
            }
            Write-Host '  Código aceito.'

            # 2. Node.js
            Write-Etapa 2 'Conferindo o Node.js (precisa da versão 20 ou mais nova)...'
            $maior = Get-VersaoNode
            if ($maior -lt 20) {
                if ($maior -gt 0) { Write-Host ('  Node.js {0} é antigo demais.' -f $maior) }
                if (-not (Install-ComWinget 'OpenJS.NodeJS.LTS' 'Node.js 20')) {
                    Write-Falha 'o Node.js 20 ou mais novo não foi encontrado e o winget não está disponível para instalá-lo.' 'Nada foi alterado.' ('instale o Node.js LTS por https://nodejs.org, abra um PowerShell novo e rode de novo: ' + $COMANDO)
                    return 1
                }
                $maior = Get-VersaoNode
                if ($maior -lt 20) {
                    Write-Falha 'o winget não deixou o Node.js 20 pronto.' 'Nada do Engrama foi alterado.' ('feche e abra o PowerShell e rode de novo: ' + $COMANDO + '  (ou instale o Node.js LTS por https://nodejs.org)')
                    return 1
                }
            }
            $node = (Get-Command 'node.exe').Source
            $comandoNpm = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
            $comandoNpx = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
            if (-not $comandoNpm -or -not $comandoNpx) {
                Write-Falha 'o npm não foi encontrado junto do Node.js.' 'Nada do Engrama foi alterado.' ('reinstale o Node.js LTS (ele traz o npm), abra um PowerShell novo e rode de novo: ' + $COMANDO)
                return 1
            }
            $npm = $comandoNpm.Source
            $npx = $comandoNpx.Source
            Write-Host ('  Node.js {0} pronto.' -f $maior)

            # 3. npmrc temporário (fora do .npmrc da pessoa; apagado no finally) e conferência da licença
            Write-Etapa 3 'Conferindo a licença (credencial num arquivo temporário, apagado no fim)...'
            $base = $env:TEMP
            if (-not $base) { $base = [IO.Path]::GetTempPath() }
            $pastaNpmrc = Join-Path $base ('engrama-instalador-' + [guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $pastaNpmrc | Out-Null
            $npmrc = Join-Path $pastaNpmrc 'npmrc'
            $lido = Invoke-Nativo -Programa $node -Argumentos @('-e', $JsLerDist, $npmrc) -Entrada $codigo -Capturar
            if ($lido.Codigo -ne 0) {
                Write-Falha ('não consegui preparar a credencial de download (código {0}).' -f $lido.Codigo) 'Nada do Engrama foi alterado.' ('confira o espaço e a permissão da pasta temporária e rode de novo: ' + $COMANDO)
                return 1
            }
            # Etapas 3 a 7 com a pasta do npmrc como pasta atual: um .npmrc de projeto na pasta da pessoa venceria o --userconfig.
            Push-Location -LiteralPath $pastaNpmrc
            $empurrou = $true
            # O npx também instala o pacote (no cache dele): sem isto, o postinstall criaria um banco e subiria daemons.
            $env:MENTE_SKIP_POSTINSTALL = '1'
            $alvos = @()
            foreach ($pacote in $VERSOES.Keys) {
                $alvo = $pacote + '@' + $VERSOES[$pacote]
                $consulta = Invoke-Nativo -Programa $npm -Argumentos @('view', $alvo, 'version', '--userconfig', $npmrc) -Capturar
                $vista = @($consulta.Saida -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }) | Select-Object -Last 1
                if ($consulta.Codigo -ne 0 -or $vista -ne $VERSOES[$pacote]) {
                    Write-Falha ('o pacote {0} não está acessível no registro.' -f $alvo) 'Nada do Engrama foi alterado.' ('confira a internet e rode de novo; se repetir, peça um código novo: ' + $COMANDO)
                    return 1
                }
                $alvos += $alvo
            }
            $verificado = Invoke-Nativo -Programa $npx -Argumentos @('--userconfig', $npmrc, '-y', '-p', ('@sevinicius/engrama@' + $VERSOES['@sevinicius/engrama']), 'engrama', 'verificar-acesso') -Entrada $codigo
            if ($verificado -ne 0) {
                Add-FalhaTentativa | Out-Null
                Write-Falha 'a licença foi recusada (o motivo está na linha acima).' 'Nada do Engrama foi alterado.' ('peça um código novo a quem enviou o seu acesso e rode de novo: ' + $COMANDO)
                return 1
            }
            Clear-Tentativas

            # 4. git
            Write-Etapa 4 'Conferindo o git...'
            if (-not (Get-Command 'git.exe' -ErrorAction SilentlyContinue)) {
                $temWinget = Install-ComWinget 'Git.Git' 'git'
                if (-not (Get-Command 'git.exe' -ErrorAction SilentlyContinue)) {
                    $porque = 'o winget não está disponível'
                    if ($temWinget) { $porque = 'o winget não deixou o git pronto nesta janela' }
                    Write-Falha ('o git não foi encontrado e {0}.' -f $porque) 'Nada do Engrama foi alterado (o Node.js pode ter sido instalado).' ('instale o git por https://git-scm.com, abra um PowerShell novo e rode de novo: ' + $COMANDO)
                    return 1
                }
            }
            Write-Host '  git pronto.'

            # 5. A IA da pessoa
            Write-Etapa 5 'Procurando a sua IA (Claude Code, Codex, Gemini CLI, OpenCode ou Cursor)...'
            if ($env:DELEGAAI_INSTALAR_IA) {
                foreach ($ia in @($env:DELEGAAI_INSTALAR_IA -split ',' | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ })) {
                    if (-not $IAS.Contains($ia)) { Write-Aviso ('IA desconhecida em DELEGAAI_INSTALAR_IA: {0} (use claude, codex, gemini ou opencode)' -f $ia); continue }
                    if (Get-Command $ia -ErrorAction SilentlyContinue) { continue }
                    if ((Invoke-Nativo -Programa $npm -Argumentos @('install', '-g', $IAS[$ia], '--no-audit', '--no-fund', '--loglevel=error')) -ne 0) {
                        Write-Aviso ('não consegui instalar {0}; instale depois e rode: delegaai instalar' -f $IAS[$ia])
                    }
                }
            }
            $achadas = @(@('claude', 'codex', 'gemini', 'opencode', 'cursor') | Where-Object { Get-Command $_ -ErrorAction SilentlyContinue })
            if (-not $achadas.Count) {
                if ($env:DELEGAAI_SEM_CLAUDE -eq '1') {
                    Write-Aviso 'nenhuma IA encontrada; instale uma depois e rode: delegaai instalar'
                } else {
                    # Nenhuma IA na máquina: o Claude Code é a que tem a integração mais completa.
                    Write-Host '  Nenhuma IA encontrada; instalando o Claude Code...'
                    if ((Invoke-Nativo -Programa $npm -Argumentos @('install', '-g', $IAS['claude'], '--no-audit', '--no-fund', '--loglevel=error')) -eq 0) { $achadas = @('claude') }
                    else { Write-Aviso 'não consegui instalar o Claude Code; instale uma IA depois e rode: delegaai instalar' }
                }
            }
            if ($achadas.Count) { Write-Host ('  IAs nesta máquina: {0} (na primeira vez, abra e faça o login).' -f ($achadas -join ', ')) }

            # 6. Tira do caminho o que fornece os mesmos comandos (dados, pastas e Docker não são tocados)
            Write-Etapa 6 'Tirando do caminho a instalação anterior (dados, pastas e Docker não são tocados)...'
            foreach ($nomeComando in @('engrama.cmd', 'mente-global.cmd')) {
                $existente = Get-Command $nomeComando -ErrorAction SilentlyContinue
                if ($existente) { Invoke-Nativo -Programa $existente.Source -Argumentos @('daemons', 'down') -Capturar | Out-Null }
            }
            $raiz = (Invoke-Nativo -Programa $npm -Argumentos @('root', '-g') -Capturar).Saida.Trim()
            $prefixo = (Invoke-Nativo -Programa $npm -Argumentos @('prefix', '-g') -Capturar).Saida.Trim()
            if (-not $raiz -or -not $prefixo) {
                Write-Falha 'não consegui descobrir a pasta global do npm.' 'Nada foi removido; se havia uma Mente rodando, ela só foi pausada (religue com: engrama daemons up ou mente-global daemons up).' ('rode de novo: ' + $COMANDO)
                return 1
            }
            $lista = Invoke-Nativo -Programa $npm -Argumentos @('ls', '-g', '--json', '--depth=0') -Capturar
            $antigos = Invoke-Nativo -Programa $node -Argumentos @('-e', $JsPacotesAntigos, $raiz) -Entrada $lista.Saida -Capturar
            $nomesAntigos = @($antigos.Saida -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ })
            foreach ($nome in $nomesAntigos) {
                Write-Host ('  Removendo do npm global: {0}' -f $nome)
                $removido = Invoke-Nativo -Programa $npm -Argumentos @('uninstall', '-g', $nome)
                if ($removido -ne 0) {
                    Write-Falha ('não consegui remover o pacote antigo {0}.' -f $nome) 'Seus dados não foram tocados; a Mente antiga ficou pausada.' ('feche os programas que usam a Mente e rode de novo: ' + $COMANDO)
                    return 1
                }
            }
            if (-not $nomesAntigos.Count) { Write-Host '  Nenhuma instalação anterior para remover.' }

            # 7. Instala os pacotes, só do registro privado (sem o postinstall: a configuração vem na etapa 8)
            Write-Etapa 7 ('Instalando {0}...' -f ($alvos -join ' e '))
            $instalado = Invoke-Nativo -Programa $npm -Argumentos (@('install', '-g') + $alvos + @('--userconfig', $npmrc, '--prefix', $prefixo, '--no-audit', '--no-fund'))
            if ($instalado -ne 0) {
                Write-Falha 'a instalação dos pacotes pelo npm falhou (detalhes acima).' 'A instalação anterior pode já ter sido removida; seus dados não foram tocados.' ('confira a internet e rode de novo: ' + $COMANDO)
                return 1
            }
            if ($null -eq $skipAntes) { Remove-Item Env:MENTE_SKIP_POSTINSTALL -ErrorAction SilentlyContinue } else { $env:MENTE_SKIP_POSTINSTALL = $skipAntes }

            # De volta à pasta da pessoa: os daemons que o instalar-acesso sobe não podem prender a pasta temporária.
            Pop-Location
            $empurrou = $false

            # 8. Mente antiga, licença, memória e conexão das IAs: tudo no próprio Engrama
            Write-Etapa 8 'Configurando: Mente antiga, licença, memória e conexão das IAs...'
            $engrama = Join-Path $prefixo 'engrama.cmd'
            $delegaai = Join-Path $prefixo 'delegaai.cmd'
            if (-not (Test-Path -LiteralPath $engrama) -or -not (Test-Path -LiteralPath $delegaai)) {
                Write-Falha 'os comandos engrama e delegaai não apareceram depois da instalação.' 'Os pacotes foram instalados; seus dados não foram tocados.' ('abra um PowerShell novo e rode de novo: ' + $COMANDO)
                return 1
            }
            # IA recém-instalada só cria a pasta de config na 1ª execução (sem ela o connect acha que não está
            # instalada); o DelegaAí instalado tem a pasta dele, que liga a extensão da esteira na memória.
            $pastas = @{
                claude = $(if ($env:CLAUDE_CONFIG_DIR) { $env:CLAUDE_CONFIG_DIR } else { Join-Path $env:USERPROFILE '.claude' })
                codex = $(if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' })
                gemini = (Join-Path $env:USERPROFILE '.gemini')
                opencode = (Join-Path (Join-Path $env:USERPROFILE '.config') 'opencode')
            }
            foreach ($ia in $pastas.Keys) {
                if ((Get-Command $ia -ErrorAction SilentlyContinue) -and -not (Test-Path -LiteralPath $pastas[$ia])) { New-Item -ItemType Directory -Force -Path $pastas[$ia] | Out-Null }
            }
            $casaDelegaai = $(if ($env:DELEGAAI_HOME) { $env:DELEGAAI_HOME } else { Join-Path $env:USERPROFILE '.delegaai' })
            if (-not (Test-Path -LiteralPath $casaDelegaai)) { New-Item -ItemType Directory -Force -Path $casaDelegaai | Out-Null }
            $configurado = Invoke-Nativo -Programa $engrama -Argumentos @('instalar-acesso') -Entrada $codigo
            $codigo = $null
            if ($configurado -ne 0) {
                Write-Falha 'a configuração terminou com erro (detalhes acima).' 'Os pacotes já estão instalados; seus dados não foram tocados.' ('rode de novo (repetir é seguro): ' + $COMANDO)
                return $configurado
            }
            if ($env:DELEGAAI_SEM_AUTOSTART -eq '1') {
                Write-Host '  Auto-start pulado (DELEGAAI_SEM_AUTOSTART=1): ligue a memória com engrama daemons up.'
            } elseif ((Invoke-Nativo -Programa $engrama -Argumentos @('autostart', 'install') -Capturar).Codigo -ne 0) {
                Write-Aviso 'não consegui registrar a memória para ligar sozinha no login; depois de reiniciar, rode: engrama daemons up'
            }

            # 9. DelegaAí nas IAs e conferência
            Write-Etapa 9 'Colocando o DelegaAí nas suas IAs e conferindo tudo...'
            if ((Invoke-Nativo -Programa $delegaai -Argumentos @('instalar')) -ne 0) { Write-Aviso 'não consegui colocar o DelegaAí nas IAs; rode depois: delegaai instalar' }
            Invoke-Nativo -Programa $delegaai -Argumentos @('doctor') | Out-Null

            Write-Host ''
            Write-Host 'Pronto. Abra um terminal novo e a sua IA em qualquer projeto (uma pasta com git) e peça o que quer.' -ForegroundColor Green
            Write-Host 'Painel da memória: http://127.0.0.1:7474/painel  -  ajuda: delegaai ajuda e engrama help'
            return 0
        }
        finally {
            if ($empurrou) { Pop-Location }
            if ($pastaNpmrc -and (Test-Path -LiteralPath $pastaNpmrc)) { Remove-Item -LiteralPath $pastaNpmrc -Recurse -Force -ErrorAction SilentlyContinue }
            if ($null -eq $skipAntes) { Remove-Item Env:MENTE_SKIP_POSTINSTALL -ErrorAction SilentlyContinue } else { $env:MENTE_SKIP_POSTINSTALL = $skipAntes }
            $codigo = $null
        }
    }

    # TLS 1.2 para o registro (o Windows PowerShell 5.1 pode começar sem ele).
    try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
    # Saída do npm/node capturada em UTF-8 (caminhos com acento) e texto enviado aos programas também em UTF-8.
    $OutputEncoding = New-Object System.Text.UTF8Encoding $false
    $codificacaoAntes = $null
    try { $codificacaoAntes = [Console]::OutputEncoding; [Console]::OutputEncoding = $OutputEncoding } catch { $codificacaoAntes = $null }
    try { Install-Engrama }
    finally { if ($codificacaoAntes) { try { [Console]::OutputEncoding = $codificacaoAntes } catch { } } }
}

# Rodado como arquivo (powershell -File), sai com o código; pelo irm | iex, só deixa o código em $LASTEXITCODE
# (um exit fecharia a janela da pessoa).
$global:LASTEXITCODE = [int](@($engramaResultado)[-1])
Remove-Variable -Name engramaResultado -ErrorAction SilentlyContinue
if ($MyInvocation.MyCommand.CommandType -eq 'ExternalScript') { exit $global:LASTEXITCODE }
