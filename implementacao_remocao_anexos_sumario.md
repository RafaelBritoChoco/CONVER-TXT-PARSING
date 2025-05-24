# Implementação Aprimorada das Funções de Remoção de Anexos e Sumário

Vou aprimorar as funções de remoção de anexos e sumário no programa R, focando especificamente na conversão de PDF/DOC para TXT.

## Função de Remoção de Anexos Aprimorada

```r
#' Detecta e remove anexos do texto extraído com maior precisão
#'
#' @param text Texto extraído do PDF/DOC
#' @param keywords Palavras-chave para identificar anexos em diferentes idiomas
#' @param include_patterns Padrões adicionais para identificar anexos (regex)
#' @return Texto sem anexos
remove_anexos <- function(text, keywords = ANEXO_KEYWORDS, include_patterns = NULL) {
  cat("Removendo anexos do documento...\n")
  
  # Juntar todo o texto para processamento
  full_text <- paste(text, collapse = "\n")
  
  # Criar padrão regex para encontrar anexos baseado nas palavras-chave
  keyword_pattern <- paste0("(?i)(", paste(keywords, collapse = "|"), ")\\s+[A-Z0-9IVXLCDMivxlcdm]+")
  
  # Adicionar padrões personalizados se fornecidos
  if (!is.null(include_patterns) && length(include_patterns) > 0) {
    keyword_pattern <- paste0("(", keyword_pattern, "|", paste(include_patterns, collapse = "|"), ")")
  }
  
  # Encontrar todas as ocorrências de início de anexos
  matches <- str_match_all(full_text, keyword_pattern)[[1]]
  
  if (length(matches) > 0) {
    # Ordenar matches por posição no texto
    match_positions <- sapply(matches[,1], function(m) str_locate(full_text, fixed(m))[1])
    sorted_indices <- order(match_positions)
    sorted_matches <- matches[sorted_indices,1]
    sorted_positions <- match_positions[sorted_indices]
    
    # Para cada anexo encontrado, determinar seu escopo e removê-lo
    for (i in 1:length(sorted_matches)) {
      # Posição inicial do anexo atual
      start_pos <- sorted_positions[i]
      
      # Determinar o fim do anexo (próximo anexo ou fim do documento)
      if (i < length(sorted_matches)) {
        end_pos <- sorted_positions[i+1] - 1
      } else {
        # Se for o último anexo, verificar se há um padrão de fim de documento
        # ou usar o fim do texto
        end_markers <- c("FIM DO DOCUMENTO", "END OF DOCUMENT", "REFERENCES", "REFERÊNCIAS")
        end_marker_pattern <- paste0("(?i)(", paste(end_markers, collapse = "|"), ")")
        end_match <- str_match(substr(full_text, start_pos, nchar(full_text)), end_marker_pattern)
        
        if (!is.na(end_match[1,1])) {
          end_marker_pos <- str_locate(substr(full_text, start_pos, nchar(full_text)), fixed(end_match[1,1]))[1]
          end_pos <- start_pos + end_marker_pos - 2
        } else {
          end_pos <- nchar(full_text)
        }
      }
      
      # Remover o anexo
      full_text <- paste0(
        substr(full_text, 1, start_pos - 1),
        substr(full_text, end_pos, nchar(full_text))
      )
      
      # Ajustar posições dos anexos subsequentes após a remoção
      if (i < length(sorted_matches)) {
        adjustment <- end_pos - start_pos + 1
        sorted_positions[(i+1):length(sorted_positions)] <- 
          sorted_positions[(i+1):length(sorted_positions)] - adjustment
      }
    }
    
    # Registrar estatísticas
    cat(sprintf("Removidos %d anexos do documento.\n", length(matches)))
  } else {
    cat("Nenhum anexo identificado no documento.\n")
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Função de Remoção de Sumário Aprimorada

```r
#' Detecta e remove sumário (table of contents) do texto extraído com maior precisão
#'
#' @param text Texto extraído do PDF/DOC
#' @param keywords Palavras-chave para identificar sumários em diferentes idiomas
#' @param max_toc_pages Número máximo estimado de páginas do sumário
#' @return Texto sem sumário
remove_sumario <- function(text, keywords = TOC_KEYWORDS, max_toc_pages = 5) {
  cat("Removendo sumário (table of contents)...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Criar padrão regex para encontrar sumários
  pattern <- paste0("(?i)(", paste(keywords, collapse = "|"), ")")
  
  # Encontrar a ocorrência do sumário
  match <- str_match(full_text, pattern)
  
  if (!is.na(match[1,1])) {
    # Encontrar a posição do início do sumário
    start_pos <- str_locate(full_text, fixed(match[1,1]))[1]
    
    # Estratégias para determinar o fim do sumário:
    
    # 1. Procurar por padrões de início de conteúdo principal
    content_start_patterns <- c(
      # Padrões em inglês
      "(?i)introduction", "(?i)chapter\\s+1", "(?i)section\\s+1", 
      # Padrões em português
      "(?i)introdução", "(?i)capítulo\\s+1", "(?i)seção\\s+1",
      # Padrões em espanhol
      "(?i)introducción", "(?i)capítulo\\s+1", "(?i)sección\\s+1",
      # Padrões gerais
      "(?i)1\\.\\s+[A-Z]"
    )
    
    # Combinar padrões em uma única expressão
    content_pattern <- paste0("(", paste(content_start_patterns, collapse = "|"), ")")
    
    # Procurar pelo início do conteúdo após o sumário
    content_match <- str_match(substr(full_text, start_pos, nchar(full_text)), content_pattern)
    
    if (!is.na(content_match[1,1])) {
      # Encontrou um marcador de início de conteúdo
      content_pos <- str_locate(substr(full_text, start_pos, nchar(full_text)), fixed(content_match[1,1]))[1]
      end_pos <- start_pos + content_pos - 2
    } else {
      # 2. Estratégia alternativa: estimar com base em características do sumário
      
      # Extrair linhas após o início do sumário
      lines_after <- strsplit(substr(full_text, start_pos, nchar(full_text)), "\n")[[1]]
      
      # Analisar padrões de linhas de sumário (números de página, pontos, etc.)
      toc_line_pattern <- ".*\\s+\\.+\\s*\\d+\\s*$|.*\\s+\\d+\\s*$"
      toc_line_count <- sum(str_detect(lines_after, toc_line_pattern))
      
      if (toc_line_count > 0) {
        # Encontrar a última linha que parece ser do sumário
        last_toc_line <- max(which(str_detect(lines_after, toc_line_pattern)))
        
        # Adicionar algumas linhas para garantir que pegamos todo o sumário
        buffer_lines <- 5
        end_line <- min(last_toc_line + buffer_lines, length(lines_after))
        
        # Calcular posição final
        end_text <- paste(lines_after[1:end_line], collapse = "\n")
        end_pos <- start_pos + nchar(end_text)
      } else {
        # 3. Última estratégia: usar estimativa de páginas
        # Estimar número de linhas por página
        avg_lines_per_page <- 40
        estimated_toc_lines <- max_toc_pages * avg_lines_per_page
        end_line <- min(estimated_toc_lines, length(lines_after))
        
        end_text <- paste(lines_after[1:end_line], collapse = "\n")
        end_pos <- start_pos + nchar(end_text)
      }
    }
    
    # Remover o sumário
    full_text <- paste0(
      substr(full_text, 1, start_pos - 1),
      substr(full_text, end_pos, nchar(full_text))
    )
    
    cat("Sumário removido com sucesso.\n")
  } else {
    cat("Nenhum sumário identificado no documento.\n")
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Função para Detectar e Remover Outros Elementos

```r
#' Detecta e remove elementos específicos como listas de figuras, tabelas, etc.
#'
#' @param text Texto extraído do PDF/DOC
#' @param elements Lista de elementos a remover com seus padrões
#' @return Texto sem os elementos especificados
remove_elementos <- function(text, elements = list(
  list(name = "Lista de Figuras", patterns = c("(?i)list of figures", "(?i)lista de figuras")),
  list(name = "Lista de Tabelas", patterns = c("(?i)list of tables", "(?i)lista de tabelas")),
  list(name = "Prefácio", patterns = c("(?i)preface", "(?i)prefácio", "(?i)prefacio")),
  list(name = "Agradecimentos", patterns = c("(?i)acknowledgements", "(?i)agradecimentos"))
)) {
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Para cada tipo de elemento
  for (element in elements) {
    element_name <- element$name
    element_patterns <- element$patterns
    
    cat(sprintf("Verificando presença de: %s\n", element_name))
    
    # Criar padrão combinado
    combined_pattern <- paste0("(", paste(element_patterns, collapse = "|"), ")")
    
    # Encontrar ocorrência
    match <- str_match(full_text, combined_pattern)
    
    if (!is.na(match[1,1])) {
      # Encontrar a posição do início do elemento
      start_pos <- str_locate(full_text, fixed(match[1,1]))[1]
      
      # Estimar o fim do elemento (próxima seção ou capítulo)
      section_pattern <- paste0("(?i)(", paste(HEADING_KEYWORDS, collapse = "|"), ")\\s+[A-Z0-9]+")
      section_match <- str_match(substr(full_text, start_pos, nchar(full_text)), section_pattern)
      
      if (!is.na(section_match[1,1])) {
        # Encontrou próxima seção
        section_pos <- str_locate(substr(full_text, start_pos, nchar(full_text)), fixed(section_match[1,1]))[1]
        end_pos <- start_pos + section_pos - 2
      } else {
        # Estimar com base em número de linhas (2 páginas)
        lines_after <- strsplit(substr(full_text, start_pos, nchar(full_text)), "\n")[[1]]
        end_line <- min(80, length(lines_after))
        end_text <- paste(lines_after[1:end_line], collapse = "\n")
        end_pos <- start_pos + nchar(end_text)
      }
      
      # Remover o elemento
      full_text <- paste0(
        substr(full_text, 1, start_pos - 1),
        substr(full_text, end_pos, nchar(full_text))
      )
      
      cat(sprintf("%s removido com sucesso.\n", element_name))
    }
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Integração com o Fluxo Principal

Estas funções aprimoradas serão integradas ao fluxo principal do programa, especialmente focando na conversão de PDF/DOC para TXT. A implementação garante:

1. Detecção mais precisa de anexos e sumários em diferentes idiomas
2. Melhor determinação dos limites de cada seção a ser removida
3. Capacidade de remover elementos adicionais como listas de figuras, tabelas, etc.
4. Feedback detalhado sobre o processo de remoção

As funções serão chamadas no fluxo principal de processamento, garantindo que o arquivo TXT final esteja limpo destes elementos quando solicitado pelo usuário.
