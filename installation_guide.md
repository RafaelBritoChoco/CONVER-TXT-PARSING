# Installation Guide for PDF to TXT Processor

## 1. Install R Programming Language

1. Download R from the official website:
   - Go to: https://cran.r-project.org/bin/windows/base/
   - Click on "Download R-x.x.x for Windows" (latest version)

2. Run the installer:
   - Accept the default settings
   - Make sure to check "Add R to PATH" during installation if available

3. Verify installation:
   - Open PowerShell and type `R --version`
   - If installed correctly, you should see version information

## 2. Install RStudio (Optional but Recommended)

1. Download RStudio Desktop (Free) from:
   - https://posit.co/download/rstudio-desktop/

2. Run the installer with default settings

## 3. Install Required R Packages

The script will attempt to install these automatically, but you can pre-install them by opening R or RStudio and running:

```r
install.packages(c(
  "pdftools",     # PDF manipulation
  "tesseract",    # OCR capabilities
  "stringr",      # String manipulation
  "stringi",      # String internationalization
  "qpdf",         # Advanced PDF handling
  "docxtractr",   # DOCX processing
  "optparse",     # Command-line interface
  "data.table",   # Efficient data processing
  "magrittr",     # Pipeline operations
  "parallel"      # Parallel processing
))
```

## 4. Additional System Dependencies

For OCR functionality:
- Tesseract OCR engine will be installed with the R package
- For better results with legal documents, you may want additional language data packages

## 5. Sample Usage (After Installation)

Process a legal document PDF:
```
Rscript pdfprocessor.R --limpar --marcar-footnotes --remove-sumario "C:\path\to\your\legal_document.pdf" --saida="C:\path\to\output\legal_document.txt"
```
