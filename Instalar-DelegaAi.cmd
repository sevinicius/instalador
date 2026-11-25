@echo off
rem DelegaAí + Engrama - instalador para Windows (clique duplo).
rem Baixa o instalar.ps1 da última release de github.com/sevinicius/instalador e roda.
chcp 65001 >nul
title Instalando o DelegaAi + Engrama
set "ARQ=%TEMP%\instalar-delegaai.ps1"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/sevinicius/instalador/releases/latest/download/instalar.ps1' -OutFile '%ARQ%'"
if errorlevel 1 (
  echo.
  echo Nao consegui baixar o instalador. Confira a internet e tente de novo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%ARQ%"
echo.
pause
