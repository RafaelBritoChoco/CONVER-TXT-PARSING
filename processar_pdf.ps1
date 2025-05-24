# Script PowerShell para executar o processador de PDF
# Salve este arquivo como "processar_pdf.ps1"

Write-Host "PDF Processor para Documentos Juridicos" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
Write-Host ""

# Verificar se R está instalado
$rPath = $null

# Tentar encontrar R no PATH
try {
    $rPath = (Get-Command R -ErrorAction Stop).Source
} catch {
    # Tentar encontrar R em locais padrão
    $possiblePaths = @(
        "C:\Program Files\R\R-*\bin\R.exe",
        "C:\Program Files\R\R-*\bin\x64\R.exe"
    )
    
    foreach ($path in $possiblePaths) {
        $foundPaths = Resolve-Path $path -ErrorAction SilentlyContinue
        if ($foundPaths) {
            $rPath = $foundPaths[-1].Path # Pegar a versão mais recente
            break
        }
    }
}

if (-not $rPath) {
    Write-Host "ERRO: R não foi encontrado. Por favor, instale o R primeiro." -ForegroundColor Red
    Write-Host "Consulte o arquivo installation_guide.md para instruções." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    exit 1
}

# Verificar se há um arquivo PDF especificado
if (-not $args[0]) {
    Write-Host "Uso: .\processar_pdf.ps1 arquivo.pdf [opcoes adicionais]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Exemplos:" -ForegroundColor Cyan
    Write-Host "  .\processar_pdf.ps1 documento.pdf"
    Write-Host "  .\processar_pdf.ps1 documento.pdf --formato=json"
    Write-Host ""
    Write-Host "Para ver todas as opcoes:" -ForegroundColor Cyan
    Write-Host "  .\processar_pdf.ps1 --ajuda"
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    exit 1
}

# Verificar se é pedido de ajuda
if ($args[0] -eq "--ajuda") {
    & $rPath "pdfprocessor_enhanced.R" --ajuda
    Write-Host ""
    Read-Host "Pressione ENTER para sair"
    exit 0
}

# Construir o comando base
$rscriptPath = $rPath -replace "R.exe$", "Rscript.exe"
$comando = "$rscriptPath pdfprocessor_enhanced.R --modo-juridico --preservar-estrutura --limpar --marcar-footnotes"

# Adicionar o arquivo PDF (primeiro argumento)
$comando += " `"$($args[0])`""

# Adicionar opções adicionais (a partir do segundo argumento)
if ($args.Count -gt 1) {
    for ($i = 1; $i -lt $args.Count; $i++) {
        $comando += " $($args[$i])"
    }
}

# Executar o comando
Write-Host "Executando: $comando" -ForegroundColor Gray
Write-Host ""
Write-Host "Processando documento, por favor aguarde..." -ForegroundColor Yellow
Write-Host ""

try {
    Invoke-Expression $comando
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "Processamento concluido com sucesso!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "ERRO: O processamento falhou com codigo $LASTEXITCODE." -ForegroundColor Red
    }
} catch {
    Write-Host ""
    Write-Host "ERRO durante a execução: $_" -ForegroundColor Red
}

Write-Host ""
Read-Host "Pressione ENTER para sair"
