# -------------------------------------------------------------------------
# Script: 04_flow_chart.R
# Purpose: Generate PRISMA 2020 Flow Diagram from screening and extraction data
# Author: David Simons
# Date: 2026-03-30
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. Load the Data
# -------------------------------------------------------------------------
# A. Master deduplicated list 
df_deduped <- read_excel(here("data", "01_raw_searches", "articles_2025-12-30.xlsx"))

# B. Automated Exclusions
df_auto_excluded <- read_excel(here("data", "02_processed", "excluded_by_string_matching_2025-12-30.xlsx"))

# C. Human Screening (Title/Abstract)
df_screened <- read_excel(here("data", "02_processed", "screened_citations_2025-12-30_OP_DS.xlsx"), guess_max = 5000)

# D. Full Text Screening 
url_full_text_screening <- "https://docs.google.com/spreadsheets/d/1k1JifoWc7inDVYLh558CKdO5aZApSBlSL2VDiAnYf8Q/edit?gid=0#gid=0"
df_fulltext_raw <- read_sheet(url_full_text_screening)

# E. Final Included Studies (Analytic dataset)
# Depends on script 05_data_cleaning.R
df_final <- readRDS(here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))

# 2. Calculate PRISMA Counts
# -------------------------------------------------------------------------

# --- Phase 1: Identification ---
total_raw_imported <- 8692
n_deduped <- nrow(df_deduped)
n_duplicates_removed <- total_raw_imported - n_deduped

# --- Phase 2: Pre-Screening Exclusions (Automation) ---
n_auto_excluded <- nrow(df_auto_excluded)

# --- Phase 3: Title/Abstract Screening ---
n_records_screened <- n_deduped - n_auto_excluded

n_human_excluded <- df_screened |> 
  filter((OP_rating == "no" | is.na(OP_rating)) & (DS_rating == "no" | is.na(DS_rating)) & !(is.na(OP_rating) & is.na(DS_rating))) |> 
  nrow()

# --- Phase 4: Full Text Screening ---
# Records sought for retrieval
n_fulltext_assessed <- df_fulltext_raw |> 
  nrow()

n_not_retrieved <- 0 
n_other_sources <- nrow(df_fulltext_raw) - (nrow(df_screened) - n_human_excluded)
n_fulltext_screened <- n_fulltext_assessed - n_not_retrieved

n_final_included <- nrow(df_final)
n_fulltext_excluded <- n_fulltext_screened - n_final_included

# 3. Process Full-Text Exclusion Reasons
# -------------------------------------------------------------------------
# Extract the specific reasons for the PRISMA box
df_reasons <- df_fulltext_raw |>
  filter(screening_decision_OP == "EXCLUDE") |>
  mutate(exclusion_label = case_when(
    str_detect(exclusion_reason, "No Individual-Level GPS Analysis") ~ "No individual-level GPS analysis",
    str_detect(exclusion_reason, "Not Empirical") ~ "Not empirical",
    str_detect(exclusion_reason, "GPS Data Not Linked") ~ "GPS not linked to addictive behaviour",
    str_detect(exclusion_reason, "Not an Addictive Behaviour") ~ "Not an addictive behaviour",
    TRUE ~ "Other reason"
  )) |>
  count(exclusion_label)

reasons_string <- paste(df_reasons$exclusion_label, df_reasons$n, sep = ", ", collapse = "; ")

# 4. Generate PRISMA Data Object
# -------------------------------------------------------------------------
csv_file <- system.file("extdata", "PRISMA.csv", package = "PRISMA2020")
prisma_template <- read.csv(csv_file)

counts_lookup <- c(
  "database_results"           = as.character(total_raw_imported),
  "register_results"           = NA_character_, 
  "citations_results"          = as.character(n_other_sources),
  "duplicates"                 = as.character(n_duplicates_removed),
  "excluded_automatic"         = as.character(n_auto_excluded),
  "records_screened"           = as.character(n_records_screened),
  "records_excluded"           = as.character(n_human_excluded),
  "dbr_sought_reports"         = as.character(n_fulltext_assessed - n_other_sources),
  "dbr_notretrieved_reports"   = as.character(n_not_retrieved),
  "dbr_assessed"               = as.character(n_fulltext_screened - n_other_sources),
  "dbr_excluded"               = reasons_string,
  "other_sought_reports"       = as.character(n_other_sources),
  "other_notretrieved_reports" = "0",
  "other_assessed"             = as.character(n_other_sources),
  "other_excluded"             = NA_character_, 
  "new_studies"                = as.character(n_final_included),
  "new_reports"                = NA_character_
)

prisma_df <- prisma_template |>
  mutate(n = ifelse(data %in% names(counts_lookup), counts_lookup[data], n))

prisma_data <- PRISMA_data(prisma_df)

# 5. Plot and Save the Flow Diagram
# -------------------------------------------------------------------------
# Generate the interactive/HTML plot
prisma_plot <- PRISMA_flowdiagram(
  prisma_data,
  previous = FALSE,
  other = TRUE,
  interactive = FALSE,
  fontsize = 12,
  font = "Helvetica"
)

# Display in viewer
prisma_plot

# Save to outputs
dir.create(here("outputs", "figures"), showWarnings = FALSE, recursive = TRUE)
PRISMA_save(prisma_plot, filename = here("outputs", "figures", "PRISMA_flowchart_2026.pdf"))
PRISMA_save(prisma_plot, filename = here("outputs", "figures", "PRISMA_flowchart_2026.png"))