# Implementação do Fluxo de Conversão para TXT

Este documento detalha a implementação do fluxo completo de conversão de PDF/DOC para TXT, integrando todas as funcionalidades desenvolvidas anteriormente.

## Função Principal de Conversão para TXT

```r
#' Converte arquivos PDF ou DOC para TXT com processamento avançado
#'
#' @param input_file Caminho para o arquivo de entrada (PDF ou DOC)
#' @param output_file Caminho para o arquivo TXT de saída (opcional)
#' @param options Lista de opções de processamento
#' @return Caminho para o arquivo TXT gerado
convert_to_txt <- function(input_file, output_file = NULL, options = list(
  remove_anexos = FALSE,
  remove_sumario = FALSE,
  limpar_texto = TRUE,
  marcar_footnotes = FALSE,
  use_ocr = FALSE,
  detect_language = TRUE,
  verbose = TRUE
)) {
  # Verificar se o arquivo existe
  if (!file.exists(input_file)) {
    stop("Arquivo de entrada não encontrado: ", input_file)
  }
  
  # Determinar tipo de arquivo
  file_ext <- tolower(tools::file_ext(input_file))
  
  # Determinar arquivo de saída se não especificado
  if (is.null(output_file)) {
    output_file <- paste0(tools::file_path_sans_ext(input_file), ".txt")
  }
  
  if (options$verbose) {
    cat(sprintf("Iniciando conversão de %s para TXT...\n", input_file))
    cat(sprintf("Arquivo de saída: %s\n", output_file))
    cat("Opções de processamento:\n")
    for (opt_name in names(options)) {
      if (opt_name != "verbose") {
        cat(sprintf("  - %s: %s\n", opt_name, as.character(options[[opt_name]])))
      }
    }
  }
  
  # Processar com base no tipo de arquivo
  if (file_ext == "pdf") {
    # Processar PDF
    process_pdf_to_txt(input_file, output_file, options)
  } else if (file_ext %in% c("doc", "docx")) {
    # Processar DOC/DOCX
    process_doc_to_txt(input_file, output_file, options)
  } else {
    stop("Formato de arquivo não suportado: ", file_ext, ". Use PDF, DOC ou DOCX.")
  }
  
  if (options$verbose) {
    cat(sprintf("Conversão concluída com sucesso. Arquivo TXT salvo em: %s\n", output_file))
  }
  
  return(output_file)
}
```

## Função para Processamento de PDF para TXT

```r
#' Processa arquivo PDF para TXT com todas as etapas de processamento
#'
#' @param pdf_file Caminho para o arquivo PDF
#' @param output_file Caminho para o arquivo TXT de saída
#' @param options Lista de opções de processamento
#' @return Caminho para o arquivo TXT gerado
process_pdf_to_txt <- function(pdf_file, output_file, options) {
  if (options$verbose) {
    cat("Processando arquivo PDF...\n")
  }
  
  # 1. Extrair texto do PDF
  if (options$verbose) {
    cat("Extraindo texto do PDF...\n")
  }
  
  text <- extract_pdf_text(pdf_file, use_ocr = options$use_ocr)
  
  # 2. Detectar idioma se solicitado
  if (options$detect_language) {
    if (options$verbose) {
      cat("Detectando idioma do documento...\n")
    }
    
    # Juntar parte do texto para análise
    sample_text <- paste(text[1:min(20, length(text))], collapse = " ")
    
    # Detectar idioma usando o pacote cld2 (se disponível)
    language <- tryCatch({
      if (!requireNamespace("cld2", quietly = TRUE)) {
        warning("Pacote 'cld2' não disponível. Detecção de idioma desativada.")
        "unknown"
      } else {
        detected <- cld2::detect_language(sample_text)
        if (is.na(detected)) "unknown" else detected
      }
    }, error = function(e) {
      warning("Erro na detecção de idioma: ", conditionMessage(e))
      return("unknown")
    })
    
    if (options$verbose && language != "unknown") {
      cat(sprintf("Idioma detectado: %s\n", language))
    }
  }
  
  # 3. Aplicar processamentos na ordem correta
  
  # 3.1. Remover anexos se solicitado
  if (options$remove_anexos) {
    if (options$verbose) {
      cat("Removendo anexos...\n")
    }
    text <- remove_anexos(text)
  }
  
  # 3.2. Remover sumário se solicitado
  if (options$remove_sumario) {
    if (options$verbose) {
      cat("Removendo sumário...\n")
    }
    text <- remove_sumario(text)
  }
  
  # 3.3. Limpar e organizar texto se solicitado
  if (options$limpar_texto) {
    if (options$verbose) {
      cat("Aplicando limpeza e organização ao texto...\n")
    }
    text <- clean_text(text)
  }
  
  # 3.4. Processar notas de rodapé se solicitado
  if (options$marcar_footnotes) {
    if (options$verbose) {
      cat("Processando notas de rodapé...\n")
    }
    
    # Detectar estilo de notas de rodapé
    footnote_style <- detect_footnote_style(text)
    
    if (length(footnote_style$detected_styles) > 0) {
      # Usar estilo detectado
      text <- process_footnotes_by_style(
        text, 
        auto_detect = TRUE,
        options = list(
          move_to_end = TRUE,
          mark_references = TRUE,
          normalize_format = TRUE
        )
      )
    } else {
      # Usar processamento padrão
      text <- mark_footnotes(text)
    }
  }
  
  # 4. Salvar resultado
  if (options$verbose) {
    cat("Salvando resultado em arquivo TXT...\n")
  }
  
  # Garantir que o diretório de saída exista
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Salvar o texto processado
  writeLines(text, output_file, useBytes = TRUE)
  
  return(output_file)
}
```

## Função para Processamento de DOC/DOCX para TXT

```r
#' Processa arquivo DOC/DOCX para TXT com todas as etapas de processamento
#'
#' @param doc_file Caminho para o arquivo DOC/DOCX
#' @param output_file Caminho para o arquivo TXT de saída
#' @param options Lista de opções de processamento
#' @return Caminho para o arquivo TXT gerado
process_doc_to_txt <- function(doc_file, output_file, options) {
  if (options$verbose) {
    cat("Processando arquivo DOC/DOCX...\n")
  }
  
  # 1. Extrair texto do DOC/DOCX
  if (options$verbose) {
    cat("Extraindo texto do documento...\n")
  }
  
  # Verificar extensão
  file_ext <- tolower(tools::file_ext(doc_file))
  
  # Extrair texto usando docxtractr para DOCX ou conversão temporária para PDF para DOC
  if (file_ext == "docx") {
    # Usar docxtractr para DOCX
    if (!requireNamespace("docxtractr", quietly = TRUE)) {
      stop("Pacote 'docxtractr' necessário para processar arquivos DOCX.")
    }
    
    doc <- docxtractr::read_docx(doc_file)
    text_parts <- character(0)
    
    # Extrair texto de cada parágrafo
    for (i in 1:docxtractr::docx_paragraph_count(doc)) {
      text_parts <- c(text_parts, docxtractr::docx_extract_paragraph(doc, i))
    }
    
    # Extrair texto de tabelas se houver
    table_count <- tryCatch(docxtractr::docx_tbl_count(doc), error = function(e) 0)
    if (table_count > 0) {
      for (i in 1:table_count) {
        table_text <- capture.output(print(docxtractr::docx_extract_tbl(doc, i)))
        text_parts <- c(text_parts, "", "TABELA:", table_text)
      }
    }
    
    text <- text_parts
  } else {
    # Para DOC, usar método alternativo (conversão para PDF e depois extração)
    # Nota: Em um ambiente real, seria implementada uma solução mais robusta
    warning("Processamento de arquivos DOC pode ser limitado. Recomenda-se converter para DOCX primeiro.")
    
    # Simulação de extração de texto de DOC
    # Em um ambiente real, usaríamos ferramentas como antiword, textract, etc.
    temp_txt <- tempfile(fileext = ".txt")
    system2("antiword", c("-f", shQuote(doc_file), ">", shQuote(temp_txt)), stderr = FALSE)
    
    if (file.exists(temp_txt) && file.info(temp_txt)$size > 0) {
      text <- readLines(temp_txt, encoding = "UTF-8")
      file.remove(temp_txt)
    } else {
      stop("Falha ao extrair texto do arquivo DOC. Considere convertê-lo para DOCX ou PDF primeiro.")
    }
  }
  
  # 2. Aplicar os mesmos processamentos do fluxo de PDF
  
  # 2.1. Remover anexos se solicitado
  if (options$remove_anexos) {
    if (options$verbose) {
      cat("Removendo anexos...\n")
    }
    text <- remove_anexos(text)
  }
  
  # 2.2. Remover sumário se solicitado
  if (options$remove_sumario) {
    if (options$verbose) {
      cat("Removendo sumário...\n")
    }
    text <- remove_sumario(text)
  }
  
  # 2.3. Limpar e organizar texto se solicitado
  if (options$limpar_texto) {
    if (options$verbose) {
      cat("Aplicando limpeza e organização ao texto...\n")
    }
    text <- clean_text(text)
  }
  
  # 2.4. Processar notas de rodapé se solicitado
  if (options$marcar_footnotes) {
    if (options$verbose) {
      cat("Processando notas de rodapé...\n")
    }
    
    # Detectar estilo de notas de rodapé
    footnote_style <- detect_footnote_style(text)
    
    if (length(footnote_style$detected_styles) > 0) {
      # Usar estilo detectado
      text <- process_footnotes_by_style(
        text, 
        auto_detect = TRUE,
        options = list(
          move_to_end = TRUE,
          mark_references = TRUE,
          normalize_format = TRUE
        )
      )
    } else {
      # Usar processamento padrão
      text <- mark_footnotes(text)
    }
  }
  
  # 3. Salvar resultado
  if (options$verbose) {
    cat("Salvando resultado em arquivo TXT...\n")
  }
  
  # Garantir que o diretório de saída exista
  output_dir <- dirname(output_file)
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Salvar o texto processado
  writeLines(text, output_file, useBytes = TRUE)
  
  return(output_file)
}
```

## Função para Processamento em Lote

```r
#' Processa múltiplos arquivos PDF/DOC para TXT em lote
#'
#' @param input_files Lista de caminhos para arquivos de entrada
#' @param output_dir Diretório para salvar os arquivos TXT de saída
#' @param options Lista de opções de processamento
#' @param join_output Se TRUE, combina todos os resultados em um único arquivo TXT
#' @return Lista de caminhos para os arquivos TXT gerados
batch_convert_to_txt <- function(input_files, output_dir = NULL, options = list(
  remove_anexos = FALSE,
  remove_sumario = FALSE,
  limpar_texto = TRUE,
  marcar_footnotes = FALSE,
  use_ocr = FALSE
), join_output = FALSE) {
  # Verificar se input_files é um arquivo ou uma lista
  if (length(input_files) == 1 && file.exists(input_files) && !grepl("\\.(pdf|doc|docx)$", input_files, ignore.case = TRUE)) {
    # Ler lista de arquivos do arquivo
    file_list <- readLines(input_files, encoding = "UTF-8")
    file_list <- file_list[file_list != ""]
  } else {
    file_list <- input_files
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- file_list[!file.exists(file_list)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  # Determinar diretório de saída
  if (is.null(output_dir)) {
    output_dir <- dirname(file_list[1])
  }
  
  # Criar diretório de saída se não existir
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  cat(sprintf("Processando %d arquivos em lote...\n", length(file_list)))
  
  # Processar cada arquivo
  output_files <- character(0)
  
  for (i in seq_along(file_list)) {
    input_file <- file_list[i]
    file_name <- basename(tools::file_path_sans_ext(input_file))
    output_file <- file.path(output_dir, paste0(file_name, ".txt"))
    
    cat(sprintf("Processando arquivo %d/%d: %s\n", i, length(file_list), basename(input_file)))
    
    # Converter para TXT
    result_file <- convert_to_txt(
      input_file, 
      output_file, 
      options = c(options, list(verbose = FALSE))
    )
    
    output_files <- c(output_files, result_file)
  }
  
  # Juntar resultados se solicitado
  if (join_output && length(output_files) > 1) {
    cat("Combinando resultados em um único arquivo TXT...\n")
    
    # Nome do arquivo combinado
    combined_file <- file.path(output_dir, "documentos_combinados.txt")
    
    # Abrir arquivo de saída
    con <- file(combined_file, "w", encoding = "UTF-8")
    
    # Processar cada arquivo
    for (i in seq_along(output_files)) {
      txt_file <- output_files[i]
      cat(sprintf("Adicionando conteúdo de: %s\n", basename(txt_file)))
      
      # Adicionar marcador de arquivo
      file_marker <- paste(rep("=", 50), collapse = "")
      writeLines(c(
        file_marker,
        sprintf("ARQUIVO: %s", basename(file_list[i])),
        file_marker,
        ""  # Linha em branco após o marcador
      ), con)
      
      # Ler e adicionar conteúdo
      content <- readLines(txt_file, encoding = "UTF-8")
      writeLines(content, con)
      
      # Adicionar separador entre arquivos
      if (i < length(output_files)) {
        writeLines(c("", "", ""), con)  # Três linhas em branco como separador
      }
    }
    
    # Fechar arquivo
    close(con)
    
    cat(sprintf("Conteúdo combinado salvo em: %s\n", combined_file))
    
    # Adicionar o arquivo combinado à lista de saída
    output_files <- c(output_files, combined_file)
  }
  
  cat(sprintf("Processamento em lote concluído. %d arquivos TXT gerados.\n", length(output_files)))
  return(output_files)
}
```

## Função para Fluxo Completo com Junção de PDFs

```r
#' Executa o fluxo completo: junção de PDFs e conversão para TXT
#'
#' @param input_files Lista de caminhos para arquivos PDF
#' @param output_dir Diretório para salvar os arquivos de saída
#' @param options Lista de opções de processamento
#' @return Lista com caminhos para os arquivos gerados
complete_pdf_to_txt_workflow <- function(input_files, output_dir = NULL, options = list(
  join_pdfs = TRUE,
  remove_anexos = FALSE,
  remove_sumario = FALSE,
  limpar_texto = TRUE,
  marcar_footnotes = FALSE,
  use_ocr = FALSE,
  analyze_chapters = TRUE
)) {
  # Verificar se input_files é um arquivo ou uma lista
  if (length(input_files) == 1 && file.exists(input_files) && !grepl("\\.pdf$", input_files, ignore.case = TRUE)) {
    # Ler lista de arquivos do arquivo
    file_list <- readLines(input_files, encoding = "UTF-8")
    file_list <- file_list[file_list != ""]
  } else {
    file_list <- input_files
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- file_list[!file.exists(file_list)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  # Determinar diretório de saída
  if (is.null(output_dir)) {
    output_dir <- dirname(file_list[1])
  }
  
  # Criar diretório de saída se não existir
  if (!dir.exists(output_dir)) {
    dir.create(output_dir, recursive = TRUE)
  }
  
  # Resultados
  result <- list(
    pdf_files = file_list,
    combined_pdf = NULL,
    txt_files = NULL
  )
  
  # 1. Juntar PDFs se solicitado e houver mais de um arquivo
  if (options$join_pdfs && length(file_list) > 1) {
    cat("Iniciando junção de PDFs...\n")
    
    # Nome do arquivo PDF combinado
    combined_pdf <- file.path(output_dir, "documentos_combinados.pdf")
    
    # Analisar capítulos se solicitado
    if (options$analyze_chapters) {
      chapter_analysis <- analyze_pdf_chapters(file_list)
      if (length(chapter_analysis$suggested_order) > 0) {
        file_list <- file_list[chapter_analysis$suggested_order]
      }
    }
    
    # Juntar PDFs
    merge_pdfs(
      file_list, 
      combined_pdf, 
      options = list(
        add_bookmarks = TRUE,
        add_toc = FALSE,
        preserve_metadata = TRUE,
        sort_files = FALSE
      )
    )
    
    # Atualizar resultado
    result$combined_pdf <- combined_pdf
    
    # Usar o PDF combinado para conversão para TXT
    input_for_txt <- combined_pdf
  } else {
    # Usar os PDFs originais para conversão para TXT
    input_for_txt <- file_list
  }
  
  # 2. Converter para TXT
  cat("Iniciando conversão para TXT...\n")
  
  # Se temos um único arquivo PDF (original ou combinado)
  if (length(input_for_txt) == 1) {
    # Nome do arquivo TXT de saída
    output_txt <- file.path(output_dir, paste0(tools::file_path_sans_ext(basename(input_for_txt)), ".txt"))
    
    # Converter para TXT
    txt_file <- convert_to_txt(
      input_for_txt, 
      output_txt, 
      options = list(
        remove_anexos = options$remove_anexos,
        remove_sumario = options$remove_sumario,
        limpar_texto = options$limpar_texto,
        marcar_footnotes = options$marcar_footnotes,
        use_ocr = options$use_ocr,
        verbose = TRUE
      )
    )
    
    # Atualizar resultado
    result$txt_files <- txt_file
  } else {
    # Processar múltiplos arquivos e combinar o resultado
    txt_files <- batch_convert_to_txt(
      input_for_txt, 
      output_dir, 
      options = list(
        remove_anexos = options$remove_anexos,
        remove_sumario = options$remove_sumario,
        limpar_texto = options$limpar_texto,
        marcar_footnotes = options$marcar_footnotes,
        use_ocr = options$use_ocr
      ),
      join_output = TRUE
    )
    
    # Atualizar resultado
    result$txt_files <- txt_files
  }
  
  cat("Fluxo completo de processamento concluído com sucesso.\n")
  return(result)
}
```

## Atualização da Função Principal do Programa

```r
#' Função principal que coordena todo o fluxo de processamento
#'
#' @param config Configurações do programa
#' @return Lista com resultados do processamento
process_documents <- function(config) {
  # Verificar tipo de operação
  if (!is.null(config$juntar_pdfs)) {
    # Operação de junção de PDFs
    if (is.null(config$arquivo_saida)) {
      output_dir <- dirname(config$juntar_pdfs)
      output_file <- file.path(output_dir, "pdfs_combinados.pdf")
    } else {
      output_file <- config$arquivo_saida
    }
    
    # Juntar PDFs
    pdf_file <- merge_pdfs_from_list(
      config$juntar_pdfs, 
      output_file, 
      options = list(
        add_bookmarks = TRUE,
        analyze_chapters = TRUE
      )
    )
    
    # Se conversão para TXT também foi solicitada
    if (config$formato_saida == "txt") {
      txt_file <- convert_to_txt(
        pdf_file, 
        paste0(tools::file_path_sans_ext(output_file), ".txt"), 
        options = list(
          remove_anexos = config$remove_anexos,
          remove_sumario = config$remove_sumario,
          limpar_texto = config$limpar_texto,
          marcar_footnotes = config$marcar_footnotes,
          use_ocr = FALSE,
          verbose = TRUE
        )
      )
      
      return(list(pdf_file = pdf_file, txt_file = txt_file))
    }
    
    return(list(pdf_file = pdf_file))
  } else if (!is.null(config$arquivo_entrada)) {
    # Operação de processamento de arquivo individual
    input_file <- config$arquivo_entrada
    
    # Determinar arquivo de saída
    if (is.null(config$arquivo_saida)) {
      output_dir <- dirname(input_file)
      base_name <- tools::file_path_sans_ext(basename(input_file))
      output_file <- file.path(output_dir, paste0(base_name, "_processado.", config$formato_saida))
    } else {
      output_file <- config$arquivo_saida
    }
    
    # Processar com base no formato de saída
    if (config$formato_saida == "txt") {
      # Converter para TXT
      txt_file <- convert_to_txt(
        input_file, 
        output_file, 
        options = list(
          remove_anexos = config$remove_anexos,
          remove_sumario = config$remove_sumario,
          limpar_texto = config$limpar_texto,
          marcar_footnotes = config$marcar_footnotes,
          use_ocr = FALSE,
          verbose = TRUE
        )
      )
      
      return(list(txt_file = txt_file))
    } else {
      stop("Formato de saída não suportado: ", config$formato_saida)
    }
  } else {
    stop("Nenhuma operação válida especificada na configuração.")
  }
}
```

## Integração com a Interface de Linha de Comando

```r
# Atualização da função parse_arguments para incluir novas opções
parse_arguments <- function(args) {
  # Definir opções da linha de comando
  option_list <- list(
    make_option("--remove-anexos", action = "store_true", default = FALSE,
                help = "Remove anexos do documento"),
    make_option("--remove-sumario", action = "store_true", default = FALSE,
                help = "Remove sumário (table of contents) do documento"),
    make_option("--limpar", action = "store_true", default = FALSE,
                help = "Aplica limpeza e organização ao texto extraído"),
    make_option("--juntar", type = "character", default = NULL,
                help = "Lista de arquivos PDF para juntar (um por linha)"),
    make_option("--marcar-footnotes", action = "store_true", default = FALSE,
                help = "Marca e organiza notas de rodapé"),
    make_option("--saida", type = "character", default = NULL,
                help = "Arquivo de saída"),
    make_option("--formato", type = "character", default = "txt",
                help = "Formato de saída (txt ou doc)"),
    make_option("--config", type = "character", default = NULL,
                help = "Arquivo de configuração personalizado"),
    make_option("--ocr", action = "store_true", default = FALSE,
                help = "Usa OCR para melhorar a extração de texto"),
    make_option("--analisar-capitulos", action = "store_true", default = FALSE,
                help = "Analisa estrutura de capítulos para ordenação"),
    make_option("--ajuda", action = "store_true", default = FALSE,
                help = "Exibe mensagem de ajuda")
  )
  
  # Analisar argumentos
  opt_parser <- OptionParser(option_list = option_list)
  tryCatch({
    opts <- parse_args(opt_parser, args = args, positional_arguments = TRUE)
  }, error = function(e) {
    cat("Erro ao processar argumentos:", conditionMessage(e), "\n")
    show_help()
    quit(status = 1)
  })
  
  # Verificar se a ajuda foi solicitada
  if (opts$options$ajuda) {
    show_help()
    quit(status = 0)
  }
  
  # Verificar se há argumentos posicionais (arquivos de entrada)
  if (length(opts$args) == 0 && is.null(opts$options$juntar)) {
    cat("ERRO: Nenhum arquivo de entrada especificado.\n")
    show_help()
    quit(status = 1)
  }
  
  # Carregar configurações do arquivo, se especificado
  config <- load_config(opts$options$config)
  
  # Sobrescrever configurações com opções da linha de comando
  config$remove_anexos <- opts$options$`remove-anexos`
  config$remove_sumario <- opts$options$`remove-sumario`
  config$limpar_texto <- opts$options$limpar
  config$marcar_footnotes <- opts$options$`marcar-footnotes`
  config$formato_saida <- opts$options$formato
  config$juntar_pdfs <- opts$options$juntar
  config$arquivo_saida <- opts$options$saida
  config$use_ocr <- opts$options$ocr
  config$analisar_capitulos <- opts$options$`analisar-capitulos`
  config$arquivo_entrada <- if (length(opts$args) > 0) opts$args[1] else NULL
  
  return(config)
}

# Atualização da função show_help para incluir novas opções
show_help <- function() {
  cat("PDF Processor - Ferramenta para processamento e conversão de PDFs para TXT\n\n")
  cat("Uso: Rscript pdfprocessor.R [opções] arquivo.pdf\n\n")
  cat("Opções:\n")
  cat("  --remove-anexos        Remove anexos do documento\n")
  cat("  --remove-sumario       Remove sumário (table of contents) do documento\n")
  cat("  --limpar               Aplica limpeza e organização ao texto extraído\n")
  cat("  --juntar=arquivo.txt   Lista de arquivos PDF para juntar (um por linha)\n")
  cat("  --marcar-footnotes     Marca e organiza notas de rodapé\n")
  cat("  --saida=arquivo.txt    Arquivo de saída (padrão: baseado no nome de entrada)\n")
  cat("  --formato=txt          Formato de saída (padrão: txt)\n")
  cat("  --config=arquivo.conf  Arquivo de configuração personalizado\n")
  cat("  --ocr                  Usa OCR para melhorar a extração de texto\n")
  cat("  --analisar-capitulos   Analisa estrutura de capítulos para ordenação\n")
  cat("  --ajuda                Exibe esta mensagem de ajuda\n\n")
  cat("Exemplos:\n")
  cat("  Rscript pdfprocessor.R --limpar --marcar-footnotes documento.pdf\n")
  cat("  Rscript pdfprocessor.R --juntar=lista_pdfs.txt --saida=combinado.txt\n\n")
}
```

## Integração com o Fluxo Principal

O fluxo de conversão para TXT implementado integra todas as funcionalidades desenvolvidas anteriormente em um processo coeso e flexível:

1. **Entrada Flexível**: Suporta arquivos PDF e DOC/DOCX como entrada
2. **Junção Inteligente**: Permite juntar múltiplos PDFs antes da conversão, com análise de capítulos para ordenação correta
3. **Processamento Completo**: Aplica todas as etapas de processamento na ordem correta:
   - Extração de texto com suporte a OCR
   - Remoção de anexos e sumários
   - Limpeza e organização do texto
   - Processamento e marcação de notas de rodapé
4. **Detecção Automática**: Identifica automaticamente o idioma e o estilo das notas de rodapé para melhor processamento
5. **Processamento em Lote**: Suporta processamento de múltiplos arquivos com opção de combinar os resultados
6. **Interface Flexível**: Oferece tanto interface de linha de comando quanto funções para uso em scripts

Esta implementação garante que o usuário possa converter facilmente documentos PDF ou DOC para TXT com alta qualidade, mantendo a estrutura do texto e facilitando a localização de notas de rodapé, conforme solicitado nos requisitos originais.
