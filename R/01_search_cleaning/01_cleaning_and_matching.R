# -------------------------------------------------------------------------
# Script: 01_cleaning_and_matching.R
# Purpose: Clean messy Rayyan export and apply string matching
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))
 
# 1. Load the data
# -------------------------------------------------------------------------
raw_path <- here("data", "01_raw_searches", "articles_2025-12-30.xlsx")
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
  mutate(notes_spillover = "", 
         across(c(title, abstract), \(x) {
           x |> 
             as.character() |>
             replace_na("") |>
             str_replace_all(mojibake_fixes) |>
             stringi::stri_trans_general("latin-ascii") |>
             str_squish() })) |>
  mutate(title = ifelse(str_detect(title, "^[A-Z\\W0-9]+$") & nchar(title) > 4,
                        str_to_sentence(title),
                        title))

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
# 
hard_exclude_pattern <- paste(c(noise_biology, noise_engineering, noise_acronyms), collapse = "|")
soft_exclude_pattern <- paste(noise_irrelevant_health, collapse = "|")

df_final <- df_processed |>
  mutate(text_for_exclusion = tolower(paste(title, keywords, sep = " ")),
         text_for_inclusion = tolower(paste(title, abstract, keywords, notes_spillover, sep = " ")),
         # 1. Flag presence of terms
         has_hard_kill = str_detect(text_for_exclusion, hard_exclude_pattern),
         has_soft_kill = str_detect(text_for_exclusion, soft_exclude_pattern),
         has_addict    = str_detect(text_for_inclusion, priority_pattern_addict),
         has_tech      = str_detect(text_for_inclusion, priority_pattern_tech),
         # 2. Determine Priority
         is_high_priority = has_addict & has_tech,
         # 3. Determine Exclusion
    exclude_flag = case_when(has_hard_kill    ~ TRUE,  # Rule 1: If it's a Rat/Drone, delete it
                             is_high_priority ~ FALSE, # Rule 2: If it's High Priority, KEEP IT (Rescues Cancer/Cardio papers)
                             has_soft_kill    ~ TRUE,  # Rule 3: If it's not High Priority but mentions Cancer, delete it.
                             TRUE             ~ FALSE  # Rule 4: Keep everything else (Low Priority/Unsure).
                             ),
    screening_notes = case_when(has_hard_kill ~ "Excluded: Biology/Engineering",
                                has_soft_kill & is_high_priority ~ "High Priority (Rescued from Health Exclusion)",
                                has_soft_kill ~ "Excluded: Irrelevant Health Topic",
                                is_high_priority ~ "High Priority: Matches Addiction + Tech",
                                TRUE ~ "Review Required (Low Priority)")) |>
  arrange(desc(is_high_priority))

# 5. DELTA MATCHING: Remove papers already screened
old_path <- here("data", "02_processed", "previously_screened_2025-11-28.xlsx")

if(file.exists(old_path)) {
  df_old <- read_excel(old_path, guess_max = 5000) |>
    mutate(match_id = str_to_lower(title) |> str_remove_all("[[:punct:]]")) |>
    drop_na(rating) |>
    select(match_id, title, year, authors, doi)
  df_final_tagged <- df_final |>
    mutate(match_id = str_to_lower(title) |> str_remove_all("[[:punct:]]"))
  df_delta <- df_final_tagged |>
    anti_join(df_old, by = "match_id")
  duplicates_count <- nrow(df_final) - nrow(df_delta)
  message(paste("Removed", duplicates_count, "papers that were already in the Nov 28 set."))
} else {
  warning("Old screening file not found! Proceeding with full dataset.")
  df_delta <- df_final
}

# 6. Assign IDs & Save
# -------------------------------------------------------------------------
df_export_ready <- df_delta |>
  mutate(study_id = paste0("GPS_DEC_", str_pad(row_number(), 4, pad = "0"))) |>
  relocate(study_id, .before = everything()) |>
  mutate(across(where(is.character), \(x) str_trunc(x, 32000)))

# A. Save the papers to Screen (High Priority at top)
df_screen <- df_export_ready |>
  filter(!exclude_flag) |>
  arrange(desc(is_high_priority)) |>
  select(-text_for_exclusion, -text_for_inclusion, -match_id)

write_xlsx(df_screen, here("data", "02_processed", "citations_to_screen_2025-12-30.xlsx"))

# B. Save the Excluded (for PRISMA)
df_excluded <- df_export_ready |> 
  filter(exclude_flag) |>
  select(-text_for_exclusion, -text_for_inclusion, -match_id)

write_xlsx(df_excluded, here("data", "02_processed", "excluded_by_string_matching_2025-12-30.xlsx"))

# C. Randomly select 10% of Excluded for manual checking of exclusion criteria
set.seed(42); excluded_by_string_matching_2025_12_30 |> 
  slice_sample(n = subset) |> 
  arrange(study_id) |>
  pull(study_id) -> to_check

excluded_by_string_matching_2025_12_30 |> 
  filter(study_id %in% to_check) |> 
  write_csv(here("data", "02_processed", "manual_check_of_exclude.csv"))