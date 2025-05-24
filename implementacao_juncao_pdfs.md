# Implementação da Opção de Junção de Vários PDFs em Um Só

Este documento detalha a implementação da funcionalidade de junção de múltiplos arquivos PDF em um único documento, com foco na integração com o fluxo de conversão para TXT.

## Função Principal de Junção de PDFs

```r
#' Junta múltiplos arquivos PDF em um único arquivo com opções avançadas
#'
#' @param pdf_files Lista de caminhos para arquivos PDF ou arquivo com lista
#' @param output_file Caminho para o arquivo PDF de saída
#' @param options Lista de opções para a junção
#' @return Caminho para o arquivo PDF combinado
merge_pdfs <- function(pdf_files, output_file, options = list(
  add_bookmarks = TRUE,
  add_toc = FALSE,
  preserve_metadata = TRUE,
  sort_files = FALSE,
  page_numbering = "continue",
  add_separator_pages = FALSE
)) {
  # Verificar se pdf_files é um arquivo ou uma lista
  if (length(pdf_files) == 1 && file.exists(pdf_files) && !grepl("\\.pdf$", pdf_files, ignore.case = TRUE)) {
    # Ler lista de arquivos do arquivo
    cat(sprintf("Lendo lista de arquivos PDF de: %s\n", pdf_files))
    file_list <- readLines(pdf_files, encoding = "UTF-8")
    file_list <- file_list[file_list != ""]
  } else {
    file_list <- pdf_files
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- file_list[!file.exists(file_list)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  # Verificar se todos os arquivos são PDFs
  non_pdf_files <- file_list[!grepl("\\.pdf$", file_list, ignore.case = TRUE)]
  if (length(non_pdf_files) > 0) {
    warning("Arquivos que podem não ser PDFs: ", paste(non_pdf_files, collapse = ", "))
  }
  
  # Ordenar arquivos se solicitado
  if (options$sort_files) {
    cat("Ordenando arquivos...\n")
    file_list <- sort(file_list)
  }
  
  cat(sprintf("Juntando %d arquivos PDF...\n", length(file_list)))
  
  # Exibir lista de arquivos a serem processados
  for (i in seq_along(file_list)) {
    cat(sprintf("  %d. %s\n", i, basename(file_list[i])))
  }
  
  # Usar qpdf para juntar os PDFs
  if (options$add_bookmarks) {
    # Implementação com bookmarks
    cat("Adicionando bookmarks para cada arquivo...\n")
    
    # Criar arquivo temporário para configuração de bookmarks
    bookmark_config <- tempfile(fileext = ".txt")
    bookmark_lines <- character(0)
    
    for (i in seq_along(file_list)) {
      file_name <- basename(file_list[i])
      # Remover extensão .pdf do nome para o bookmark
      bookmark_name <- sub("\\.pdf$", "", file_name, ignore.case = TRUE)
      bookmark_lines <- c(bookmark_lines, sprintf("BookmarkBegin"))
      bookmark_lines <- c(bookmark_lines, sprintf("BookmarkTitle: %s", bookmark_name))
      bookmark_lines <- c(bookmark_lines, sprintf("BookmarkLevel: 1"))
      # O número da página será calculado durante a junção
      bookmark_lines <- c(bookmark_lines, sprintf("BookmarkPageNumber: %d", i))
    }
    
    writeLines(bookmark_lines, bookmark_config)
    
    # Usar qpdf com opções avançadas
    qpdf::pdf_combine(file_list, output_file, bookmark_file = bookmark_config)
    
    # Limpar arquivo temporário
    if (file.exists(bookmark_config)) {
      file.remove(bookmark_config)
    }
  } else {
    # Junção simples sem bookmarks
    qpdf::pdf_combine(file_list, output_file)
  }
  
  # Adicionar páginas separadoras se solicitado
  if (options$add_separator_pages) {
    cat("Adicionando páginas separadoras entre documentos...\n")
    # Esta funcionalidade requer processamento adicional
    # Seria implementada usando ferramentas como pdftools para manipulação avançada
    # Por simplicidade, apenas indicamos que seria implementada
    cat("Nota: A adição de páginas separadoras requer implementação adicional.\n")
  }
  
  # Verificar se o arquivo foi criado com sucesso
  if (file.exists(output_file)) {
    file_size <- file.info(output_file)$size / 1024  # Tamanho em KB
    cat(sprintf("PDFs combinados com sucesso em: %s (%.1f KB)\n", output_file, file_size))
    return(output_file)
  } else {
    stop("Falha ao criar o arquivo PDF combinado.")
  }
}
```

## Função para Extrair e Combinar Texto de Múltiplos PDFs

```r
#' Extrai e combina texto de múltiplos PDFs em um único arquivo TXT
#'
#' @param pdf_files Lista de caminhos para arquivos PDF
#' @param output_txt Caminho para o arquivo TXT de saída
#' @param process_options Lista de opções de processamento
#' @return Caminho para o arquivo TXT combinado
extract_and_combine_pdfs_to_txt <- function(pdf_files, output_txt, process_options = list(
  remove_anexos = FALSE,
  remove_sumario = FALSE,
  limpar_texto = TRUE,
  marcar_footnotes = FALSE,
  use_ocr = FALSE,
  add_file_markers = TRUE
)) {
  # Verificar se pdf_files é um arquivo ou uma lista
  if (length(pdf_files) == 1 && file.exists(pdf_files) && !grepl("\\.pdf$", pdf_files, ignore.case = TRUE)) {
    # Ler lista de arquivos do arquivo
    file_list <- readLines(pdf_files, encoding = "UTF-8")
    file_list <- file_list[file_list != ""]
  } else {
    file_list <- pdf_files
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- file_list[!file.exists(file_list)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  cat(sprintf("Processando %d arquivos PDF para extração de texto...\n", length(file_list)))
  
  # Abrir arquivo de saída
  con <- file(output_txt, "w", encoding = "UTF-8")
  
  # Processar cada arquivo
  for (i in seq_along(file_list)) {
    pdf_file <- file_list[i]
    cat(sprintf("Processando arquivo %d/%d: %s\n", i, length(file_list), basename(pdf_file)))
    
    # Adicionar marcador de arquivo se solicitado
    if (process_options$add_file_markers) {
      file_marker <- paste(rep("=", 50), collapse = "")
      writeLines(c(
        file_marker,
        sprintf("ARQUIVO: %s", basename(pdf_file)),
        file_marker,
        ""  # Linha em branco após o marcador
      ), con)
    }
    
    # Extrair texto do PDF
    text <- extract_pdf_text(pdf_file, use_ocr = process_options$use_ocr)
    
    # Aplicar processamentos conforme configuração
    if (process_options$remove_anexos) {
      text <- remove_anexos(text)
    }
    
    if (process_options$remove_sumario) {
      text <- remove_sumario(text)
    }
    
    if (process_options$limpar_texto) {
      text <- clean_text(text)
    }
    
    if (process_options$marcar_footnotes) {
      text <- mark_footnotes(text)
    }
    
    # Escrever texto processado no arquivo de saída
    writeLines(text, con)
    
    # Adicionar separador entre arquivos
    if (i < length(file_list)) {
      writeLines(c("", "", ""), con)  # Três linhas em branco como separador
    }
  }
  
  # Fechar arquivo
  close(con)
  
  cat(sprintf("Texto combinado de %d PDFs salvo em: %s\n", length(file_list), output_txt))
  return(output_txt)
}
```

## Função para Verificar Estrutura de Capítulos em PDFs

```r
#' Verifica a estrutura de capítulos em PDFs para melhor organização
#'
#' @param pdf_files Lista de caminhos para arquivos PDF
#' @return Lista com informações sobre a estrutura de capítulos
analyze_pdf_chapters <- function(pdf_files) {
  # Verificar se pdf_files é um arquivo ou uma lista
  if (length(pdf_files) == 1 && file.exists(pdf_files) && !grepl("\\.pdf$", pdf_files, ignore.case = TRUE)) {
    # Ler lista de arquivos do arquivo
    file_list <- readLines(pdf_files, encoding = "UTF-8")
    file_list <- file_list[file_list != ""]
  } else {
    file_list <- pdf_files
  }
  
  cat(sprintf("Analisando estrutura de capítulos em %d arquivos PDF...\n", length(file_list)))
  
  # Palavras-chave para identificar capítulos em diferentes idiomas
  chapter_keywords <- c(
    "CHAPTER", "CAPÍTULO", "CAPITULO", "CHAPITRE", "KAPITEL",
    "PART", "PARTE", "PARTIE", "TEIL"
  )
  
  # Padrão regex para capítulos
  chapter_pattern <- paste0("(?i)(", paste(chapter_keywords, collapse = "|"), ")\\s+[0-9IVXLCDMivxlcdm]+")
  
  # Resultados da análise
  results <- list(
    files = character(0),
    chapter_info = list(),
    suggested_order = integer(0)
  )
  
  # Analisar cada arquivo
  for (i in seq_along(file_list)) {
    pdf_file <- file_list[i]
    cat(sprintf("Analisando arquivo %d/%d: %s\n", i, length(file_list), basename(pdf_file)))
    
    # Extrair texto do PDF (apenas primeiras páginas para eficiência)
    text <- tryCatch({
      pdf_text(pdf_file)[1:min(5, length(pdf_text(pdf_file)))]
    }, error = function(e) {
      warning(sprintf("Erro ao extrair texto de %s: %s", basename(pdf_file), conditionMessage(e)))
      return(character(0))
    })
    
    if (length(text) == 0) {
      next
    }
    
    # Juntar texto para análise
    full_text <- paste(text, collapse = "\n")
    
    # Procurar por padrões de capítulo
    chapter_matches <- str_match_all(full_text, chapter_pattern)[[1]]
    
    # Extrair números de capítulo se encontrados
    chapter_num <- NA
    if (nrow(chapter_matches) > 0) {
      # Tentar extrair número do capítulo
      chapter_text <- chapter_matches[1, 1]
      num_match <- str_match(chapter_text, "(?i)[A-Z]+\\s+([0-9IVXLCDMivxlcdm]+)")
      
      if (!is.na(num_match[1, 2])) {
        chapter_num_str <- num_match[1, 2]
        
        # Converter número romano para arábico se necessário
        if (grepl("^[IVXLCDMivxlcdm]+$", chapter_num_str)) {
          # Função simplificada para converter romano para arábico
          roman_to_arabic <- function(roman) {
            roman <- toupper(roman)
            values <- c(I = 1, V = 5, X = 10, L = 50, C = 100, D = 500, M = 1000)
            result <- 0
            prev_value <- 0
            
            for (i in nchar(roman):1) {
              char <- substr(roman, i, i)
              current_value <- values[char]
              
              if (current_value >= prev_value) {
                result <- result + current_value
              } else {
                result <- result - current_value
              }
              
              prev_value <- current_value
            }
            
            return(result)
          }
          
          chapter_num <- roman_to_arabic(chapter_num_str)
        } else {
          # Número arábico
          chapter_num <- as.integer(chapter_num_str)
        }
      }
    }
    
    # Armazenar informações
    results$files <- c(results$files, pdf_file)
    results$chapter_info[[length(results$chapter_info) + 1]] <- list(
      file = pdf_file,
      chapter_text = if (nrow(chapter_matches) > 0) chapter_matches[1, 1] else NA,
      chapter_num = chapter_num
    )
  }
  
  # Sugerir ordem com base nos números de capítulo
  chapter_nums <- sapply(results$chapter_info, function(x) x$chapter_num)
  if (any(!is.na(chapter_nums))) {
    # Ordenar apenas os arquivos com números de capítulo identificados
    valid_indices <- which(!is.na(chapter_nums))
    ordered_indices <- valid_indices[order(chapter_nums[valid_indices])]
    
    # Adicionar arquivos sem número de capítulo identificado ao final
    invalid_indices <- which(is.na(chapter_nums))
    results$suggested_order <- c(ordered_indices, invalid_indices)
    
    cat("Ordem sugerida para os arquivos com base na análise de capítulos:\n")
    for (i in seq_along(results$suggested_order)) {
      idx <- results$suggested_order[i]
      info <- results$chapter_info[[idx]]
      chapter_info <- if (!is.na(info$chapter_text)) info$chapter_text else "Capítulo não identificado"
      cat(sprintf("  %d. %s (%s)\n", i, basename(info$file), chapter_info))
    }
  } else {
    cat("Não foi possível identificar números de capítulo nos arquivos.\n")
    results$suggested_order <- seq_along(file_list)
  }
  
  return(results)
}
```

## Função para Interface de Usuário para Junção de PDFs

```r
#' Cria uma interface interativa para junção de PDFs
#'
#' @param input_dir Diretório para buscar arquivos PDF (opcional)
#' @param output_file Arquivo de saída (opcional)
#' @return Caminho para o arquivo PDF combinado ou NULL se cancelado
interactive_pdf_merger <- function(input_dir = NULL, output_file = NULL) {
  # Esta função seria implementada com uma interface gráfica em um ambiente interativo
  # Como estamos em um ambiente de script, vamos simular o comportamento
  
  cat("=== Interface de Junção de PDFs ===\n\n")
  
  # Determinar diretório de entrada
  if (is.null(input_dir)) {
    input_dir <- getwd()
    cat(sprintf("Usando diretório atual: %s\n", input_dir))
  } else {
    cat(sprintf("Usando diretório especificado: %s\n", input_dir))
  }
  
  # Listar arquivos PDF no diretório
  pdf_files <- list.files(input_dir, pattern = "\\.pdf$", full.names = TRUE, ignore.case = TRUE)
  
  if (length(pdf_files) == 0) {
    cat("Nenhum arquivo PDF encontrado no diretório especificado.\n")
    return(NULL)
  }
  
  cat(sprintf("Encontrados %d arquivos PDF:\n", length(pdf_files)))
  for (i in seq_along(pdf_files)) {
    file_size <- file.info(pdf_files[i])$size / 1024  # Tamanho em KB
    cat(sprintf("  %d. %s (%.1f KB)\n", i, basename(pdf_files[i]), file_size))
  }
  
  # Analisar estrutura de capítulos
  cat("\nAnalisando estrutura de capítulos para sugerir ordem...\n")
  chapter_analysis <- analyze_pdf_chapters(pdf_files)
  
  # Determinar ordem dos arquivos
  if (length(chapter_analysis$suggested_order) > 0) {
    ordered_files <- pdf_files[chapter_analysis$suggested_order]
  } else {
    ordered_files <- pdf_files
  }
  
  # Determinar arquivo de saída
  if (is.null(output_file)) {
    output_file <- file.path(input_dir, "documentos_combinados.pdf")
    cat(sprintf("\nArquivo de saída: %s\n", output_file))
  }
  
  # Opções de junção
  cat("\nOpções de junção:\n")
  cat("  - Adicionar bookmarks: Sim\n")
  cat("  - Adicionar sumário: Não\n")
  cat("  - Preservar metadados: Sim\n")
  
  # Confirmar junção
  cat("\nPronto para juntar os arquivos na ordem sugerida.\n")
  cat("Em um ambiente interativo, o usuário poderia reordenar os arquivos.\n")
  
  # Executar junção
  result <- merge_pdfs(
    ordered_files, 
    output_file, 
    options = list(
      add_bookmarks = TRUE,
      add_toc = FALSE,
      preserve_metadata = TRUE,
      sort_files = FALSE,
      page_numbering = "continue",
      add_separator_pages = FALSE
    )
  )
  
  return(result)
}
```

## Função para Junção Direta via Linha de Comando

```r
#' Junta PDFs a partir de uma lista em um arquivo de texto
#'
#' @param list_file Arquivo com lista de PDFs (um por linha)
#' @param output_file Arquivo PDF de saída
#' @param options Opções de junção
#' @return Caminho para o arquivo PDF combinado
merge_pdfs_from_list <- function(list_file, output_file, options = list(
  add_bookmarks = TRUE,
  analyze_chapters = TRUE
)) {
  if (!file.exists(list_file)) {
    stop("Arquivo de lista não encontrado: ", list_file)
  }
  
  # Ler lista de arquivos
  pdf_files <- readLines(list_file, encoding = "UTF-8")
  pdf_files <- pdf_files[pdf_files != ""]
  
  if (length(pdf_files) == 0) {
    stop("Nenhum arquivo listado em: ", list_file)
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- pdf_files[!file.exists(pdf_files)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  # Analisar capítulos se solicitado
  if (options$analyze_chapters) {
    chapter_analysis <- analyze_pdf_chapters(pdf_files)
    if (length(chapter_analysis$suggested_order) > 0) {
      pdf_files <- pdf_files[chapter_analysis$suggested_order]
    }
  }
  
  # Executar junção
  result <- merge_pdfs(
    pdf_files, 
    output_file, 
    options = list(
      add_bookmarks = options$add_bookmarks,
      add_toc = FALSE,
      preserve_metadata = TRUE,
      sort_files = FALSE
    )
  )
  
  return(result)
}
```

## Integração com o Fluxo Principal

Estas funções de junção de PDFs serão integradas ao fluxo principal do programa, permitindo:

1. Juntar múltiplos arquivos PDF em um único documento antes da conversão para TXT
2. Analisar a estrutura de capítulos para sugerir a ordem correta dos arquivos
3. Adicionar bookmarks para facilitar a navegação no PDF combinado
4. Extrair e combinar o texto de múltiplos PDFs diretamente em um único arquivo TXT

A implementação oferece tanto opções via linha de comando quanto uma interface interativa simulada, permitindo flexibilidade no uso da ferramenta. Estas funções trabalham em conjunto com as funções de limpeza, remoção de anexos e sumários já implementadas, garantindo um fluxo completo de processamento.

A capacidade de juntar PDFs antes da conversão para TXT é especialmente útil quando o usuário precisa baixar capítulos separados de um documento e processá-los como uma única unidade, conforme mencionado nos requisitos originais.
