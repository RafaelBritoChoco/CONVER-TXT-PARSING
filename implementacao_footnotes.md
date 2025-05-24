# Implementação de Marcação e Separação de Footnotes

Este documento detalha a implementação da funcionalidade de marcação e separação de notas de rodapé (footnotes) para o programa de conversão de PDF/DOC para TXT.

## Função Principal para Marcação de Footnotes

```r
#' Identifica, marca e reorganiza notas de rodapé no texto
#'
#' @param text Texto extraído do PDF/DOC
#' @param options Lista de opções para processamento de notas
#' @return Texto com notas de rodapé marcadas e reorganizadas
mark_footnotes <- function(text, options = list(
  move_to_end = TRUE,
  mark_references = TRUE,
  normalize_format = TRUE,
  detect_superscript = TRUE,
  add_section_header = TRUE,
  preserve_numbering = TRUE
)) {
  cat("Identificando e processando notas de rodapé...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Padrões para identificar notas de rodapé
  footnote_patterns <- list(
    # Padrão 1: Número seguido de texto (início de linha)
    standard = "(?m)^\\s*(\\d+(?:-\\d+)?)\\s+([^\n]+)",
    
    # Padrão 2: Número entre colchetes ou parênteses seguido de texto
    bracketed = "(?m)^\\s*\\[(\\d+)\\]\\s+([^\n]+)",
    
    # Padrão 3: Asterisco ou outro símbolo seguido de texto
    symbol = "(?m)^\\s*([\\*†‡§¶])\\s+([^\n]+)"
  )
  
  # Mapa para armazenar notas de rodapé encontradas
  footnote_map <- list()
  footnote_texts <- character(0)
  
  # 1. Identificar blocos de notas de rodapé
  cat("Buscando blocos de notas de rodapé...\n")
  
  # Para cada padrão de nota de rodapé
  for (pattern_name in names(footnote_patterns)) {
    pattern <- footnote_patterns[[pattern_name]]
    
    # Encontrar todas as ocorrências
    matches <- str_match_all(full_text, pattern)[[1]]
    
    if (nrow(matches) > 0) {
      cat(sprintf("Encontradas %d notas de rodapé com padrão '%s'\n", nrow(matches), pattern_name))
      
      # Processar cada nota encontrada
      for (i in 1:nrow(matches)) {
        fn_id <- matches[i, 2]
        fn_text <- matches[i, 3]
        
        # Armazenar no mapa
        footnote_map[[fn_id]] <- fn_text
        
        # Armazenar o texto completo da nota
        if (options$move_to_end) {
          footnote_texts <- c(footnote_texts, sprintf("%s: %s", fn_id, fn_text))
          
          # Remover a nota do texto principal
          full_text <- str_replace(full_text, fixed(matches[i, 1]), "")
        }
      }
    }
  }
  
  # 2. Identificar referências a notas de rodapé no texto
  if (options$mark_references && length(footnote_map) > 0) {
    cat("Marcando referências a notas de rodapé no texto...\n")
    
    # Padrões para identificar referências no texto
    reference_patterns <- list(
      # Superscript numérico
      superscript = if (options$detect_superscript) "([⁰¹²³⁴⁵⁶⁷⁸⁹]+)" else NULL,
      
      # Número entre colchetes
      bracketed = "\\[(\\d+(?:-\\d+)?)\\]",
      
      # Número entre parênteses
      parenthesis = "\\((\\d+(?:-\\d+)?)\\)",
      
      # Símbolos comuns de nota de rodapé
      symbols = "([\\*†‡§¶])"
    )
    
    # Função para normalizar superscripts para texto normal
    normalize_superscript <- function(text) {
      # Tabela de conversão de superscript para normal
      superscript_map <- c(
        "⁰" = "0", "¹" = "1", "²" = "2", "³" = "3", "⁴" = "4",
        "⁵" = "5", "⁶" = "6", "⁷" = "7", "⁸" = "8", "⁹" = "9",
        "⁻" = "-"
      )
      
      # Aplicar conversões
      for (sup in names(superscript_map)) {
        text <- gsub(sup, superscript_map[sup], text, fixed = TRUE)
      }
      
      return(text)
    }
    
    # Para cada padrão de referência
    for (pattern_name in names(reference_patterns)) {
      pattern <- reference_patterns[[pattern_name]]
      
      if (!is.null(pattern)) {
        # Encontrar todas as ocorrências
        ref_matches <- str_match_all(full_text, pattern)[[1]]
        
        if (nrow(ref_matches) > 0) {
          cat(sprintf("Encontradas %d referências com padrão '%s'\n", nrow(ref_matches), pattern_name))
          
          # Processar cada referência encontrada
          for (i in 1:nrow(ref_matches)) {
            ref_full <- ref_matches[i, 1]
            ref_id <- ref_matches[i, 2]
            
            # Para superscripts, normalizar o ID
            if (pattern_name == "superscript") {
              ref_id_normal <- normalize_superscript(ref_id)
            } else {
              ref_id_normal <- ref_id
            }
            
            # Verificar se existe uma nota correspondente
            if (ref_id_normal %in% names(footnote_map)) {
              # Substituir a referência por uma marcação clara
              marked_ref <- sprintf("(footnote %s)", ref_id_normal)
              full_text <- str_replace(full_text, fixed(ref_full), marked_ref)
            }
          }
        }
      }
    }
  }
  
  # 3. Adicionar seção de notas de rodapé no final do documento
  if (options$move_to_end && length(footnote_texts) > 0) {
    # Adicionar cabeçalho da seção
    if (options$add_section_header) {
      full_text <- paste0(
        full_text,
        "\n\n",
        paste(rep("=", 50), collapse = ""),
        "\n",
        "NOTAS DE RODAPÉ",
        "\n",
        paste(rep("=", 50), collapse = ""),
        "\n\n"
      )
    } else {
      full_text <- paste0(full_text, "\n\n")
    }
    
    # Adicionar cada nota de rodapé
    for (fn_text in footnote_texts) {
      full_text <- paste0(full_text, fn_text, "\n\n")
    }
  }
  
  # Remover linhas em branco consecutivas excessivas
  full_text <- str_replace_all(full_text, "\n{3,}", "\n\n")
  
  # Estatísticas
  cat(sprintf("Processamento de notas de rodapé concluído. %d notas identificadas e marcadas.\n", 
              length(footnote_map)))
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Função Avançada para Detecção de Footnotes em Diferentes Formatos

```r
#' Detecta notas de rodapé em diferentes formatos e estilos
#'
#' @param text Texto extraído do PDF/DOC
#' @return Lista com informações sobre notas de rodapé detectadas
detect_footnote_style <- function(text) {
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Diferentes estilos de notas de rodapé para detectar
  footnote_styles <- list(
    # Estilo 1: Notas numeradas no rodapé da página
    bottom_numbered = list(
      pattern = "(?m)^\\s*(\\d+)\\s+([^\n]+)",
      example = "1 Esta é uma nota de rodapé."
    ),
    
    # Estilo 2: Notas no final do documento (endnotes)
    endnotes = list(
      pattern = "(?i)(?m)(Notes|Notas|Endnotes)\\s*\\n+\\s*\\d+\\.",
      example = "Notes\n\n1. Esta é uma nota de fim."
    ),
    
    # Estilo 3: Notas com símbolos
    symbol_notes = list(
      pattern = "(?m)^\\s*([\\*†‡§¶])\\s+([^\n]+)",
      example = "* Esta é uma nota com símbolo."
    ),
    
    # Estilo 4: Notas entre colchetes
    bracketed_notes = list(
      pattern = "(?m)^\\s*\\[(\\d+)\\]\\s+([^\n]+)",
      example = "[1] Esta é uma nota entre colchetes."
    ),
    
    # Estilo 5: Notas acadêmicas com autor/ano
    academic_notes = list(
      pattern = "(?m)^\\s*\\(([A-Za-z]+,\\s+\\d{4})\\)\\s+([^\n]+)",
      example = "(Smith, 2020) Esta é uma nota acadêmica."
    )
  )
  
  # Resultados da detecção
  results <- list(
    detected_styles = character(0),
    counts = list(),
    examples = list(),
    recommended_approach = NULL
  )
  
  # Detectar cada estilo
  for (style_name in names(footnote_styles)) {
    style <- footnote_styles[[style_name]]
    
    # Encontrar ocorrências
    matches <- str_match_all(full_text, style$pattern)[[1]]
    
    if (nrow(matches) > 0) {
      # Registrar estilo detectado
      results$detected_styles <- c(results$detected_styles, style_name)
      results$counts[[style_name]] <- nrow(matches)
      
      # Guardar exemplos
      if (nrow(matches) >= 3) {
        results$examples[[style_name]] <- matches[1:3, 1]
      } else {
        results$examples[[style_name]] <- matches[, 1]
      }
    }
  }
  
  # Determinar abordagem recomendada
  if (length(results$detected_styles) > 0) {
    # Encontrar o estilo mais comum
    most_common_style <- results$detected_styles[which.max(unlist(results$counts))]
    results$recommended_approach <- most_common_style
    
    cat(sprintf("Detectados %d estilos de notas de rodapé.\n", length(results$detected_styles)))
    cat(sprintf("Estilo mais comum: %s (%d ocorrências)\n", 
                most_common_style, results$counts[[most_common_style]]))
    
    for (style in results$detected_styles) {
      cat(sprintf("- %s: %d ocorrências\n", style, results$counts[[style]]))
    }
  } else {
    cat("Nenhum estilo de nota de rodapé detectado no texto.\n")
  }
  
  return(results)
}
```

## Função para Processamento Avançado de Footnotes

```r
#' Processa notas de rodapé com base no estilo detectado
#'
#' @param text Texto extraído do PDF/DOC
#' @param auto_detect Se TRUE, detecta automaticamente o estilo das notas
#' @param style Estilo específico a ser usado (se auto_detect = FALSE)
#' @param options Opções adicionais de processamento
#' @return Texto com notas de rodapé processadas
process_footnotes_by_style <- function(text, auto_detect = TRUE, style = NULL, options = list(
  move_to_end = TRUE,
  mark_references = TRUE,
  normalize_format = TRUE
)) {
  # Se auto_detect está ativado, detectar o estilo
  if (auto_detect) {
    cat("Detectando automaticamente o estilo das notas de rodapé...\n")
    detection_results <- detect_footnote_style(text)
    
    if (length(detection_results$detected_styles) > 0) {
      style <- detection_results$recommended_approach
      cat(sprintf("Usando estilo detectado: %s\n", style))
    } else {
      cat("Nenhum estilo detectado. Usando processamento padrão.\n")
      style <- "bottom_numbered"
    }
  }
  
  # Configurar padrões e opções com base no estilo
  processing_config <- list(
    bottom_numbered = list(
      footnote_pattern = "(?m)^\\s*(\\d+)\\s+([^\n]+)",
      reference_patterns = list(
        superscript = "([⁰¹²³⁴⁵⁶⁷⁸⁹]+)",
        bracketed = "\\[(\\d+)\\]",
        parenthesis = "\\((\\d+)\\)"
      )
    ),
    
    endnotes = list(
      footnote_pattern = "(?m)^\\s*(\\d+)\\.\\s+([^\n]+)",
      reference_patterns = list(
        superscript = "([⁰¹²³⁴⁵⁶⁷⁸⁹]+)",
        bracketed = "\\[(\\d+)\\]"
      )
    ),
    
    symbol_notes = list(
      footnote_pattern = "(?m)^\\s*([\\*†‡§¶])\\s+([^\n]+)",
      reference_patterns = list(
        symbols = "([\\*†‡§¶])"
      )
    ),
    
    bracketed_notes = list(
      footnote_pattern = "(?m)^\\s*\\[(\\d+)\\]\\s+([^\n]+)",
      reference_patterns = list(
        bracketed = "\\[(\\d+)\\]"
      )
    ),
    
    academic_notes = list(
      footnote_pattern = "(?m)^\\s*\\(([A-Za-z]+,\\s+\\d{4})\\)\\s+([^\n]+)",
      reference_patterns = list(
        parenthesis = "\\(([A-Za-z]+,\\s+\\d{4})\\)"
      )
    )
  )
  
  # Verificar se o estilo é válido
  if (!(style %in% names(processing_config))) {
    warning(sprintf("Estilo '%s' não reconhecido. Usando estilo padrão 'bottom_numbered'.", style))
    style <- "bottom_numbered"
  }
  
  # Obter configuração para o estilo
  config <- processing_config[[style]]
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Identificar notas de rodapé
  footnote_map <- list()
  footnote_texts <- character(0)
  
  # Encontrar todas as ocorrências de notas
  matches <- str_match_all(full_text, config$footnote_pattern)[[1]]
  
  if (nrow(matches) > 0) {
    cat(sprintf("Encontradas %d notas de rodapé.\n", nrow(matches)))
    
    # Processar cada nota
    for (i in 1:nrow(matches)) {
      fn_id <- matches[i, 2]
      fn_text <- matches[i, 3]
      
      # Armazenar no mapa
      footnote_map[[fn_id]] <- fn_text
      
      # Armazenar o texto completo da nota
      if (options$move_to_end) {
        footnote_texts <- c(footnote_texts, sprintf("%s: %s", fn_id, fn_text))
        
        # Remover a nota do texto principal
        full_text <- str_replace(full_text, fixed(matches[i, 1]), "")
      }
    }
  } else {
    cat("Nenhuma nota de rodapé encontrada com o padrão especificado.\n")
    return(text)  # Retornar texto original
  }
  
  # 2. Identificar e marcar referências
  if (options$mark_references && length(footnote_map) > 0) {
    cat("Marcando referências a notas de rodapé no texto...\n")
    
    # Função para normalizar superscripts
    normalize_superscript <- function(text) {
      superscript_map <- c(
        "⁰" = "0", "¹" = "1", "²" = "2", "³" = "3", "⁴" = "4",
        "⁵" = "5", "⁶" = "6", "⁷" = "7", "⁸" = "8", "⁹" = "9",
        "⁻" = "-"
      )
      
      for (sup in names(superscript_map)) {
        text <- gsub(sup, superscript_map[sup], text, fixed = TRUE)
      }
      
      return(text)
    }
    
    # Para cada padrão de referência
    for (pattern_name in names(config$reference_patterns)) {
      pattern <- config$reference_patterns[[pattern_name]]
      
      # Encontrar todas as ocorrências
      ref_matches <- str_match_all(full_text, pattern)[[1]]
      
      if (nrow(ref_matches) > 0) {
        cat(sprintf("Encontradas %d referências com padrão '%s'\n", nrow(ref_matches), pattern_name))
        
        # Processar cada referência
        for (i in 1:nrow(ref_matches)) {
          ref_full <- ref_matches[i, 1]
          ref_id <- ref_matches[i, 2]
          
          # Para superscripts, normalizar o ID
          if (pattern_name == "superscript") {
            ref_id_normal <- normalize_superscript(ref_id)
          } else {
            ref_id_normal <- ref_id
          }
          
          # Verificar se existe uma nota correspondente
          if (ref_id_normal %in% names(footnote_map)) {
            # Substituir a referência por uma marcação clara
            marked_ref <- sprintf("(footnote %s)", ref_id_normal)
            full_text <- str_replace(full_text, fixed(ref_full), marked_ref)
          }
        }
      }
    }
  }
  
  # 3. Adicionar seção de notas de rodapé no final
  if (options$move_to_end && length(footnote_texts) > 0) {
    full_text <- paste0(
      full_text,
      "\n\n",
      paste(rep("=", 50), collapse = ""),
      "\n",
      "NOTAS DE RODAPÉ",
      "\n",
      paste(rep("=", 50), collapse = ""),
      "\n\n"
    )
    
    # Adicionar cada nota
    for (fn_text in footnote_texts) {
      full_text <- paste0(full_text, fn_text, "\n\n")
    }
  }
  
  # Remover linhas em branco consecutivas excessivas
  full_text <- str_replace_all(full_text, "\n{3,}", "\n\n")
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Função para Extração e Processamento de Footnotes em Documentos Acadêmicos

```r
#' Processa notas de rodapé em documentos acadêmicos
#'
#' @param text Texto extraído do PDF/DOC
#' @param options Opções de processamento
#' @return Texto com notas de rodapé processadas
process_academic_footnotes <- function(text, options = list(
  extract_bibliography = TRUE,
  format_citations = TRUE,
  move_to_end = TRUE
)) {
  cat("Processando notas de rodapé em formato acadêmico...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Detectar seção de bibliografia/referências
  bibliography_section <- NULL
  bibliography_patterns <- c(
    "(?i)\\n\\s*(References|Bibliografia|Referências)\\s*\\n",
    "(?i)\\n\\s*(Works Cited|Obras Citadas)\\s*\\n",
    "(?i)\\n\\s*(Bibliography|Bibliografía|Bibliografia)\\s*\\n"
  )
  
  for (pattern in bibliography_patterns) {
    bib_match <- str_match(full_text, pattern)
    if (!is.na(bib_match[1,1])) {
      # Encontrar posição da seção de bibliografia
      bib_pos <- str_locate(full_text, pattern)[1,1]
      
      # Extrair seção de bibliografia
      bibliography_section <- substr(full_text, bib_pos, nchar(full_text))
      
      # Remover a seção do texto principal se solicitado
      if (options$extract_bibliography) {
        full_text <- substr(full_text, 1, bib_pos - 1)
      }
      
      cat("Seção de bibliografia/referências encontrada.\n")
      break
    }
  }
  
  # 2. Identificar citações no texto
  citation_patterns <- list(
    author_year = "\\(([A-Za-z]+(?:,?\\s+et al\\.?)?,\\s+\\d{4}[a-z]?)\\)",
    numbered = "\\[(\\d+)\\]",
    superscript = "([⁰¹²³⁴⁵⁶⁷⁸⁹]+)"
  )
  
  citation_map <- list()
  citation_count <- 0
  
  # Para cada padrão de citação
  for (pattern_name in names(citation_patterns)) {
    pattern <- citation_patterns[[pattern_name]]
    
    # Encontrar todas as ocorrências
    cit_matches <- str_match_all(full_text, pattern)[[1]]
    
    if (nrow(cit_matches) > 0) {
      cat(sprintf("Encontradas %d citações com padrão '%s'\n", nrow(cit_matches), pattern_name))
      
      # Processar cada citação
      for (i in 1:nrow(cit_matches)) {
        cit_full <- cit_matches[i, 1]
        cit_id <- cit_matches[i, 2]
        
        # Verificar se já processamos esta citação
        if (!(cit_id %in% names(citation_map))) {
          citation_count <- citation_count + 1
          citation_map[[cit_id]] <- citation_count
          
          # Marcar a citação no texto
          if (options$format_citations) {
            marked_cit <- sprintf("(citation %s)", cit_id)
            full_text <- str_replace_all(full_text, fixed(cit_full), marked_cit)
          }
        }
      }
    }
  }
  
  # 3. Adicionar seção de bibliografia processada no final
  if (options$move_to_end && !is.null(bibliography_section) && citation_count > 0) {
    full_text <- paste0(
      full_text,
      "\n\n",
      paste(rep("=", 50), collapse = ""),
      "\n",
      "REFERÊNCIAS BIBLIOGRÁFICAS",
      "\n",
      paste(rep("=", 50), collapse = ""),
      "\n\n"
    )
    
    # Processar e adicionar entradas bibliográficas
    bib_lines <- strsplit(bibliography_section, "\n")[[1]]
    bib_lines <- bib_lines[bib_lines != ""]
    
    # Remover a linha de cabeçalho
    header_pattern <- "(?i)^\\s*(References|Bibliografia|Referências|Works Cited|Obras Citadas|Bibliography|Bibliografía)\\s*$"
    bib_lines <- bib_lines[!grepl(header_pattern, bib_lines)]
    
    # Adicionar entradas processadas
    if (length(bib_lines) > 0) {
      for (line in bib_lines) {
        full_text <- paste0(full_text, line, "\n")
      }
    }
  }
  
  cat(sprintf("Processamento de citações acadêmicas concluído. %d citações identificadas.\n", 
              citation_count))
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Integração com o Fluxo Principal

Estas funções de processamento de notas de rodapé serão integradas ao fluxo principal do programa, garantindo que:

1. As notas de rodapé sejam corretamente identificadas em diferentes formatos e estilos
2. As referências às notas no texto principal sejam claramente marcadas para fácil localização
3. As notas sejam organizadas em uma seção específica no final do documento
4. O formato seja consistente e legível no arquivo TXT final

A implementação oferece detecção automática do estilo das notas, permitindo processar corretamente diferentes tipos de documentos, desde textos legais até artigos acadêmicos. As funções trabalham em conjunto com as demais funcionalidades já implementadas (limpeza, remoção de anexos e sumários, junção de PDFs), garantindo um fluxo completo de processamento.

A capacidade de identificar e marcar claramente as notas de rodapé é especialmente importante para o usuário, conforme mencionado nos requisitos originais, permitindo que ele localize facilmente as referências e seus textos correspondentes no documento convertido para TXT.
