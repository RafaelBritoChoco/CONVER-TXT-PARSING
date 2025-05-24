# DOCX/DOC to Structured TXT Converter

## 1. Overview

This Python script, `docx_to_text.py`, is designed to convert Microsoft Word `.docx` and older `.doc` files into a structured plain text (`.txt`) format. It is particularly tailored for processing documents (such as legal texts) where preserving titles, consolidating paragraph content, and handling footnotes in a specific custom manner are important. The script identifies titles based on common heuristics, formats paragraphs into single lines, and replaces Word's native footnote references with a custom `//FOOTNOTENUMBER{N}` marker, appending the footnote content in a structured `//FOOTNOTE` block immediately after the referencing paragraph.

## 2. Features

*   **DOCX Processing:** Natively processes `.docx` files using the `python-docx` library.
*   **DOC Processing:** Supports `.doc` files by automatically converting them to `.docx` using `unoconv` and LibreOffice (requires these to be installed).
*   **Title Detection:** Identifies titles based on heuristics:
    *   Starts with "CHAPTER" (case-insensitive) followed by a number.
    *   Starts with "Article" (case-insensitive) followed by a number/identifier.
    *   Paragraph is in ALL CAPS (and longer than 5 characters).
*   **Paragraph Formatting:** Consolidates each non-title paragraph into a single line of text by replacing internal newlines and tabs with a single space.
*   **Custom Footnote Handling:**
    *   Replaces Word's native footnote references in the text with a custom marker: `//FOOTNOTENUMBER{N}` (where `N` is a sequential number).
    *   Appends a detailed footnote block immediately after each paragraph that contains footnote references. This block is formatted as:
        ```
        //FOOTNOTE
        N Footnote text content here...
        ```
*   **Sequential Footnote Numbering:** Ensures that `N` in the footnote markers and blocks is sequential throughout the document, starting from 1.

## 3. Requirements

*   **Python 3.x** (developed and tested with Python 3.6+)
*   **`python-docx` library:** For parsing `.docx` files.
*   **For `.doc` file processing (optional):**
    *   `unoconv`: A command-line utility for document conversion.
    *   LibreOffice: Required by `unoconv` for the conversion process. Must be installed and accessible in the system's PATH.

## 4. Installation/Setup

1.  **Clone the repository or download the script.**

2.  **Set up a virtual environment (recommended):**
    ```bash
    python3 -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    ```

3.  **Install `python-docx`:**
    ```bash
    pip install python-docx
    ```

4.  **Install `unoconv` and LibreOffice (if `.doc` support is needed):**
    *   **On Debian/Ubuntu:**
        ```bash
        sudo apt-get update && sudo apt-get install -y unoconv libreoffice
        ```
    *   **On other systems (e.g., macOS, Windows):**
        *   Install LibreOffice from the official website.
        *   `unoconv` might require separate installation. On macOS, if you have Homebrew: `brew install unoconv`. For Windows, `unoconv` setup can be more involved and might require ensuring LibreOffice's `soffice` binary is in the PATH. Refer to `unoconv` documentation for specific instructions.

## 5. How to Run

The script is executed from the command line, requiring the input file path and the desired output file path as arguments.

**Command-line syntax:**
```bash
python docx_to_text.py <input_file> <output_file>
```

**Example:**
```bash
python docx_to_text.py "MyLegalDocument.docx" "ProcessedOutput.txt"
```
Or, for an older `.doc` file:
```bash
python docx_to_text.py "OldContract.doc" "Contract_Processed.txt"
```

*   **Supported input file types:** `.docx`, `.doc`

## 6. Input Document Assumptions/Limitations

*   **Title Detection Heuristics:**
    *   Titles are identified if a paragraph starts with "CHAPTER" (case-insensitive) followed by a number, "Article" (case-insensitive) followed by a number/identifier, or if the entire paragraph text is in ALL CAPS (and longer than 5 characters).
    *   Documents not adhering to these patterns might not have titles correctly identified. The script does not currently use Word styles (e.g., "Heading 1") for title detection.
*   **Footnote Extraction:**
    *   The script is designed to extract footnotes that are created using Word's built-in footnote functionality. Manually typed references (e.g., "[1]" in the text with details at the end of the document but not as a Word footnote object) will not be processed as footnotes.
*   **`.doc` Conversion Dependency:**
    *   Processing of `.doc` files is entirely dependent on a successful conversion by `unoconv` and LibreOffice. If these are not installed correctly, not found in the system PATH, or if `unoconv` fails to convert the specific `.doc` file for any reason, the script will not be able to process it.
*   **File Paths:** Ensure that the provided input and output file paths are correct and that the script has the necessary read/write permissions.

## 7. Output Format

The output is a plain `.txt` file with the following characteristics:

*   **Titles:** Preserved on their own lines. The script's console output will indicate "[TITLE DETECTED]" or "[PARAGRAPH DETECTED]" before printing the line to the file, but these markers themselves are not part of the file content unless explicitly added by a version of the script. (Note: The current version of the script writes the text directly, the `[TITLE DETECTED]` messages are console only during processing).
*   **Paragraphs:** Each non-title paragraph from the source document is presented as a single line of text. Any internal newlines or tabs within a paragraph are replaced with a single space.
*   **Footnote Markers:** Word footnote references are replaced in the paragraph text by `//FOOTNOTENUMBER{N}`, where `N` is a sequential integer (e.g., `//FOOTNOTENUMBER{1}`).
*   **Footnote Blocks:** Immediately following each paragraph that contains one or more footnote markers, a block detailing these footnotes is inserted:
    ```
    //FOOTNOTE
    1 This is the text of the first footnote.
    //FOOTNOTE
    2 This is the text of the second footnote (if the paragraph had multiple).
    ```
    Each footnote within the block starts with its corresponding serial number `N`, followed by its text (which has also had internal newlines/tabs replaced by spaces).

**Example Snippet of Output:**

```
CHAPTER 1: A NEW BEGINNING

This is the first paragraph of the introduction. It might span multiple lines in the original document but will be a single line here.

This second paragraph has a reference to a footnote here //FOOTNOTENUMBER{1} and perhaps another one here //FOOTNOTENUMBER{2}.
//FOOTNOTE
1 Details for the first footnote mentioned.
//FOOTNOTE
2 Details for the second footnote.

Another paragraph follows.
```
