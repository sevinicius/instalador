@echo off
rem DelegaAi + Engrama - instalador para Windows (clique duplo).
rem Baixa o instalar.ps1 da ultima release de github.com/sevinicius/instalador e roda. O instalador pede o codigo de
rem acesso (ENGA1...) que voce recebeu: sem um codigo valido, nenhum pacote e baixado e nada e instalado.
chcp 65001 >nul
title Instalando o DelegaAi + Engrama
set "ENGRAMA_INSTALADOR_ARQ=%TEMP%instalar-delegaai-%RANDOM%%RANDOM%.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/sevinicius/instalador/releases/latest/download/instalar.ps1' -OutFile $env:ENGRAMA_INSTALADOR_ARQ"
if errorlevel 1 (
  echo.
  echo Nao consegui baixar o instalador. Confira a internet e tente de novo.
  del "%ENGRAMA_INSTALADOR_ARQ%" >nul 2>&1
  pause
  exit /b 1
)
set "ENGRAMA_INSTALADOR_COMANDO=o Instalar-DelegaAi.cmd (clique duplo)"
rem Lido como UTF-8 (o arquivo nao tem BOM; o powershell -File o leria como ANSI e estragaria os acentos).
powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([scriptblock]::Create([IO.File]::ReadAllText($env:ENGRAMA_INSTALADOR_ARQ, [Text.Encoding]::UTF8))); exit $LASTEXITCODE"
set "ENGRAMA_INSTALADOR_SAIDA=%errorlevel%"
del "%ENGRAMA_INSTALADOR_ARQ%" >nul 2>&1
echo.
pause
exit /b %ENGRAMA_INSTALADOR_SAIDA%
