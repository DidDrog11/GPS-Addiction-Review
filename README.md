# Use of GPS to detect, predict and intervene on addictive behaviours: A Systematic Review

## Overview
This repository contains the code and reproducible workflow for a systematic review examining the use of GPS data in addiction research. The review protocol is registered at [PROSPERO LINK / OSF LINK].

**Note:** This repository contains *code only*. Raw search results and full-text PDFs are stored in a secured location to comply with copyright and privacy standards.

## Workflow & Directory Structure

The project follows a linear 8-step workflow, divided into **Phase A (Screening)** and **Phase B (Extraction)**.

### Phase A: Search & Screening
**Goal:** Convert raw database exports into a clean list for screening.

1.  **Searches Run:** Raw `.ris` or `.bib` files are saved locally in `data/01_raw_searches/`.
2.  **Deduplication:**
    * *Script:* `code/01_search_cleaning/01_deduplication.R`
    * *Action:* Merges files and removes duplicates.
3.  **String Matching & Specificity Check:**
    * *Script:* `code/01_search_cleaning/02_string_matching.R`
    * *Action:* Filters citations based on exclusion keywords to reduce noise before human screening.
4.  **Rayyan Upload:**
    * *Script:* `code/01_search_cleaning/03_export_for_rayyan.R`
    * *Action:* Generates a standard import file for Rayyan.
    * *Manual Step:* Team screens Title/Abstracts in Rayyan.

### Phase B: Extraction & Analysis
**Goal:** Link included studies to full texts and extract data into the cloud.

5.  **Full Text Retrieval:**
    * Included articles are identified from Rayyan export.
    * PDFs are stored in the shared Google Drive folder.
6.  **Master Linking List:**
    * A "Master List" Google Sheet is created containing: `Study_ID`, `Title`, `Year`, `PDF_Link`.
7.  **Data Extraction (Google Sheets):**
    * Extractors work in individual Google Sheets.
    * Sheets are generated from the template.
    * *Constraint:* Columns A-E (Study Metadata) are protected; extractors enter data in Columns F onwards.
8.  **Data Processing (R + Google Drive API):**
    * *Script:* `code/02_extraction_analysis/01_fetch_extraction_data.R`
    * *Action:* Authenticates via `googledrive` package, pulls all extraction sheets, binds them into a single dataset, and runs quality checks (e.g., checking for invalid GPS feature definitions).

## Setup & Dependencies

### Prerequisites
* R (v4.0+)
* A Google Account with access to the Shared Drive.

### Installation
1.  Clone this repository.
2.  Open `GPS-Addiction-Review.Rproj`.
3.  Install dependencies:
    ```r
    install.packages(c("tidyverse", "terra", "litsearchr", "googledrive", "googlesheets4"))
    ```

### Authentication
This project uses the `googledrive` package. On first run of any Phase B script, you will be asked to authenticate in your browser. A local token will be cached in `.secrets/` (which is git-ignored).

## License
MIT License