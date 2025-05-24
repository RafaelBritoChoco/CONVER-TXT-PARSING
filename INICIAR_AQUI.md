# Instruções Rápidas para Execução

## Passos para Começar

1. **Instale o R**:
   - Visite: https://cran.r-project.org/bin/windows/base/
   - Baixe a versão mais recente e execute o instalador
   - **IMPORTANTE**: Marque a opção "Add R to PATH" durante a instalação

2. **Verifique a instalação**:
   - Abra o PowerShell e digite: `R --version`
   - Você deve ver informações sobre a versão instalada

3. **Execute o programa**:
   - Coloque seu arquivo PDF na mesma pasta deste programa
   - Execute o arquivo `processar_pdf.bat` seguido do nome do seu PDF:
     ```
     .\processar_pdf.bat seu_documento.pdf
     ```

4. **Verifique o resultado**:
   - Um arquivo de texto será gerado na mesma pasta
   - O nome padrão será `seu_documento_processado.txt`

## Solução de Problemas

Se você encontrar o erro "R não foi encontrado":
- Certifique-se de que você marcou "Add R to PATH" durante a instalação
- Tente reiniciar o computador após a instalação do R
- Se o problema persistir, você pode editar o arquivo `processar_pdf.bat` para apontar diretamente para o executável R:
  ```
  REM Substituir a linha com "Rscript" por:
  "C:\Program Files\R\R-x.x.x\bin\Rscript.exe" pdfprocessor_enhanced.R ...
  ```
  (Substitua x.x.x pela versão do R que você instalou)
