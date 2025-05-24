# Criar um arquivo PDF de teste para o processador
# Este script cria um PDF simples com conteúdo jurídico para testes

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
  
  # Adicionar um parágrafo com texto
  doc <- addParagraph(doc, 
    paste(
      "CAPÍTULO I - DAS DISPOSIÇÕES PRELIMINARES\n\n",
      "Art. 1º Esta Lei estabelece normas gerais sobre procedimentos de teste para documentos jurídicos.\n\n",
      "Parágrafo único. As disposições desta Lei aplicam-se a todos os procedimentos de teste.\n\n",
      "Art. 2º Para os fins desta Lei, considera-se:\n",
      "I - processamento: conjunto de operações automatizadas de texto;\n",
      "II - extração: obtenção de informações de documentos jurídicos;\n",
      "III - parsing: análise sintática do conteúdo textual para estruturação.\n\n",
      "Art. 3º Os princípios que regem esta Lei são:\n",
      "a) eficiência na extração de texto;\n",
      "b) fidelidade ao conteúdo original;\n",
      "c) integridade dos parágrafos e estrutura.[1]\n\n",
      "CAPÍTULO II - DOS PROCEDIMENTOS ESPECIAIS\n\n",
      "Art. 4º O processamento deve preservar a estrutura hierárquica do documento jurídico, mantendo a relação entre artigos, parágrafos, incisos e alíneas.\n\n",
      "§ 1º A conversão deve garantir que parágrafos lógicos sejam mantidos em uma única linha.\n\n",
      "§ 2º Referências cruzadas e citações legais devem ser preservadas conforme Lei nº 8.112/90 e CF/88 art. 5º.\n\n",
      "SEÇÃO I - DAS NOTAS DE RODAPÉ\n\n",
      "Art. 5º As notas de rodapé devem ser identificadas e processadas adequadamente[2], mantendo a referência ao texto original.\n\n",
      "------------------\n",
      "[1] Nota de rodapé 1: Esta é uma nota de rodapé de teste para demonstrar o processamento.\n",
      "[2] Nota de rodapé 2: Segunda nota para verificar como múltiplas notas são tratadas."
    )
  )
  
  # Salvar o documento
  writeDoc(doc, output_file)
  
  message("Arquivo de teste criado: ", output_file)
}

# Executar a função
createTestPDF()
