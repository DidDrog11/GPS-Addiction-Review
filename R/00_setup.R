# -------------------------------------------------------------------------
# Script: 00_setup.R
# Purpose: Install and load necessary packages, and ensure directory structure exists.
# Author: David Simons
# Date: 2025-11-28
# -------------------------------------------------------------------------

# 1. Install pacman if not already installed
# -------------------------------------------------------------------------
if (!require("pacman")) install.packages("pacman")

# 2. Load packages
# -------------------------------------------------------------------------
pacman::p_load(
  # Core Data Manipulation & Tidyverse
  tidyverse,      # Includes dplyr, ggplot2, stringr, readr, etc.
  here,           # Relative file paths
  janitor,        # Cleaning column names (e.g., clean_names())
  readxl,         # Load xlsx files
  writexl,
  PRISMA2020,
  
  # String Manipulation & Text Analysis
  stringi,
  stringr,        # Advanced string operations (regex)
  stringdist,     # Fuzzy string matching (useful for deduplication checks)
  tidytext,
  
  # Bibliographic Data Handling
  synthesisr,     # Standard tool for importing/exporting .ris/.bib files and deduplication
  
  # Google Drive/Sheets Integration (Phase B)
  googledrive,    # Interact with Google Drive files
  googlesheets4   # Read/Write Google Sheets
)

# 3. Project Configuration
# -------------------------------------------------------------------------
# Conflict resolution: Prefer dplyr::filter and dplyr::select
# This prevents errors if other packages mask these common functions.
conflicted::conflict_prefer("filter", "dplyr")
conflicted::conflict_prefer("select", "dplyr")

# 4. Directory Structure Check
# -------------------------------------------------------------------------
# Defines the required local folders and creates them if they are missing.
# This ensures all collaborators have the same folder structure.

required_dirs <- c(
  here("data"),
  here("data", "01_raw_searches"),
  here("data", "02_processed"),
  here("data", "03_for_extraction"),
  here("outputs"),
  here("dictionaries"),
  here("templates")
)

# Loop to create directories if they don't exist
walk(required_dirs, ~ {
  if (!dir.exists(.x)) {
    dir.create(.x, recursive = TRUE)
    message(paste("Created directory:", .x))
  }
})
