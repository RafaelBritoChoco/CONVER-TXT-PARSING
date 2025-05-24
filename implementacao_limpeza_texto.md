# Implementação de Ferramentas de Limpeza e Organização de Texto

Este documento detalha a implementação das ferramentas de limpeza e organização de texto para o programa de conversão de PDF/DOC para TXT.

## Função Principal de Limpeza de Texto

```r
#' Aplica limpeza e organização avançada ao texto extraído
#'
#' @param text Texto extraído do PDF/DOC
#' @param options Lista de opções de limpeza
#' @return Texto limpo e organizado
clean_text <- function(text, options = list(
  fix_paragraphs = TRUE,
  normalize_spaces = TRUE,
  fix_hyphens = TRUE,
  preserve_headings = TRUE,
  preserve_lists = TRUE,
  normalize_quotes = TRUE,
  remove_page_numbers = TRUE,
  remove_headers_footers = TRUE
)) {
  cat("Aplicando limpeza e organização avançada ao texto...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Remover números de página
  if (options$remove_page_numbers) {
    full_text <- remove_page_numbers(full_text)
  }
  
  # Remover cabeçalhos e rodapés repetitivos
  if (options$remove_headers_footers) {
    full_text <- remove_headers_footers(full_text)
  }
  
  # Normalizar espaços em branco
  if (options$normalize_spaces) {
    full_text <- normalize_spaces(full_text)
  }
  
  # Corrigir hifenização incorreta
  if (options$fix_hyphens) {
    full_text <- fix_hyphenation(full_text)
  }
  
  # Preservar formatação de cabeçalhos
  if (options$preserve_headings) {
    full_text <- preserve_headings(full_text)
  }
  
  # Preservar listas e itens numerados
  if (options$preserve_lists) {
    full_text <- preserve_lists(full_text)
  }
  
  # Corrigir quebras de linha em parágrafos
  if (options$fix_paragraphs) {
    full_text <- fix_paragraphs(full_text)
  }
  
  # Normalizar aspas e outros caracteres especiais
  if (options$normalize_quotes) {
    full_text <- normalize_quotes(full_text)
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Funções Auxiliares de Limpeza

### Remoção de Números de Página

```r
#' Remove números de página do texto
#'
#' @param text Texto completo
#' @return Texto sem números de página
remove_page_numbers <- function(text) {
  # Padrões comuns de números de página
  patterns <- c(
    # Número isolado centralizado
    "(?m)^\\s*\\d+\\s*$",
    # Padrão "Página X de Y"
    "(?i)(?m)^\\s*(?:page|página|pagina)\\s+\\d+\\s+(?:of|de)\\s+\\d+\\s*$",
    # Padrão "X" no início ou fim de linha
    "(?m)^\\s*\\d+\\s*\\n|\\n\\s*\\d+\\s*$"
  )
  
  # Aplicar cada padrão
  for (pattern in patterns) {
    text <- str_replace_all(text, pattern, "")
  }
  
  # Remover linhas em branco consecutivas resultantes
  text <- str_replace_all(text, "\n{3,}", "\n\n")
  
  return(text)
}
```

### Remoção de Cabeçalhos e Rodapés

```r
#' Remove cabeçalhos e rodapés repetitivos
#'
#' @param text Texto completo
#' @return Texto sem cabeçalhos e rodapés repetitivos
remove_headers_footers <- function(text) {
  # Dividir em linhas para análise
  lines <- strsplit(text, "\n")[[1]]
  
  # Detectar linhas que se repetem em intervalos regulares (possíveis cabeçalhos/rodapés)
  line_counts <- table(lines)
  potential_headers <- names(line_counts[line_counts > 3])
  
  # Filtrar linhas muito curtas ou vazias
  potential_headers <- potential_headers[nchar(potential_headers) > 5]
  
  if (length(potential_headers) > 0) {
    cat(sprintf("Detectados %d possíveis cabeçalhos/rodapés repetitivos.\n", length(potential_headers)))
    
    # Remover cada cabeçalho/rodapé potencial
    for (header in potential_headers) {
      # Verificar se aparece em intervalos regulares
      positions <- which(lines == header)
      intervals <- diff(positions)
      
      # Se os intervalos são consistentes (mesma distância entre ocorrências)
      if (length(unique(intervals)) <= 3 && length(positions) >= 3) {
        cat(sprintf("Removendo cabeçalho/rodapé repetitivo: '%s'\n", substr(header, 1, 30)))
        text <- str_replace_all(text, fixed(header), "")
      }
    }
    
    # Remover linhas em branco consecutivas resultantes
    text <- str_replace_all(text, "\n{3,}", "\n\n")
  }
  
  return(text)
}
```

### Normalização de Espaços

```r
#' Normaliza espaços em branco no texto
#'
#' @param text Texto completo
#' @return Texto com espaços normalizados
normalize_spaces <- function(text) {
  # Remover espaços múltiplos
  text <- str_replace_all(text, "[ \t]+", " ")
  
  # Remover espaços no início das linhas
  text <- str_replace_all(text, "(?m)^[ \t]+", "")
  
  # Remover espaços no final das linhas
  text <- str_replace_all(text, "(?m)[ \t]+$", "")
  
  # Garantir espaço após pontuação
  text <- str_replace_all(text, "([.!?:;,])([^ \n\"])", "\\1 \\2")
  
  # Remover linhas em branco consecutivas (mais de 2)
  text <- str_replace_all(text, "\n{3,}", "\n\n")
  
  return(text)
}
```

### Correção de Hifenização

```r
#' Corrige hifenização incorreta de palavras
#'
#' @param text Texto completo
#' @return Texto com hifenização corrigida
fix_hyphenation <- function(text) {
  # Padrão para palavras hifenizadas no final da linha
  # Palavra termina com hífen, seguida de quebra de linha e palavra começando com minúscula
  hyphen_pattern <- "([a-záéíóúàâêîôûãõñüç]+-)\n([a-záéíóúàâêîôûãõñüç]+)"
  
  # Substituir removendo o hífen e a quebra de linha
  text <- str_replace_all(text, hyphen_pattern, "\\1\\2")
  
  # Segundo passo: corrigir casos onde o hífen deve ser mantido
  # (compostos legítimos que foram quebrados em linhas)
  compound_pattern <- "([a-záéíóúàâêîôûãõñüç]+)-\n([a-záéíóúàâêîôûãõñüç]+)"
  text <- str_replace_all(text, compound_pattern, "\\1-\\2")
  
  return(text)
}
```

### Preservação de Cabeçalhos

```r
#' Preserva a formatação de cabeçalhos
#'
#' @param text Texto completo
#' @return Texto com cabeçalhos preservados
preserve_headings <- function(text) {
  # Criar padrão para cabeçalhos baseado nas palavras-chave
  heading_pattern <- paste0("(?i)(^|\\n)(", paste(HEADING_KEYWORDS, collapse = "|"), ")\\s+[A-Z0-9IVXLCDMivxlcdm]+")
  
  # Adicionar espaço antes e depois dos cabeçalhos
  text <- str_replace_all(text, heading_pattern, "\\1\n\n\\2")
  
  # Garantir que cabeçalhos tenham quebras de linha após
  text <- str_replace_all(text, paste0("(", heading_pattern, ")([^\n])"), "\\1\n\n\\4")
  
  # Padrão para cabeçalhos numerados (ex: "1. Introdução", "1.1 Contexto")
  numbered_heading_pattern <- "(?m)^(\\d+(?:\\.\\d+)*)\\s+([A-Z][a-záéíóúàâêîôûãõñüç]+)"
  
  # Garantir que cabeçalhos numerados tenham quebras de linha antes e depois
  text <- str_replace_all(text, numbered_heading_pattern, "\n\n\\1 \\2\n\n")
  
  # Remover quebras de linha excessivas
  text <- str_replace_all(text, "\n{3,}", "\n\n")
  
  return(text)
}
```

### Preservação de Listas

```r
#' Preserva a formatação de listas e itens numerados
#'
#' @param text Texto completo
#' @return Texto com listas preservadas
preserve_lists <- function(text) {
  # Padrões para diferentes tipos de marcadores de lista
  list_patterns <- list(
    # Itens numerados (1., 2., etc.)
    numbered = "(?m)^(\\d+\\.)\\s+([A-Za-záéíóúàâêîôûãõñüç])",
    
    # Itens com letras (a), b), etc.)
    lettered = "(?m)^([a-z]\\))\\s+([A-Za-záéíóúàâêîôûãõñüç])",
    
    # Itens com numeração romana (i., ii., etc.)
    roman = "(?m)^([ivxlcdm]+\\.)\\s+([A-Za-záéíóúàâêîôûãõñüç])",
    
    # Itens com marcadores (•, -, *, etc.)
    bullet = "(?m)^([•\\-\\*])\\s+([A-Za-záéíóúàâêîôûãõñüç])"
  )
  
  # Garantir que cada item de lista tenha quebra de linha antes
  for (pattern_name in names(list_patterns)) {
    pattern <- list_patterns[[pattern_name]]
    
    # Adicionar quebra de linha antes se não existir
    text <- str_replace_all(text, pattern, "\n\\1 \\2")
    
    # Garantir que itens de lista não sejam unidos com o texto anterior
    text <- str_replace_all(text, "([^\n])(\n\\d+\\.|\\n[a-z]\\)|\\n[ivxlcdm]+\\.|\\n[•\\-\\*])", "\\1\n\\2")
  }
  
  # Remover quebras de linha excessivas
  text <- str_replace_all(text, "\n{3,}", "\n\n")
  
  return(text)
}
```

### Correção de Parágrafos

```r
#' Corrige quebras de linha em parágrafos
#'
#' @param text Texto completo
#' @return Texto com parágrafos corrigidos
fix_paragraphs <- function(text) {
  # Dividir em linhas para processamento
  lines <- strsplit(text, "\n")[[1]]
  result <- character(0)
  
  i <- 1
  while (i <= length(lines)) {
    current_line <- lines[i]
    current_line_trimmed <- trimws(current_line)
    
    # Pular linhas vazias
    if (current_line_trimmed == "") {
      result <- c(result, current_line)
      i <- i + 1
      next
    }
    
    # Verificar se a linha atual deve ser unida com a próxima
    if (i < length(lines)) {
      next_line <- lines[i + 1]
      next_line_trimmed <- trimws(next_line)
      
      # Condições para unir linhas:
      # 1. Linha atual não termina com pontuação final
      # 2. Próxima linha não está vazia
      # 3. Próxima linha não começa com marcador de lista ou cabeçalho
      # 4. Linha atual não é um cabeçalho
      
      ends_with_punctuation <- grepl("[.!?:;]$", current_line_trimmed)
      next_is_empty <- next_line_trimmed == ""
      next_is_list_or_heading <- grepl("^(\\d+\\.|[a-z]\\)|[ivxlcdm]+\\.|[•\\-\\*]|[A-Z][A-Z]+)", next_line_trimmed)
      current_is_heading <- grepl(paste0("^(", paste(HEADING_KEYWORDS, collapse = "|"), ")\\s+"), current_line_trimmed, ignore.case = TRUE)
      
      if (!ends_with_punctuation && !next_is_empty && !next_is_list_or_heading && !current_is_heading) {
        # Unir com a próxima linha
        result <- c(result, paste(current_line, next_line))
        i <- i + 2
        next
      }
    }
    
    # Se não unir, adicionar a linha atual normalmente
    result <- c(result, current_line)
    i <- i + 1
  }
  
  # Juntar linhas processadas
  return(paste(result, collapse = "\n"))
}
```

### Normalização de Caracteres Especiais

```r
#' Normaliza aspas e outros caracteres especiais
#'
#' @param text Texto completo
#' @return Texto com caracteres normalizados
normalize_quotes <- function(text) {
  # Normalizar aspas
  replacements <- list(
    # Aspas
    c(""", "\""), c(""", "\""), c("'", "'"), c("'", "'"),
    # Travessões e hífens
    c("—", "-"), c("–", "-"),
    # Outros caracteres especiais
    c("…", "..."), c("•", "*"),
    # Caracteres não-quebráveis
    c("\u00A0", " ")
  )
  
  # Aplicar cada substituição
  for (replacement in replacements) {
    text <- str_replace_all(text, fixed(replacement[1]), replacement[2])
  }
  
  return(text)
}
```

## Função de Detecção e Correção de Problemas Comuns

```r
#' Detecta e corrige problemas comuns em textos extraídos de PDF/DOC
#'
#' @param text Texto extraído
#' @return Texto corrigido com relatório de problemas
detect_and_fix_issues <- function(text) {
  issues_found <- list()
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Detectar problemas de codificação
  encoding_issues <- str_count(full_text, "[�\\x{FFFD}]")
  if (encoding_issues > 0) {
    issues_found$encoding <- encoding_issues
    # Tentar corrigir substituindo caracteres problemáticos
    full_text <- str_replace_all(full_text, "[�\\x{FFFD}]", "")
  }
  
  # 2. Detectar linhas muito curtas (possíveis quebras incorretas)
  lines <- strsplit(full_text, "\n")[[1]]
  short_lines <- sum(nchar(lines) > 0 & nchar(lines) < 40)
  if (short_lines > length(lines) * 0.3) {  # Se mais de 30% das linhas são curtas
    issues_found$short_lines <- short_lines
    # Já será corrigido pela função fix_paragraphs
  }
  
  # 3. Detectar problemas de espaçamento
  spacing_issues <- str_count(full_text, "\\s{2,}")
  if (spacing_issues > 0) {
    issues_found$spacing <- spacing_issues
    # Já será corrigido pela função normalize_spaces
  }
  
  # 4. Detectar possíveis problemas de OCR
  ocr_issues <- str_count(full_text, "(?i)([b8]ased|cl0ud|0rganization|1nformation)")
  if (ocr_issues > 0) {
    issues_found$ocr <- ocr_issues
    # Correções específicas para problemas comuns de OCR
    ocr_replacements <- list(
      c("(?i)\\b0\\b", "o"), c("(?i)\\b1\\b", "i"), c("(?i)\\b8\\b", "B"),
      c("(?i)cl0ud", "cloud"), c("(?i)1nformation", "information")
    )
    for (replacement in ocr_replacements) {
      full_text <- str_replace_all(full_text, replacement[1], replacement[2])
    }
  }
  
  # 5. Detectar problemas de hifenização
  hyphen_issues <- str_count(full_text, "-\\n[a-z]")
  if (hyphen_issues > 0) {
    issues_found$hyphenation <- hyphen_issues
    # Já será corrigido pela função fix_hyphenation
  }
  
  # Gerar relatório
  if (length(issues_found) > 0) {
    cat("Problemas detectados e corrigidos:\n")
    for (issue_type in names(issues_found)) {
      cat(sprintf("- %s: %d ocorrências\n", issue_type, issues_found[[issue_type]]))
    }
  } else {
    cat("Nenhum problema comum detectado no texto.\n")
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Função de Pós-processamento para Melhorar a Legibilidade

```r
#' Aplica pós-processamento para melhorar a legibilidade do texto final
#'
#' @param text Texto processado
#' @return Texto com legibilidade aprimorada
improve_readability <- function(text) {
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Garantir espaçamento consistente entre parágrafos
  full_text <- str_replace_all(full_text, "(?m)([^\n])\n([^\n])", "\\1\n\n\\2")
  
  # 2. Garantir que títulos de seção estejam destacados
  for (keyword in HEADING_KEYWORDS) {
    pattern <- paste0("(?i)(^|\\n)(", keyword, "\\s+[A-Z0-9IVXLCDMivxlcdm]+[^\\n]*)")
    full_text <- str_replace_all(full_text, pattern, "\\1\n\\2\n")
  }
  
  # 3. Adicionar marcadores visuais para facilitar a leitura
  # Adicionar linha separadora antes de grandes seções
  for (keyword in c("CHAPTER", "PART", "SECTION", "CAPÍTULO", "PARTE", "SEÇÃO")) {
    pattern <- paste0("(?i)(^|\\n)(", keyword, "\\s+[A-Z0-9IVXLCDMivxlcdm]+[^\\n]*)")
    replacement <- paste0("\\1\n", paste(rep("-", 40), collapse=""), "\n\\2")
    full_text <- str_replace_all(full_text, pattern, replacement)
  }
  
  # 4. Normalizar quebras de linha excessivas
  full_text <- str_replace_all(full_text, "\n{3,}", "\n\n")
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}
```

## Integração com o Fluxo Principal

Estas funções de limpeza e organização de texto serão integradas ao fluxo principal do programa, garantindo que o texto extraído de PDFs ou DOCs seja convertido para TXT com alta qualidade e legibilidade. O processo completo inclui:

1. Detecção e correção automática de problemas comuns
2. Normalização de espaços e caracteres especiais
3. Correção de quebras de linha e parágrafos
4. Preservação da estrutura de cabeçalhos e listas
5. Remoção de elementos indesejados como números de página e cabeçalhos/rodapés repetitivos
6. Pós-processamento para melhorar a legibilidade final

Estas funções trabalham em conjunto com as funções de remoção de anexos e sumários já implementadas, garantindo um fluxo completo de processamento para obter arquivos TXT limpos e bem estruturados a partir de PDFs ou DOCs.
