# -------------------------------------------------------------------------
# Script: 00_import_and_deduplicate.R
# Purpose: Import raw searches, standardize columns, and deduplicate
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. List all files
search_files <- list.files(here("data", "01_raw_searches", "2025-12-30"), 
                           pattern = "\\.(ris|bib|txt|ciw|cgi|enw|xls)$", 
                           full.names = TRUE)

# 2. Helper function to read and tag source
read_and_label <- function(files, source_label) {
  if (length(files) == 0) {
    warning(paste("No files found for:", source_label))
    return(NULL)
  }
  
  # Read all files in the list and combine them
  imported <- read_refs(files) |>
    mutate(database_source = source_label)
  
  return(imported)
}

# 3. Import by identifying text in the filename
# -------------------------------------------------------------------------

# Find files containing specific strings (case-insensitive)
files_medline  <- str_subset(search_files, "(?i)medline")
files_psycinfo <- str_subset(search_files, "(?i)psycinfo")
files_ieee     <- str_subset(search_files, "(?i)ieee")
files_wos      <- str_subset(search_files, "(?i)wos|web")

# 4. Read and Bind
# -------------------------------------------------------------------------
df_psycinfo <- read_and_label(files_psycinfo, "PsycINFO")
df_ieee <- read_and_label(files_ieee, "IEEE")
df_medline <- read_and_label(files_medline, "MEDLINE")
df_wos <- read_and_label(files_wos, "WoS")

df_all <- bind_rows(df_psycinfo, df_ieee, df_medline, df_wos)

message(paste("Total Imported:", nrow(df_all)))

# 5. Deduplicate
# -------------------------------------------------------------------------
df_cleaned <- df_all |>
  mutate(year = coalesce(year, Y1, PY),
    year = str_extract(year, "\\d{4}"),
    year = as.numeric(year),
    title_clean = str_to_lower(title) |> str_remove_all("[[:punct:]]")) |>
  filter(!is.na(title) | !is.na(year)) |>
  select(database_source, # Keep track of where it came from
         title, 
         title_clean,     # Needed for the deduplication step
         year, 
         author, 
         abstract, 
         journal, 
         doi, 
         url, 
         keywords) |>
  mutate(dedup_id = paste0(title_clean, "_", year))

# A. Exact Match
dups_exact <- find_duplicates(df_cleaned$dedup_id,
                              method = "exact")

df_step1 <- extract_unique_references(df_cleaned, dups_exact)

# B. Fuzzy Match (Title allows for small typos, Year must match)
# threshold = 5 means ~5 characters difference allowed
dups_fuzzy <- find_duplicates(df_step1$title_clean, 
                              method = "string_osa", 
                              threshold = 5,
                              group_by = as.character(df_step1$year))

df_final <- extract_unique_references(df_step1, dups_fuzzy)

# 5. Save Final Output
cols_for_export <- c("database_source", "title", "abstract", "year", 
                     "author", "journal", "doi", "url", "keywords")

excel_limit <- 32000

df_export <- df_final |>
  select(any_of(cols_for_export)) |>
  mutate(author = str_trunc(author, width = excel_limit, side = "right", ellipsis = "... [TRUNCATED]"),
         abstract = str_trunc(abstract, width = excel_limit, side = "right", ellipsis = "... [TRUNCATED]"),
         keywords = str_trunc(keywords, width = excel_limit, side = "right", ellipsis = "..."),
         url = str_trunc(url, width = excel_limit, side = "right", ellipsis = "..."))

writexl::write_xlsx(df_export, here("data", "01_raw_searches", "articles_2025-12-30.xlsx"))
