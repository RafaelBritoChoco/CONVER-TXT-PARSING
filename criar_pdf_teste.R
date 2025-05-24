# Criar um arquivo PDF de teste para o processador
# Este script cria um PDF simples com conteúdo jurídico para testes
# Usa o pacote rmarkdown que é mais comum e geralmente já está instalado

# Verificar e instalar pacotes necessários
if (!requireNamespace("rmarkdown", quietly = TRUE)) {
  install.packages("rmarkdown")
}

# Criar conteúdo para o PDF
conteudo <- '
---
title: "Lei Nº 12.345 - DOCUMENTO DE TESTE"
output: pdf_document
---

## CAPÍTULO I - DAS DISPOSIÇÕES PRELIMINARES

**Art. 1º** Esta Lei estabelece normas gerais sobre procedimentos de teste para documentos jurídicos.

**Parágrafo único.** As disposições desta Lei aplicam-se a todos os procedimentos de teste.

**Art. 2º** Para os fins desta Lei, considera-se:

I - processamento: conjunto de operações automatizadas de texto;

II - extração: obtenção de informações de documentos jurídicos;

III - parsing: análise sintática do conteúdo textual para estruturação.

**Art. 3º** Os princípios que regem esta Lei são:

a) eficiência na extração de texto;

b) fidelidade ao conteúdo original;

c) integridade dos parágrafos e estrutura.[^1]

## CAPÍTULO II - DOS PROCEDIMENTOS ESPECIAIS

**Art. 4º** O processamento deve preservar a estrutura hierárquica do documento jurídico, mantendo a relação entre artigos, parágrafos, incisos e alíneas.

**§ 1º** A conversão deve garantir que parágrafos lógicos sejam mantidos em uma única linha.

**§ 2º** Referências cruzadas e citações legais devem ser preservadas conforme Lei nº 8.112/90 e CF/88 art. 5º.

## SEÇÃO I - DAS NOTAS DE RODAPÉ

**Art. 5º** As notas de rodapé devem ser identificadas e processadas adequadamente[^2], mantendo a referência ao texto original.

[^1]: Esta é uma nota de rodapé de teste para demonstrar o processamento.
[^2]: Segunda nota para verificar como múltiplas notas são tratadas.
'

# Salvar o conteúdo em um arquivo temporário
arquivo_rmd <- "documento_teste.Rmd"
writeLines(conteudo, arquivo_rmd)

# Renderizar para PDF
tryCatch({
  rmarkdown::render(arquivo_rmd, output_file = "documento_teste.pdf")
  cat("Arquivo PDF de teste criado com sucesso: documento_teste.pdf\n")
}, error = function(e) {
  cat("Erro ao criar PDF:", conditionMessage(e), "\n")
})

# Remover o arquivo temporário
file.remove(arquivo_rmd)
