#!/usr/bin/env Rscript

# =============================================================================
# PDF Processor - Ferramenta para processamento e limpeza de PDFs Jurídicos
# =============================================================================
# Autor: Manus AI
# Data: Maio 2025
# Descrição: Programa para processamento de arquivos PDF jurídicos, incluindo 
#            remoção de anexos, sumários, limpeza de texto, junção de PDFs, 
#            tratamento de notas de rodapé e formatação específica para documentos
#            legais com foco em preservar a estrutura para posterior parsing.
# =============================================================================

# Carregamento de pacotes necessários
required_packages <- c(
  "pdftools",     # Manipulação básica de PDFs
  "tesseract",    # OCR para melhorar extração de texto
  "stringr",      # Manipulação avançada de strings
  "stringi",      # Suporte a internacionalização
  "qpdf",         # Manipulação avançada de PDFs
  "docxtractr",   # Para trabalhar com documentos DOCX
  "optparse",     # Para interface de linha de comando
  "data.table",   # Para processamento eficiente de dados
  "magrittr",     # Para operações em pipeline
  "parallel",     # Para processamento paralelo
  "xml2",         # Para saída estruturada
  "jsonlite"      # Para saída em JSON
)

# Função para instalar pacotes ausentes
install_missing_packages <- function(packages) {
  new_packages <- packages[!(packages %in% installed.packages()[,"Package"])]
  if(length(new_packages) > 0) {
    cat("Instalando pacotes necessários...\n")
    install.packages(new_packages, repos = "https://cloud.r-project.org/")
  }
}

# Tentar instalar pacotes ausentes
tryCatch({
  install_missing_packages(required_packages)
}, error = function(e) {
  cat("ERRO: Falha ao instalar pacotes. Detalhes:", conditionMessage(e), "\n")
  cat("Por favor, instale manualmente os seguintes pacotes:", paste(required_packages, collapse=", "), "\n")
  quit(status = 1)
})

# Carregar pacotes
suppressPackageStartupMessages({
  for(pkg in required_packages) {
    library(pkg, character.only = TRUE)
  }
})

# =============================================================================
# Constantes e configurações globais
# =============================================================================

# Palavras-chave para identificação de anexos em diferentes idiomas
ANEXO_KEYWORDS <- c(
  "ANNEX", "ANEXO", "APPENDIX", "APÊNDICE", "APPENDICE", "ANHANG", "ANLAGE"
)

# Palavras-chave para identificação de sumários em diferentes idiomas
TOC_KEYWORDS <- c(
  "TABLE OF CONTENTS", "CONTENTS", "ÍNDICE", "INDICE", "SUMÁRIO", "SUMARIO",
  "TABLA DE CONTENIDOS", "SOMMAIRE", "TABLE DES MATIÈRES", "INHALTSVERZEICHNIS"
)

# Palavras-chave para identificação de cabeçalhos em diferentes idiomas
HEADING_KEYWORDS <- c(
  # Inglês
  "PART", "BOOK", "CHAPTER", "SECTION", "ARTICLE", "TITLE", "DIVISION", "SUBPART",
  # Português
  "PARTE", "LIVRO", "CAPÍTULO", "SEÇÃO", "SECÇÃO", "ARTIGO", "TÍTULO", "DIVISÃO", "SUBPARTE",
  # Espanhol
  "PARTE", "LIBRO", "CAPÍTULO", "SECCIÓN", "ARTÍCULO", "TÍTULO", "DIVISIÓN", "SUBPARTE",
  # Francês
  "PARTIE", "LIVRE", "CHAPITRE", "SECTION", "ARTICLE", "TITRE", "DIVISION", "SOUS-PARTIE",
  # Alemão
  "TEIL", "BUCH", "KAPITEL", "ABSCHNITT", "ARTIKEL", "TITEL", "UNTERTEIL"
)

# Padrões para identificação de elementos jurídicos
LEGAL_PATTERNS <- list(
  # Padrões para artigos
  articles = c(
    "Art\\. \\d+", "Artigo \\d+", "Article \\d+",
    "Art\\. \\d+[A-Za-z]?º", "Artigo \\d+[A-Za-z]?º"
  ),
  # Padrões para parágrafos
  paragraphs = c(
    "§ \\d+", "§\\d+º", "§ único", "§único", "Parágrafo único", 
    "Paragrafo único", "Parágrafo", "Paragraph"
  ),
  # Padrões para incisos
  items = c(
    "^\\s*I +[-–]", "^\\s*II +[-–]", "^\\s*III +[-–]", "^\\s*IV +[-–]",
    "^\\s*V +[-–]", "^\\s*VI +[-–]", "^\\s*VII +[-–]", "^\\s*VIII +[-–]",
    "^\\s*IX +[-–]", "^\\s*X +[-–]", "^\\s*XI +[-–]", "^\\s*XII +[-–]",
    "^\\s*[a-z]\\) ", "^\\s*[a-z]\\.", "^\\s*\\d+\\. ", "^\\s*\\d+\\) "
  ),
  # Padrões para capítulos
  chapters = c(
    "CAPÍTULO [IVX]+", "CAPITULO [IVX]+", "CHAPTER [IVX]+"
  ),
  # Padrões para seções
  sections = c(
    "SEÇÃO [IVX]+", "SECÇÃO [IVX]+", "SECTION [IVX]+"
  ),
  # Padrões para citações legais
  citations = c(
    "Lei n[ºo] [\\d\\.]+\\/\\d+", "CF\\/\\d+ art\\. \\d+", 
    "Decreto n[ºo] [\\d\\.]+\\/\\d+"
  )
)

# Padrões para notas de rodapé
FOOTNOTE_PATTERNS <- c(
  # Números sobrescritos
  "\\[\\d+\\]", "\\(\\d+\\)", "\\d+\\)", 
  # Padrões comuns para referências de nota de rodapé
  "^\\s*\\d+\\s+\\S+.*$", "^\\s*\\[\\d+\\]\\s+\\S+.*$"
)

# =============================================================================
# Módulo 1: Funções de Utilidade
# =============================================================================

#' Exibe mensagem de ajuda do programa
#'
#' @return NULL
show_help <- function() {
  cat("PDF Processor - Ferramenta para processamento e limpeza de PDFs Jurídicos\n\n")
  cat("Uso: Rscript pdfprocessor.R [opções] arquivo.pdf\n\n")
  cat("Opções:\n")
  cat("  --remove-anexos        Remove anexos do PDF\n")
  cat("  --remove-sumario       Remove sumário (table of contents) do PDF\n")
  cat("  --limpar               Aplica limpeza e organização ao texto extraído\n")
  cat("  --juntar=arquivo.txt   Lista de arquivos PDF para juntar (um por linha)\n")
  cat("  --marcar-footnotes     Marca e organiza notas de rodapé\n")
  cat("  --saida=arquivo.txt    Arquivo de saída (padrão: baseado no nome de entrada)\n")
  cat("  --formato=txt|doc|json Formato de saída (padrão: txt)\n")
  cat("  --config=arquivo.conf  Arquivo de configuração personalizado\n")
  cat("  --modo-juridico        Ativa processamento otimizado para documentos jurídicos\n")
  cat("  --preservar-estrutura  Preserva a estrutura de parágrafos e formatação\n")
  cat("  --ajuda                Exibe esta mensagem de ajuda\n\n")
  cat("Exemplos:\n")
  cat("  Rscript pdfprocessor.R --limpar --marcar-footnotes --modo-juridico documento.pdf\n")
  cat("  Rscript pdfprocessor.R --juntar=lista_pdfs.txt --saida=combinado.pdf\n\n")
}

#' Carrega configurações de um arquivo
#'
#' @param config_file Caminho para o arquivo de configuração
#' @return Lista com configurações carregadas
load_config <- function(config_file = NULL) {
  # Configurações padrão
  config <- list(
    remove_anexos = FALSE,
    remove_sumario = FALSE,
    limpar_texto = FALSE,
    marcar_footnotes = FALSE,
    formato_saida = "txt",
    juntar_pdfs = NULL,
    arquivo_saida = NULL,
    idioma = "pt",
    modo_juridico = FALSE,
    preservar_estrutura = FALSE,
    tagging = FALSE
  )
  
  # Se um arquivo de configuração foi especificado, carregá-lo
  if (!is.null(config_file) && file.exists(config_file)) {
    tryCatch({
      conf_lines <- readLines(config_file, encoding = "UTF-8")
      for (line in conf_lines) {
        if (grepl("^#", line) || nchar(trimws(line)) == 0) next
        parts <- strsplit(line, "=")[[1]]
        if (length(parts) == 2) {
          key <- trimws(parts[1])
          value <- trimws(parts[2])
          
          # Converter string para booleano se necessário
          if (value %in% c("TRUE", "true", "True", "1")) {
            value <- TRUE
          } else if (value %in% c("FALSE", "false", "False", "0")) {
            value <- FALSE
          }
          
          config[[key]] <- value
        }
      }
    }, error = function(e) {
      warning("Erro ao carregar arquivo de configuração: ", conditionMessage(e))
    })
  }
  
  return(config)
}

#' Processa argumentos da linha de comando
#'
#' @param args Argumentos da linha de comando
#' @return Lista com opções processadas
parse_arguments <- function(args) {
  # Definir opções da linha de comando
  option_list <- list(
    make_option("--remove-anexos", action = "store_true", default = FALSE,
                help = "Remove anexos do PDF"),
    make_option("--remove-sumario", action = "store_true", default = FALSE,
                help = "Remove sumário (table of contents) do PDF"),
    make_option("--limpar", action = "store_true", default = FALSE,
                help = "Aplica limpeza e organização ao texto extraído"),
    make_option("--juntar", type = "character", default = NULL,
                help = "Lista de arquivos PDF para juntar (um por linha)"),
    make_option("--marcar-footnotes", action = "store_true", default = FALSE,
                help = "Marca e organiza notas de rodapé"),
    make_option("--saida", type = "character", default = NULL,
                help = "Arquivo de saída"),
    make_option("--formato", type = "character", default = "txt",
                help = "Formato de saída (txt, doc, json)"),
    make_option("--config", type = "character", default = NULL,
                help = "Arquivo de configuração personalizado"),
    make_option("--modo-juridico", action = "store_true", default = FALSE,
                help = "Ativa processamento otimizado para documentos jurídicos"),
    make_option("--preservar-estrutura", action = "store_true", default = FALSE,
                help = "Preserva a estrutura de parágrafos e formatação"),
    make_option("--tagging", action = "store_true", default = FALSE,
                help = "Adiciona tags de marcação para elementos estruturais"),
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
  config$modo_juridico <- opts$options$`modo-juridico`
  config$preservar_estrutura <- opts$options$`preservar-estrutura`
  config$tagging <- opts$options$tagging
  config$arquivo_entrada <- if (length(opts$args) > 0) opts$args[1] else NULL
  
  return(config)
}

# =============================================================================
# Módulo 2: Processamento de PDF
# =============================================================================

#' Extrai texto de um arquivo PDF
#'
#' @param pdf_file Caminho para o arquivo PDF
#' @param use_ocr Usar OCR para melhorar a extração (lógico)
#' @return Texto extraído do PDF
extract_pdf_text <- function(pdf_file, use_ocr = FALSE) {
  if (!file.exists(pdf_file)) {
    stop("Arquivo PDF não encontrado: ", pdf_file)
  }
  
  cat("Extraindo texto de", pdf_file, "...\n")
  
  if (use_ocr) {
    # Extrair usando OCR para melhor qualidade
    cat("Usando OCR para extração de texto...\n")
    
    # Configurar tesseract para documentos jurídicos
    tesseract_config <- tesseract::tesseract(
      language = "por+eng",  # Português e inglês
      options = list(
        tessedit_char_whitelist = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.,;:§-_()[]{}'\"/\\+?!@#$%&*=<>°ºª",
        preserve_interword_spaces = 1
      )
    )
    
    # Converter PDF para imagens e extrair texto
    tryCatch({
      # Extrair páginas como imagens
      images <- pdftools::pdf_convert(pdf_file, dpi = 300)
      
      # Extrair texto de cada imagem
      text <- c()
      for (img in images) {
        page_text <- tesseract::ocr(img, engine = tesseract_config)
        text <- c(text, page_text)
        # Remover arquivo temporário
        if (file.exists(img)) file.remove(img)
      }
    }, error = function(e) {
      warning("Erro ao processar OCR: ", conditionMessage(e))
      # Fallback para extração direta
      text <- pdf_text(pdf_file)
    })
  } else {
    # Extração direta de texto
    text <- pdf_text(pdf_file)
  }
  
  return(text)
}

# =============================================================================
# Módulo 3: Processamento de Documentos Jurídicos
# =============================================================================

#' Detecta elementos jurídicos no texto
#'
#' @param text Texto extraído do PDF
#' @return Lista com elementos jurídicos identificados
detect_legal_elements <- function(text) {
  cat("Detectando elementos jurídicos no texto...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Dividir em linhas para processamento
  lines <- strsplit(full_text, "\n")[[1]]
  
  # Inicializar estrutura para armazenar elementos
  elements <- list(
    articles = list(),
    paragraphs = list(),
    items = list(),
    chapters = list(),
    sections = list(),
    citations = list(),
    footnotes = list()
  )
  
  # Processar cada linha
  for (i in seq_along(lines)) {
    line <- lines[i]
    
    # Detectar artigos
    for (pattern in LEGAL_PATTERNS$articles) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$articles[[length(elements$articles) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
    
    # Detectar parágrafos
    for (pattern in LEGAL_PATTERNS$paragraphs) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$paragraphs[[length(elements$paragraphs) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
    
    # Detectar incisos/itens
    for (pattern in LEGAL_PATTERNS$items) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$items[[length(elements$items) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
    
    # Detectar capítulos
    for (pattern in LEGAL_PATTERNS$chapters) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$chapters[[length(elements$chapters) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
    
    # Detectar seções
    for (pattern in LEGAL_PATTERNS$sections) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$sections[[length(elements$sections) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
    
    # Detectar citações legais
    for (pattern in LEGAL_PATTERNS$citations) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$citations[[length(elements$citations) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract_all(line, pattern)[[1]]
        )
        break
      }
    }
    
    # Detectar notas de rodapé
    for (pattern in FOOTNOTE_PATTERNS) {
      if (grepl(pattern, line, perl = TRUE)) {
        elements$footnotes[[length(elements$footnotes) + 1]] <- list(
          text = line,
          line_number = i,
          match = str_extract(line, pattern)
        )
        break
      }
    }
  }
  
  return(elements)
}

#' Estrutura o texto para documentos jurídicos
#'
#' @param text Texto extraído do PDF
#' @param elements Elementos jurídicos detectados
#' @param config Configurações de processamento
#' @return Texto estruturado
structure_legal_text <- function(text, elements, config) {
  cat("Estruturando texto para formato jurídico...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Dividir em linhas para processamento
  lines <- strsplit(full_text, "\n")[[1]]
  
  # Marcar as linhas que contêm elementos estruturais
  structural_lines <- rep(FALSE, length(lines))
  
  # Função para marcar linhas estruturais
  mark_structural_lines <- function(element_list) {
    for (element in element_list) {
      structural_lines[element$line_number] <<- TRUE
    }
  }
  
  # Marcar todas as linhas estruturais
  mark_structural_lines(elements$articles)
  mark_structural_lines(elements$paragraphs)
  mark_structural_lines(elements$chapters)
  mark_structural_lines(elements$sections)
  
  # Para incisos, considerar a linha e as próximas linhas como um bloco
  for (item in elements$items) {
    structural_lines[item$line_number] <- TRUE
  }
  
  # Processar o texto linha por linha
  processed_lines <- character(0)
  current_paragraph <- character(0)
  in_paragraph <- FALSE
  
  for (i in seq_along(lines)) {
    line <- lines[i]
    is_structural <- structural_lines[i]
    
    # Se for linha estrutural ou em branco, finalizar parágrafo atual
    if (is_structural || trimws(line) == "") {
      if (length(current_paragraph) > 0) {
        # Juntar o parágrafo em uma única linha
        processed_lines <- c(processed_lines, paste(current_paragraph, collapse = " "))
        current_paragraph <- character(0)
        in_paragraph <- FALSE
      }
      
      # Adicionar a linha estrutural
      if (trimws(line) != "") {
        processed_lines <- c(processed_lines, line)
      } else {
        # Adicionar linha em branco apenas se não for repetida
        if (length(processed_lines) == 0 || 
            (length(processed_lines) > 0 && trimws(processed_lines[length(processed_lines)]) != "")) {
          processed_lines <- c(processed_lines, "")
        }
      }
    } else {
      # Continuar acumulando o parágrafo
      current_paragraph <- c(current_paragraph, line)
      in_paragraph <- TRUE
    }
  }
  
  # Adicionar o último parágrafo se existir
  if (length(current_paragraph) > 0) {
    processed_lines <- c(processed_lines, paste(current_paragraph, collapse = " "))
  }
  
  # Se configurado para adicionar tags, adicionar marcações
  if (config$tagging) {
    processed_lines <- add_structural_tags(processed_lines, elements)
  }
  
  return(processed_lines)
}

#' Adiciona tags de marcação aos elementos estruturais
#'
#' @param lines Linhas de texto processadas
#' @param elements Elementos jurídicos detectados
#' @return Texto com tags de marcação
add_structural_tags <- function(lines, elements) {
  cat("Adicionando tags de marcação estrutural...\n")
  
  # Mapear números de linha para índices no vetor processado
  line_mapping <- data.frame(
    original_line = sapply(elements$articles, function(e) e$line_number),
    element_type = rep("article", length(elements$articles)),
    match = sapply(elements$articles, function(e) e$match)
  )
  
  line_mapping <- rbind(line_mapping, data.frame(
    original_line = sapply(elements$paragraphs, function(e) e$line_number),
    element_type = rep("paragraph", length(elements$paragraphs)),
    match = sapply(elements$paragraphs, function(e) e$match)
  ))
  
  line_mapping <- rbind(line_mapping, data.frame(
    original_line = sapply(elements$chapters, function(e) e$line_number),
    element_type = rep("chapter", length(elements$chapters)),
    match = sapply(elements$chapters, function(e) e$match)
  ))
  
  line_mapping <- rbind(line_mapping, data.frame(
    original_line = sapply(elements$sections, function(e) e$line_number),
    element_type = rep("section", length(elements$sections)),
    match = sapply(elements$sections, function(e) e$match)
  ))
  
  line_mapping <- rbind(line_mapping, data.frame(
    original_line = sapply(elements$items, function(e) e$line_number),
    element_type = rep("item", length(elements$items)),
    match = sapply(elements$items, function(e) e$match)
  ))
  
  # Ordenar pelo número da linha original
  if (nrow(line_mapping) > 0) {
    line_mapping <- line_mapping[order(line_mapping$original_line), ]
  }
  
  # Adicionar tags
  tagged_lines <- lines
  for (i in seq_len(nrow(line_mapping))) {
    element <- line_mapping[i, ]
    # Encontrar a linha correspondente no texto processado
    for (j in seq_along(tagged_lines)) {
      if (grepl(element$match, tagged_lines[j], fixed = TRUE)) {
        # Adicionar tag
        tag_open <- paste0("<", element$element_type, ">")
        tag_close <- paste0("</", element$element_type, ">")
        tagged_lines[j] <- paste0(tag_open, tagged_lines[j], tag_close)
        break
      }
    }
  }
  
  return(tagged_lines)
}

#' Aplica limpeza e organização ao texto jurídico
#'
#' @param text Texto extraído do PDF
#' @param elements Elementos jurídicos detectados
#' @return Texto limpo e organizado
clean_legal_text <- function(text, elements) {
  cat("Aplicando limpeza e organização ao texto jurídico...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Remover múltiplos espaços em branco
  full_text <- str_replace_all(full_text, "\\s+", " ")
  
  # 2. Corrigir quebras de linha em parágrafos, preservando elementos estruturais
  lines <- strsplit(full_text, "\n")[[1]]
  
  # Criar uma máscara para linhas que contêm elementos estruturais
  structural_lines <- rep(FALSE, length(lines))
  
  # Função para marcar linhas estruturais
  mark_lines <- function(element_list) {
    for (element in element_list) {
      if (element$line_number <= length(structural_lines)) {
        structural_lines[element$line_number] <<- TRUE
      }
    }
  }
  
  # Marcar todas as linhas estruturais
  mark_lines(elements$articles)
  mark_lines(elements$paragraphs)
  mark_lines(elements$chapters)
  mark_lines(elements$sections)
  mark_lines(elements$items)
  
  # 3. Aplicar regras de limpeza específicas para documentos jurídicos
  
  # 3.1 Preservar quebras de linha em elementos estruturais
  for (i in seq_along(lines)) {
    if (structural_lines[i]) {
      # Garantir que elementos estruturais tenham quebras de linha antes e depois
      if (i > 1 && !grepl("^\\s*$", lines[i-1])) {
        lines[i-1] <- paste0(lines[i-1], "\n")
      }
      if (i < length(lines) && !grepl("^\\s*$", lines[i+1])) {
        lines[i] <- paste0(lines[i], "\n")
      }
    }
  }
  
  # 3.2 Juntar linhas que formam parágrafos contínuos
  i <- 1
  while (i < length(lines)) {
    if (!structural_lines[i] && !structural_lines[i+1] && 
        !grepl("^\\s*$", lines[i]) && !grepl("^\\s*$", lines[i+1])) {
      # Verificar se a linha termina com pontuação
      if (!grepl("[.!?:;]\\s*$", lines[i])) {
        # Juntar com a próxima linha
        lines[i] <- paste(lines[i], lines[i+1])
        # Remover a próxima linha
        lines <- lines[-(i+1)]
        # Atualizar structural_lines
        structural_lines <- structural_lines[-(i+1)]
      } else {
        i <- i + 1
      }
    } else {
      i <- i + 1
    }
  }
  
  # 4. Normalizar espaços após pontuação
  full_text <- paste(lines, collapse = "\n")
  full_text <- str_replace_all(full_text, "([.!?:;])\\s*", "\\1 ")
  
  # 5. Remover linhas em branco consecutivas
  full_text <- str_replace_all(full_text, "\n{3,}", "\n\n")
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}

#' Processa notas de rodapé em documentos jurídicos
#'
#' @param text Texto extraído do PDF
#' @param elements Elementos jurídicos detectados
#' @return Texto com notas de rodapé processadas
process_legal_footnotes <- function(text, elements) {
  cat("Processando notas de rodapé em formato jurídico...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Dividir em linhas para processamento
  lines <- strsplit(full_text, "\n")[[1]]
  
  # Extrair notas de rodapé
  footnotes <- elements$footnotes
  
  if (length(footnotes) > 0) {
    # Ordenar notas de rodapé por número da linha
    footnote_lines <- sapply(footnotes, function(fn) fn$line_number)
    footnotes <- footnotes[order(footnote_lines)]
    
    # Criar mapa de notas de rodapé
    footnote_map <- list()
    
    for (fn in footnotes) {
      # Extrair número da nota de rodapé
      fn_num <- str_extract(fn$match, "\\d+")
      if (!is.na(fn_num)) {
        footnote_map[[fn_num]] <- fn$text
      }
    }
    
    # Processar referências a notas de rodapé no texto
    for (i in seq_along(lines)) {
      for (fn_num in names(footnote_map)) {
        # Padrão para encontrar referências numéricas
        pattern <- paste0("\\b", fn_num, "\\b")
        
        # Se não for uma linha de nota de rodapé e contiver referência
        if (!i %in% footnote_lines && grepl(pattern, lines[i])) {
          # Marcar referência claramente
          lines[i] <- gsub(pattern, paste0("[fn:", fn_num, "]"), lines[i])
        }
      }
    }
    
    # Remover as linhas de notas de rodapé do corpo do texto
    lines <- lines[-footnote_lines]
    
    # Adicionar seção de notas de rodapé no final
    lines <- c(
      lines,
      "",
      "--- NOTAS DE RODAPÉ ---",
      ""
    )
    
    # Adicionar cada nota de rodapé formatada
    for (fn_num in names(footnote_map)) {
      fn_text <- footnote_map[[fn_num]]
      # Limpar formatação da nota
      fn_text <- gsub(paste0("^\\s*", fn_num, "\\s*"), "", fn_text)
      lines <- c(lines, paste0("[fn:", fn_num, "] ", fn_text))
    }
  }
  
  return(lines)
}

#' Gera saída em formato JSON para documentos jurídicos
#'
#' @param text Texto processado
#' @param elements Elementos jurídicos detectados
#' @return String JSON
generate_json_output <- function(text, elements) {
  cat("Gerando saída em formato JSON...\n")
  
  # Criar estrutura de dados para JSON
  document <- list(
    content = paste(text, collapse = "\n"),
    structure = list(
      articles = lapply(elements$articles, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      }),
      paragraphs = lapply(elements$paragraphs, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      }),
      chapters = lapply(elements$chapters, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      }),
      sections = lapply(elements$sections, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      }),
      items = lapply(elements$items, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      }),
      footnotes = lapply(elements$footnotes, function(e) {
        list(
          text = e$text,
          position = e$line_number
        )
      })
    )
  )
  
  # Converter para JSON
  json_output <- jsonlite::toJSON(document, pretty = TRUE, auto_unbox = TRUE)
  
  return(json_output)
}

# =============================================================================
# Módulo 4: Processamento de PDF Básico (original)
# =============================================================================

#' Detecta e remove anexos do texto extraído
#'
#' @param text Texto extraído do PDF
#' @param keywords Palavras-chave para identificar anexos
#' @return Texto sem anexos
remove_anexos <- function(text, keywords = ANEXO_KEYWORDS) {
  cat("Removendo anexos...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Criar padrão regex para encontrar anexos
  pattern <- paste0("(?i)(", paste(keywords, collapse = "|"), ")\\s+[A-Z0-9]+")
  
  # Encontrar todas as ocorrências de início de anexos
  matches <- str_match_all(full_text, pattern)[[1]]
  
  if (length(matches) > 0) {
    # Para cada anexo encontrado, remover o conteúdo
    for (match in matches[,1]) {
      # Encontrar a posição do início do anexo
      start_pos <- str_locate(full_text, fixed(match))[1]
      
      # Determinar o fim do anexo (próximo anexo ou fim do documento)
      next_matches <- matches[matches[,1] != match, 1]
      next_positions <- sapply(next_matches, function(m) str_locate(full_text, fixed(m))[1])
      next_positions <- next_positions[next_positions > start_pos]
      
      end_pos <- if (length(next_positions) > 0) min(next_positions) - 1 else nchar(full_text)
      
      # Remover o anexo
      full_text <- paste0(
        substr(full_text, 1, start_pos - 1),
        substr(full_text, end_pos, nchar(full_text))
      )
    }
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}

#' Detecta e remove sumário do texto extraído
#'
#' @param text Texto extraído do PDF
#' @param keywords Palavras-chave para identificar sumários
#' @return Texto sem sumário
remove_sumario <- function(text, keywords = TOC_KEYWORDS) {
  cat("Removendo sumário...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # Criar padrão regex para encontrar sumários
  pattern <- paste0("(?i)(", paste(keywords, collapse = "|"), ")")
  
  # Encontrar a ocorrência do sumário
  match <- str_match(full_text, pattern)
  
  if (!is.na(match[1,1])) {
    # Encontrar a posição do início do sumário
    start_pos <- str_locate(full_text, fixed(match[1,1]))[1]
    
    # Determinar o fim do sumário (próximo capítulo ou seção)
    section_pattern <- paste0("(?i)(", paste(HEADING_KEYWORDS, collapse = "|"), ")\\s+[A-Z0-9]+")
    section_match <- str_match(substr(full_text, start_pos, nchar(full_text)), section_pattern)
    
    if (!is.na(section_match[1,1])) {
      section_pos <- str_locate(substr(full_text, start_pos, nchar(full_text)), fixed(section_match[1,1]))[1]
      end_pos <- start_pos + section_pos - 2
    } else {
      # Se não encontrar próxima seção, estimar fim do sumário (50 linhas)
      lines_after <- strsplit(substr(full_text, start_pos, nchar(full_text)), "\n")[[1]]
      end_lines <- min(50, length(lines_after))
      end_text <- paste(lines_after[1:end_lines], collapse = "\n")
      end_pos <- start_pos + nchar(end_text)
    }
    
    # Remover o sumário
    full_text <- paste0(
      substr(full_text, 1, start_pos - 1),
      substr(full_text, end_pos, nchar(full_text))
    )
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}

#' Aplica limpeza e organização ao texto extraído
#'
#' @param text Texto extraído do PDF
#' @return Texto limpo e organizado
clean_text <- function(text) {
  cat("Aplicando limpeza e organização ao texto...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Remover múltiplos espaços em branco
  full_text <- str_replace_all(full_text, "\\s+", " ")
  
  # 2. Corrigir quebras de linha em parágrafos
  # Identificar padrões de quebra de linha incorreta (linha termina sem pontuação)
  full_text <- str_replace_all(full_text, "([^.!?:])\\n([a-z])", "\\1 \\2")
  
  # 3. Preservar quebras de linha em cabeçalhos e itens numerados
  # Criar padrão para cabeçalhos
  heading_pattern <- paste0("(?i)(", paste(HEADING_KEYWORDS, collapse = "|"), ")\\s+[A-Z0-9]+")
  
  # Garantir que cabeçalhos tenham quebras de linha antes e depois
  full_text <- str_replace_all(full_text, paste0("([^\n])(", heading_pattern, ")"), "\\1\n\n\\2")
  full_text <- str_replace_all(full_text, paste0("(", heading_pattern, ")([^\n])"), "\\1\n\n\\2")
  
  # 4. Preservar itens numerados e marcadores
  full_text <- str_replace_all(full_text, "(^|\\n)(\\d+\\.\\s)", "\\1\n\\2")
  full_text <- str_replace_all(full_text, "(^|\\n)([a-z]\\)\\s)", "\\1\n\\2")
  
  # 5. Normalizar espaços após pontuação
  full_text <- str_replace_all(full_text, "([.!?:])\\s*", "\\1 ")
  
  # 6. Remover linhas em branco consecutivas
  full_text <- str_replace_all(full_text, "\n{3,}", "\n\n")
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}

#' Junta múltiplos arquivos PDF em um único arquivo
#'
#' @param pdf_list Lista de caminhos para arquivos PDF ou arquivo com lista
#' @param output_file Caminho para o arquivo PDF de saída
#' @return Caminho para o arquivo PDF combinado
merge_pdfs <- function(pdf_list, output_file) {
  # Verificar se pdf_list é um arquivo ou uma lista
  if (length(pdf_list) == 1 && file.exists(pdf_list)) {
    # Ler lista de arquivos do arquivo
    pdf_files <- readLines(pdf_list, encoding = "UTF-8")
    pdf_files <- pdf_files[pdf_files != ""]
  } else {
    pdf_files <- pdf_list
  }
  
  # Verificar se todos os arquivos existem
  missing_files <- pdf_files[!file.exists(pdf_files)]
  if (length(missing_files) > 0) {
    stop("Arquivos não encontrados: ", paste(missing_files, collapse = ", "))
  }
  
  cat("Juntando", length(pdf_files), "arquivos PDF...\n")
  
  # Usar qpdf para juntar os PDFs
  qpdf::pdf_combine(pdf_files, output_file)
  
  cat("PDFs combinados com sucesso em", output_file, "\n")
  return(output_file)
}

#' Identifica e marca notas de rodapé no texto
#'
#' @param text Texto extraído do PDF
#' @return Texto com notas de rodapé marcadas
mark_footnotes <- function(text) {
  cat("Identificando e marcando notas de rodapé...\n")
  
  # Juntar todo o texto
  full_text <- paste(text, collapse = "\n")
  
  # 1. Identificar padrões de notas de rodapé
  # Padrão comum: número seguido de texto
  footnote_pattern <- "(?m)^\\s*(\\d+)\\s+([^\n]+)"
  
  # Encontrar todas as ocorrências de notas de rodapé
  footnotes <- str_match_all(full_text, footnote_pattern)[[1]]
  
  if (nrow(footnotes) > 0) {
    # Criar mapa de notas de rodapé
    footnote_map <- setNames(
      footnotes[, 3],
      footnotes[, 2]
    )
    
    # 2. Identificar referências a notas de rodapé no texto
    # Padrão comum: número sobrescrito
    ref_pattern <- "\\b(\\d+)\\b"
    
    # Para cada nota de rodapé, verificar referências no texto
    for (fn_id in names(footnote_map)) {
      # Encontrar referências que correspondem ao ID da nota
      ref_matches <- str_match_all(full_text, ref_pattern)[[1]]
      ref_matches <- ref_matches[ref_matches[, 2] == fn_id, , drop = FALSE]
      
      if (nrow(ref_matches) > 0) {
        # Substituir referências por marcação clara
        for (i in 1:nrow(ref_matches)) {
          ref_text <- ref_matches[i, 1]
          marked_text <- paste0("[fn:", fn_id, "]")
          full_text <- str_replace(full_text, fixed(ref_text), marked_text)
        }
      }
    }
    
    # 3. Mover todas as notas de rodapé para o final do documento
    # Remover as notas de rodapé do texto principal
    for (i in 1:nrow(footnotes)) {
      full_text <- str_replace(full_text, fixed(footnotes[i, 1]), "")
    }
    
    # Adicionar seção de notas de rodapé no final
    full_text <- paste0(
      full_text,
      "\n\n--- NOTAS DE RODAPÉ ---\n\n"
    )
    
    # Adicionar cada nota de rodapé
    for (fn_id in names(footnote_map)) {
      full_text <- paste0(
        full_text,
        "[fn:", fn_id, "] ", footnote_map[fn_id], "\n"
      )
    }
  }
  
  # Dividir de volta em linhas
  return(strsplit(full_text, "\n")[[1]])
}

# =============================================================================
# Função Principal
# =============================================================================

#' Função principal que coordena o processamento de PDFs
#'
#' @param config Configurações do programa
#' @return Caminho para o arquivo de saída
process_pdf <- function(config) {
  # Verificar se é uma operação de junção de PDFs
  if (!is.null(config$juntar_pdfs)) {
    output_file <- config$arquivo_saida
    if (is.null(output_file)) {
      output_file <- "pdfs_combinados.pdf"
    }
    return(merge_pdfs(config$juntar_pdfs, output_file))
  }
  
  # Processar arquivo PDF ou TXT individual
  input_file <- config$arquivo_entrada
  if (is.null(input_file) || !file.exists(input_file)) {
    stop("Arquivo de entrada não especificado ou não encontrado")
  }
  
  # Verificar extensão do arquivo
  file_ext <- tolower(tools::file_ext(input_file))
    # Determinar arquivo de saída
  output_file <- config$arquivo_saida
  if (is.null(output_file)) {
    # Criar nome de saída baseado no nome de entrada
    base_name <- tools::file_path_sans_ext(basename(input_file))
    output_file <- paste0(base_name, "_processado.", config$formato_saida)
  }
  
  # Extrair texto do PDF ou ler arquivo TXT
  text <- NULL
  if (file_ext == "pdf") {
    text <- extract_pdf_text(input_file, use_ocr = TRUE)
  } else if (file_ext == "txt") {
    cat("Lendo arquivo de texto:", input_file, "\n")
    text <- readLines(input_file, encoding = "UTF-8")
  } else {
    stop("Formato de arquivo não suportado: ", file_ext, ". Use PDF ou TXT")
  }
  
  # Verificar se o modo jurídico está ativado
  if (config$modo_juridico) {
    # Detectar elementos jurídicos
    elements <- detect_legal_elements(text)
    
    # Aplicar processamentos para documentos jurídicos
    if (config$remove_anexos) {
      text <- remove_anexos(text)
    }
    
    if (config$remove_sumario) {
      text <- remove_sumario(text)
    }
    
    if (config$limpar_texto) {
      text <- clean_legal_text(text, elements)
    }
    
    if (config$marcar_footnotes) {
      text <- process_legal_footnotes(text, elements)
    }
    
    # Estruturar o texto conforme configuração
    if (config$preservar_estrutura) {
      text <- structure_legal_text(text, elements, config)
    }
    
    # Gerar saída conforme formato especificado
    if (config$formato_saida == "json") {
      # Gerar JSON e salvar
      json_content <- generate_json_output(text, elements)
      writeLines(json_content, output_file, useBytes = TRUE)
    } else {
      # Salvar como texto
      writeLines(text, output_file, useBytes = TRUE)
    }
  } else {
    # Processamento padrão (não-jurídico)
    if (config$remove_anexos) {
      text <- remove_anexos(text)
    }
    
    if (config$remove_sumario) {
      text <- remove_sumario(text)
    }
    
    if (config$limpar_texto) {
      text <- clean_text(text)
    }
    
    if (config$marcar_footnotes) {
      text <- mark_footnotes(text)
    }
    
    # Salvar resultado
    writeLines(text, output_file, useBytes = TRUE)
  }
  
  cat("Arquivo processado salvo em", output_file, "\n")
  return(output_file)
}

# =============================================================================
# Execução do programa
# =============================================================================

# Verificar se o script está sendo executado diretamente
if (!interactive()) {
  # Obter argumentos da linha de comando (excluindo o nome do script)
  args <- commandArgs(trailingOnly = TRUE)
  
  # Processar argumentos
  config <- parse_arguments(args)
  
  # Executar processamento
  tryCatch({
    output_file <- process_pdf(config)
    cat("Processamento concluído com sucesso!\n")
    cat("Resultado salvo em:", output_file, "\n")
  }, error = function(e) {
    cat("ERRO durante o processamento:", conditionMessage(e), "\n")
    quit(status = 1)
  })
}
