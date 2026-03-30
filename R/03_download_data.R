# -------------------------------------------------------------------------
# Script: 03_download_data.R
# Purpose: Download extraction and dictionary sheets from Google Drive.
# Author: David Simons
# Date: 2026-03-30
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. Authentication
# -------------------------------------------------------------------------
# Run this interactively once to cache your Google credentials.
# googlesheets4::gs4_auth() 

# 2. Define Google Sheet URLs/IDs
# -------------------------------------------------------------------------
url_ext_1 <- "https://docs.google.com/spreadsheets/d/1Qczi3KtAgCIcSWKmEm6tOqCBO0hUHxmlhUXBiCTkcxQ/edit?gid=2016267919#gid=2016267919"
url_ext_2 <- "https://docs.google.com/spreadsheets/d/1NXWH9WJAKAZ6TtDWxxju2Jk_1xBb017P70X4Xzg9mWk/edit?gid=2016267919#gid=2016267919"
url_dicts <- "https://docs.google.com/spreadsheets/d/1yVReeLtrgGHIzBqAPm7sLajIZ3ey-R4xM8-yuO-hFfU/edit?gid=388455683#gid=388455683"

# 3. Helper Function: Download All Tabs
# -------------------------------------------------------------------------
download_all_tabs <- function(sheet_url) {
  # Get the names of all sheets (tabs) in the workbook
  tab_names <- sheet_properties(sheet_url) |> 
    pull(name)
  
  # Map over the tab names and read each one into a named list
  map(set_names(tab_names), ~ read_sheet(sheet_url, sheet = .x))
}

# 4. Download the Data
# -------------------------------------------------------------------------
# Extraction sheets
list_ext_1 <- download_all_tabs(url_ext_1)
list_ext_2 <- download_all_tabs(url_ext_2)

# Dictionary
list_dicts <- download_all_tabs(url_dicts)

# 5. Save Lists Locally
# -------------------------------------------------------------------------
saveRDS(list_ext_1, here("data", "03_for_extraction", "raw_extraction_1.rds"))
saveRDS(list_ext_2, here("data", "03_for_extraction", "raw_extraction_2.rds"))
saveRDS(list_dicts, here("dictionaries", "raw_dictionaries.rds"))
