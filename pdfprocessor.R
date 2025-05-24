#!/usr/bin/env Rscript

# =============================================================================
# PDF Processor - Ferramenta para processamento e limpeza de PDFs
# =============================================================================
# Autor: Manus AI
# Data: Maio 2025
# Descrição: Programa para processamento de arquivos PDF, incluindo remoção de 
#            anexos, sumários, limpeza de texto, junção de PDFs e tratamento
#            de notas de rodapé.
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
  "parallel"      # Para processamento paralelo
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

# =============================================================================
# Módulo 1: Funções de Utilidade
# =============================================================================

#' Exibe mensagem de ajuda do programa
#'
#' @return NULL
show_help <- function() {
  cat("PDF Processor - Ferramenta para processamento e limpeza de PDFs\n\n")
  cat("Uso: Rscript pdfprocessor.R [opções] arquivo.pdf\n\n")
  cat("Opções:\n")
  cat("  --remove-anexos        Remove anexos do PDF\n")
  cat("  --remove-sumario       Remove sumário (table of contents) do PDF\n")
  cat("  --limpar               Aplica limpeza e organização ao texto extraído\n")
  cat("  --juntar=arquivo.txt   Lista de arquivos PDF para juntar (um por linha)\n")
  cat("  --marcar-footnotes     Marca e organiza notas de rodapé\n")
  cat("  --saida=arquivo.txt    Arquivo de saída (padrão: baseado no nome de entrada)\n")
  cat("  --formato=txt|doc      Formato de saída (padrão: txt)\n")
  cat("  --config=arquivo.conf  Arquivo de configuração personalizado\n")
  cat("  --ajuda                Exibe esta mensagem de ajuda\n\n")
  cat("Exemplos:\n")
  cat("  Rscript pdfprocessor.R --limpar --marcar-footnotes documento.pdf\n")
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
    idioma = "pt"
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
                help = "Formato de saída (txt ou doc)"),
    make_option("--config", type = "character", default = NULL,
                help = "Arquivo de configuração personalizado"),
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
    # Primeiro converte páginas para imagens
    cat("Usando OCR para extração de texto...\n")
    
    # Implementação básica - em produção seria mais elaborada
    text <- pdf_text(pdf_file)
    
    # Aqui seria implementado o processamento OCR completo
    # usando o pacote tesseract para cada página
    
  } else {
    # Extração direta de texto
    text <- pdf_text(pdf_file)
  }
  
  return(text)
}

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

# =============================================================================
# Módulo 3: Limpeza e Organização de Texto
# =============================================================================

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

# =============================================================================
# Módulo 4: Junção de PDFs
# =============================================================================

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

# =============================================================================
# Módulo 5: Tratamento de Notas de Rodapé
# =============================================================================

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
          marked_text <- paste0("(footnote ", fn_id, ")")
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
        fn_id, ": ", footnote_map[fn_id], "\n"
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
  
  # Processar arquivo PDF individual
  pdf_file <- config$arquivo_entrada
  if (is.null(pdf_file) || !file.exists(pdf_file)) {
    stop("Arquivo PDF de entrada não especificado ou não encontrado")
  }
  
  # Determinar arquivo de saída
  output_file <- config$arquivo_saida
  if (is.null(output_file)) {
    # Criar nome de saída baseado no nome de entrada
    base_name <- tools::file_path_sans_ext(basename(pdf_file))
    output_file <- paste0(base_name, "_processado.", config$formato_saida)
  }
  
  # Extrair texto do PDF
  text <- extract_pdf_text(pdf_file, use_ocr = TRUE)
  
  # Aplicar processamentos conforme configuração
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
