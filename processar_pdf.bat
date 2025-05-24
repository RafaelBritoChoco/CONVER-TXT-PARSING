REM Script para facilitar a execução do processador de PDF jurídico
REM Salve este arquivo como "processar_pdf.bat" para Windows

@echo off
echo PDF Processor para Documentos Juridicos
echo =======================================
echo.

REM Verificar se R está instalado
where R >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERRO: R nao foi encontrado. Por favor, instale o R primeiro.
    echo Consulte o arquivo installation_guide.md para instruções.
    echo.
    pause
    exit /b 1
)

REM Verificar se há um arquivo PDF especificado
if "%~1"=="" (
    echo Uso: processar_pdf.bat arquivo.pdf [opcoes adicionais]
    echo.
    echo Exemplos:
    echo   processar_pdf.bat documento.pdf
    echo   processar_pdf.bat documento.pdf --formato=json
    echo.
    echo Para ver todas as opcoes:
    echo   processar_pdf.bat --ajuda
    echo.
    pause
    exit /b 1
)

REM Verificar se é pedido de ajuda
if "%~1"=="--ajuda" (
    Rscript pdfprocessor_enhanced.R --ajuda
    echo.
    pause
    exit /b 0
)

REM Montar o comando com as opções padrão + opções do usuário
set COMANDO="C:\Program Files\R\R-4.5.0\bin\x64\Rscript.exe" pdfprocessor_enhanced.R --modo-juridico --preservar-estrutura --limpar --marcar-footnotes

REM Adicionar o arquivo PDF (primeiro argumento)
set COMANDO=%COMANDO% "%~1"

REM Adicionar opções adicionais (a partir do segundo argumento)
shift
:loop
if "%~1"=="" goto execute
set COMANDO=%COMANDO% %~1
shift
goto loop

:execute
echo Executando: %COMANDO%
echo.
echo Processando documento, por favor aguarde...
echo.

REM Executar o comando
%COMANDO%

echo.
if %ERRORLEVEL% EQU 0 (
    echo Processamento concluido com sucesso!
) else (
    echo ERRO: O processamento falhou com codigo %ERRORLEVEL%.
)

echo.
pause
