# -------------------------------------------------------------------------
# Script: 01_cleaning_and_matching.R
# Purpose: Clean messy Rayyan export and apply string matching
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. Load the data
# -------------------------------------------------------------------------
raw_path <- here("data", "01_raw_searches", "articles_2025-11-28.xlsx")
df_raw <- read_excel(raw_path, .name_repair = "unique")

message(paste("Loaded", nrow(df_raw), "rows with", ncol(df_raw), "columns."))

# 2. Fix the Spillover Columns
# -------------------------------------------------------------------------

# Patterns on the left, fixes on the right.
mojibake_fixes <- c(
  # Standard Windows-1252 -> UTF-8 artifacts
  "â€œ"      = '"',   "â€\u009d" = '"',   "â€"       = '"',
  "â€™"      = "'",   "â€˜"      = "'",   "â€\u0090" = "-",
  "â€“"      = "-",   "â€”"      = "-",   "Â"        = " ",
  
  # Aggressive fixes for specific artifacts in your dataset
  "\u0090"   = "-",   "™"        = "'",   "“"        = '"',
  "”"        = '"',   "‘"        = "'",   "’"        = "'",
  '"-'       = "-",   "&amp;"    = " and ", "&lt;"     = "<", "&gt;" = ">")

# Identify all columns that start with "..."
spillover_cols <- df_raw |> 
  select(matches("^\\.\\.\\.")) |> 
  names()

# Unite all messy columns into one "notes_spillover" column
df_processed <- df_raw |>
  unite(col = "notes_spillover", 
        all_of(spillover_cols), 
        sep = " ", 
        na.rm = TRUE, 
        remove = TRUE) |>
  mutate(across(c(title, abstract, notes_spillover), \(x) {
    x |> 
      as.character() |>              # Ensure input is character
      replace_na("") |>              # Handle NAs before regex
      str_replace_all(mojibake_fixes) |> # Apply dictionary fixes
      stringi::stri_trans_general("latin-ascii") |> # Transliterate remaining non-ASCII
      str_squish()                   # Collapse excessive whitespace
  })) |>
  mutate(title = ifelse(str_detect(title, "^[A-Z\\W0-9]+$") & nchar(title) > 4,
                        str_to_sentence(title),
                        title)) |>
  # Create study id
  mutate(study_id = paste0("GPS_", str_pad(row_number(), 4, pad = "0")),
         search_text = tolower(paste(title, abstract, keywords, notes_spillover, sep = " "))) |>
  relocate(study_id, .before = everything())

# Exclusion list
noise_biology <- c(
  "polymorphism", "genotyp", "enzyme", "protein", "molecular", 
  "cellular", "immune", "inflammatory", "in vitro", "oxidoreductase", 
  "lipid", "metabolism", "epigenetic", "chromosome", "squamous cell", 
  "carcinoma", "retinal", "pharmacological", "bioactive",
  "gentiopicroside", "iridoid glycoside", "g-protein", "modulator",
  "cadmium", "lead exposure", "heavy metal", "pesticide", "pollutant",
  "bacterial", "microbial", "gut microbiota", "neoplasm", "genetics", 
  "vaccin", "synthesis",
  
  # SHORT WORDS WITH BOUNDARIES (The "Safe" List)
  "\\brat\\b", "\\brats\\b",   # Fixes 'Strategies', 'Rational', 'Rate'
  "\\bmice\\b", "\\bmouse\\b", 
  "\\bfish\\b",                # Fixes 'Selfish', 'Efficient'
  "\\brna\\b",                 # Fixes 'Journal', 'International'
  "\\blung\\b",                # Fixes 'Plunge'
  "\\bsoil\\b"                 # Fixes 'Topsoil'
)

noise_engineering <- c(
  "routing protocol", "ad hoc network", "multipath", "lidar", 
  "odometry", "antenna", "robot", "uav", "drone", 
  "blockchain", "energy harvesting", "e-waste", "power data centers",
  "vehicle tracking", "engine immobilization", "smart helmet",
  "internet of things", 
  "firefighting", "forest fire", "fire detection",
  "fabrication", "polymer", "fiber",
  
  # SHORT WORDS WITH BOUNDARIES
  "\\biot\\b"                  # Fixes 'Antibiotic', 'Biotech'
)

noise_irrelevant_health <- c(
  "parkinson", "copd", "asthma", "cancer", "tumor", "malignan", 
  "surgery", "surgical", "fracture", "diabetes", "insulin", 
  "hidradenitis", "dermatology", "gestational", "sexual debut",
  "atrial fibrillation", "cardiovascular", "glaucoma")

noise_acronyms <- c(
  "global prevalence study", 
  "gambling passion scale")

exclude_pattern <- paste(c(noise_biology, noise_engineering, noise_irrelevant_health, noise_acronyms), collapse = "|")

# Priority list
required_addiction <- c(
  "addict", "alcohol", "tobacco", "smok", "gambl", "substance", "craving", 
  "nicotine", "drink", "betting", "drug", "opioid", "cannabis", "marijuana", 
  "vaping", "e-cigarette", "sobriety", "abstinence")

required_tech_geo <- c(
  "gps", "global positioning", "location", "geograph", "spatial", "spatiotemporal", 
  "tracking", "sensing", "mobility", "smartphone", "mobile phone", "wearable", 
  "geofenc", "jitai", "momentary", "ema", "ecological")

priority_pattern_addict <- paste(required_addiction, collapse = "|")
priority_pattern_tech   <- paste(required_tech_geo, collapse = "|")

# Apply Filter & Prioritisation
df_final <- df_processed |>
  mutate(text_for_exclusion = tolower(paste(title, keywords, sep = " ")), # Limited to checking titles and keywords only
         text_for_inclusion = tolower(paste(title, abstract, keywords, notes_spillover, sep = " ")),
         exclude_flag = str_detect(text_for_exclusion, exclude_pattern),
         has_addict = str_detect(text_for_inclusion, priority_pattern_addict),
         has_tech   = str_detect(text_for_inclusion, priority_pattern_tech),
         is_high_priority = has_addict & has_tech,
         screening_notes = case_when(is_high_priority ~ "High Priority: Matches Addiction + Tech",
                                     !has_addict      ~ "Low Priority: No Addiction Term Found",
                                     !has_tech        ~ "Low Priority: No Tech Term Found",
                                     TRUE             ~ "Review Required")) |> # Screening notes for Rayyan
  # Sort: High priority first
  arrange(desc(is_high_priority))

write_xlsx(df_final |>
             filter(!exclude_flag) |>
             select(-text_for_exclusion, -text_for_inclusion, -search_text, -notes_spillover) |>
             mutate(across(where(is.character), \(x) str_trunc(x, 32000))), 
           here("data", "02_processed", "citations_for_rayyan_2025-11-28.xlsx"))

# The Excluded Record (For PRISMA)
# Filter: KEEP rows where exclude_flag is TRUE
df_excluded <- df_final |> 
  filter(exclude_flag)

write_xlsx(df_excluded |>
             select(-text_for_exclusion, -text_for_inclusion, -search_text, -notes_spillover) |>
             mutate(across(where(is.character), \(x) str_trunc(x, 32000))), 
           here("data", "02_processed", "excluded_by_string_matching_2025-11-28.xlsx"))

message("--- EXPORT COMPLETE ---")
message(paste("Sent to Rayyan:", nrow(df_final) - nrow(df_excluded)))
message(paste("Excluded (PRISMA):", nrow(df_excluded)))

           