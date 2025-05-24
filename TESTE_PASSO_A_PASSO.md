# Guia Passo a Passo para Testar o Programa

## 1. Instalação do R e Pacotes Necessários

### Instalar o R
1. Baixe o R do site oficial: https://cran.r-project.org/bin/windows/base/
2. Execute o instalador e **marque a opção para adicionar R ao PATH do sistema**
3. Complete a instalação com as opções padrão

### Verificar a Instalação
1. Abra o PowerShell ou Prompt de Comando
2. Digite `R --version` e pressione Enter
3. Você deve ver informações sobre a versão do R instalada

## 2. Criar um PDF de Teste (Opcional)

Se você já tem um documento PDF jurídico para testar, pode pular esta etapa. Caso contrário:

1. Abra o PowerShell na pasta do programa
2. Execute o comando:
   ```
   R -f criar_teste.R
   ```
3. Isso criará um arquivo chamado `documento_teste.pdf` com conteúdo jurídico para testes

## 3. Executar o Processador de PDF

### Usando o Script Batch
1. Abra o Prompt de Comando na pasta do programa
2. Execute o comando:
   ```
   processar_pdf.bat documento_teste.pdf
   ```
   (ou substitua por seu próprio arquivo PDF)

### Usando o Script PowerShell (Alternativa)
1. Abra o PowerShell na pasta do programa
2. Execute o comando:
   ```
   .\processar_pdf.ps1 documento_teste.pdf
   ```

## 4. Verificar os Resultados

1. Após o processamento, será gerado um arquivo de texto com o mesmo nome do PDF e o sufixo "_processado"
2. Abra este arquivo para verificar se:
   - Os parágrafos estão em linhas únicas
   - A estrutura jurídica (artigos, parágrafos, etc.) está preservada
   - As notas de rodapé estão corretamente marcadas

## 5. Experimentar Diferentes Opções

Você pode testar diferentes configurações:

### Formato JSON
```
processar_pdf.bat documento_teste.pdf --formato=json
```

### Sem Marcar Notas de Rodapé
```
processar_pdf.bat documento_teste.pdf --modo-juridico --preservar-estrutura --limpar
```

### Usando Arquivo de Configuração
```
processar_pdf.bat documento_teste.pdf --config=config_juridico.conf
```

## Solução de Problemas

### Se o R não for encontrado:
- Verifique se você marcou "Add R to PATH" durante a instalação
- Tente reiniciar o computador
- Edite o arquivo batch para apontar diretamente para o executável R

### Se os pacotes não instalarem automaticamente:
1. Abra o R ou RStudio
2. Execute o seguinte comando para instalar os pacotes manualmente:
   ```r
   install.packages(c("pdftools", "tesseract", "stringr", "stringi", "qpdf", 
                   "docxtractr", "optparse", "data.table", "magrittr", 
                   "parallel", "xml2", "jsonlite"))
   ```

### Se ocorrerem erros no processamento:
- Verifique se o arquivo PDF não está protegido ou danificado
- Tente com um PDF mais simples primeiro
- Consulte o log de erros para informações mais detalhadas
