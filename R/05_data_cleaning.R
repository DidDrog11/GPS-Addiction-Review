# -------------------------------------------------------------------------
# Script: 05_data_cleaning.R
# Purpose: Clean extraction data, separate QA sheets, and apply dictionaries
# Author: David Simons
# Date: 2026-03-30
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. Load the Raw RDS Files
# -------------------------------------------------------------------------
raw_ext_1 <- readRDS(here("data", "03_for_extraction", "raw_extraction_1.rds"))
raw_ext_2 <- readRDS(here("data", "03_for_extraction", "raw_extraction_2.rds"))
raw_dicts <- readRDS(here("dictionaries", "raw_dictionaries.rds"))

# 2. Split and Combine the Sheets
# -------------------------------------------------------------------------
nr_strings <- c("NR", "nr", "N/A", "n/a", "NA", "Not reported", 
                "Not Reported", "none reported", "None Reported")

# Extract Main Data
df_main_1 <- raw_ext_1 |> 
  purrr::pluck("Data Extraction") |>
  drop_na(nr) |>
  clean_names() |>
  mutate(across(where(is.list), ~ map_chr(., \(x) {
    if (is.null(x) || length(x) == 0) return(NA_character_)
    paste(as.character(x), collapse = "; ")
  }))) |>
  mutate(across(where(is.character), ~ str_squish(.))) |>
  mutate(across(where(is.character), ~ na_if(., ""))) |>
  mutate(across(where(is.character), ~ if_else(. %in% nr_strings, NA_character_, .))) |>
  mutate(study_id = as.character(study_id))

df_main_2 <- raw_ext_2 |> 
  purrr::pluck("Data Extraction") |>
  drop_na(nr) |>
  clean_names() |>
  mutate(across(where(is.list), ~ map_chr(., \(x) {
    if (is.null(x) || length(x) == 0) return(NA_character_)
    paste(as.character(x), collapse = "; ")
  }))) |>
  mutate(across(where(is.character), ~ str_squish(.))) |>
  mutate(across(where(is.character), ~ na_if(., ""))) |>
  mutate(across(where(is.character), ~ if_else(. %in% nr_strings, NA_character_, .))) |>
  mutate(study_id = as.character(study_id))

df_main_combined <- bind_rows(df_main_1, df_main_2)

# 3. Extract Dictionaries
# -------------------------------------------------------------------------
dict_participant_cutoffs <- raw_dicts |> 
  purrr::pluck("gps_participant_level_cutoffs") |> 
  clean_names()
dict_features <- raw_dicts |> 
  purrr::pluck("GPS features") |> 
  clean_names()
dict_tradeoff <- raw_dicts |> 
  purrr::pluck("tradeoff_rationale") |> 
  clean_names()
dict_intervention <- raw_dicts |> 
  purrr::pluck("intervention_decision_rule") |> 
  clean_names()
dict_efficacy <- raw_dicts |> 
  purrr::pluck("intervention_efficacy") |> 
  clean_names()
dict_observation <- raw_dicts |> 
  purrr::pluck("observational_results") |> 
  clean_names()
dict_barriers <- raw_dicts |> 
  purrr::pluck("reported_barriers") |> 
  clean_names()


# 4. Apply Dictionary Matching
# -------------------------------------------------------------------------
df_main_matched <- df_main_combined |>
  # A. Participant Cut-offs
  left_join(dict_participant_cutoffs |> 
              select(data, category_cutoff_participant = code_participant_level, category_cutoff_day = code_day_or_episode_level) |> 
              distinct(data, .keep_all = TRUE),
            by = c("gps_participant_level_cut_offs" = "data")) |>
  # B. Trade-off Rationale
  left_join(dict_tradeoff |> 
              select(data, category_tradeoff = codes) |> 
              distinct(data, .keep_all = TRUE),
            by = c("tradeoff_rationale_cleaned" = "data")) |>
  # C. Intervention Decision Rule
  left_join(dict_intervention |> 
              select(data, category_intervention_rule = codes) |> 
              distinct(data, .keep_all = TRUE),
            by = c("intervention_decision_rule" = "data")) |>
  # D. Efficacy Results
  left_join(dict_efficacy |> 
              select(data, category_efficacy = codes) |> 
              distinct(data, .keep_all = TRUE),
            by = c("efficacy_results_cleaned" = "data")) |>
  # E. Observational Results
  left_join(dict_observation |> 
              select(data, category_observational = codes) |> 
              distinct(data, .keep_all = TRUE),
            by = c("observational_results_cleaned" = "data")) |>
  # F. Reported Barriers
  left_join(dict_barriers |> 
              select(data, category_barriers = codes) |> 
              distinct(data, .keep_all = TRUE),
            by = c("reported_barriers_cleaned" = "data"))

# GPS Features
df_features_matched <- df_main_matched |>
  select(study_id, gps_features_cleaned) |>
  separate_longer_delim(gps_features_cleaned, delim = regex(",\\s*")) |>
  left_join(dict_features |> 
              select(data, category_gps_feature = code) |>
              distinct(data, .keep_all = TRUE), 
            by = c("gps_features_cleaned" = "data")) |>
  group_by(study_id) |>
  summarise(category_gps_features_all = paste(unique(na.omit(category_gps_feature)), collapse = "; "),
            .groups = "drop")

# Attach the features back to the main dataset
df_main_raw <- df_main_matched |>
  left_join(df_features_matched, by = "study_id") |>
  mutate(category_gps_features_all = na_if(category_gps_features_all, ""))

# 5. Data Quality Cleaning
# -------------------------------------------------------------------------

prep_qa <- function(raw_list, tab_name, design_tag) {
  raw_list |> 
    purrr::pluck(tab_name) |> 
    # Drop empty rows where there is no study ID
    drop_na(study_id) |> 
    # Force everything to character so logical/character mismatches don't break bind_rows
    mutate(across(everything(), as.character)) |> 
    # Add our new tracking column
    mutate(qa_design_tool = design_tag)
}

df_qa_combined <- bind_rows(
  # Controlled Interventions
  prep_qa(raw_ext_1, "Quality Appraisal - Controlled Interventions", "Controlled Interventions"),
  prep_qa(raw_ext_2, "Quality Appraisal - Controlled Interventions", "Controlled Interventions"),
  # Pre-Post
  prep_qa(raw_ext_1, "Quality Appraisal - Pre-Post", "Pre-Post"),
  prep_qa(raw_ext_2, "Quality Appraisal - Pre-Post", "Pre-Post"),
  # Observational
  prep_qa(raw_ext_1, "Quality Appraisal - Observational", "Observational"),
  prep_qa(raw_ext_2, "Quality Appraisal - Observational", "Observational")) |> 
  clean_names() |>
  # Move study_id and the tool identifier to the front
  relocate(study_id, qa_design_tool, .before = everything())

# 6. Clean Main Data
# -------------------------------------------------------------------------
df_main_final <- df_main_raw |>
  mutate(# Clean Sample Size
    n_participants_analytical = str_remove_all(n_participants_analytical, ","),
    n_participants_analytical = str_extract(n_participants_analytical, "^\\d+"),
    n_participants_analytical = as.numeric(n_participants_analytical),
        # Clean Mean Age
    mean_age = case_when(str_detect(mean_age, "^\\d+\\s*-\\s*\\d+") ~ NA_character_, # Matches ranges like 14-16
                         str_detect(mean_age, "(?i)grade|twenties|younger") ~ NA_character_, # Matches text descriptions
                         TRUE ~ str_extract(mean_age, "\\d+\\.\\d+|\\d+") # Extracts first number or decimal
                         ),
    mean_age = as.numeric(mean_age),
        # Clean Percentage Female
    perc_female = case_when(str_detect(perc_female, "(?i)LBMI-A") ~ NA_character_,
                            TRUE ~ str_extract(perc_female, "\\d+\\.\\d+|\\d+")),
    perc_female = as.numeric(perc_female),
    perc_female = if_else(perc_female > 1, perc_female / 100, perc_female)) |>
  mutate(# Clean GPS
    gps_sampling_frequency_clean = case_when(str_detect(str_to_lower(gps_sampling_frequency_s), "continuous") ~ "Continuous",
                                             str_detect(str_to_lower(gps_sampling_frequency_s), "movement") ~ "Movement-triggered",
                                             str_detect(gps_sampling_frequency_s, "\\d+") ~ paste0(str_extract(gps_sampling_frequency_s, "\\d+"), " s"),
                                             TRUE ~ NA_character_),
    level_of_aggregation_space = case_when(str_detect(str_to_lower(level_of_aggregation_space), "none report|not report") ~ NA_character_,
                                           TRUE ~ level_of_aggregation_space),
    level_of_aggregation_time = case_when(str_detect(str_to_lower(level_of_aggregation_time), "none report|not report") ~ NA_character_,
                                          TRUE ~ level_of_aggregation_time),
    noise_filtering = if_else(noise_filtering == "Manual Cleaning, None Reported", 
                              "Manual Cleaning", 
                              noise_filtering)) |>
  mutate(# Bin Sampling Frequency
    temp_freq = as.numeric(str_extract(gps_sampling_frequency_clean, "\\d+")),
    gps_sampling_frequency_clean = case_when(gps_sampling_frequency_clean == "Continuous" ~ "Continuous",
                                             gps_sampling_frequency_clean == "Movement-triggered" ~ "Movement-triggered",
                                             temp_freq <= 60 ~ "\u2264 1 minute",          # <= 60s
                                             temp_freq > 60 & temp_freq <= 300 ~ "> 1 to 5 minutes", # 61s to 5 mins
                                             temp_freq > 300 ~ "> 5 minutes",              # > 5 mins
                                             TRUE ~ NA_character_),
    # Bin Temporal Aggregation
    level_of_aggregation_time_clean = case_when(str_detect(str_to_lower(level_of_aggregation_time), "dynamic|and") ~ "Multiple scales / Dynamic",
                                                str_detect(str_to_lower(level_of_aggregation_time), "week|72 hours") ~ "> 24 hours",
                                                str_detect(str_to_lower(level_of_aggregation_time), "24 hours") ~ "24 hours",
                                                str_detect(str_to_lower(level_of_aggregation_time), "hour") ~ "1 to < 24 hours",
                                                str_detect(str_to_lower(level_of_aggregation_time), "min") ~ "< 1 hour",
                                                TRUE ~ NA_character_),
    # Bin Bucket Spatial Aggregation
    level_of_aggregation_space_clean = case_when(str_detect(str_to_lower(level_of_aggregation_space), "and|,") ~ "Multiple scales",
                                                 str_detect(str_to_lower(level_of_aggregation_space), "mile|200m|1320") ~ "> 100m (e.g., neighbourhood)",
                                                 str_detect(str_to_lower(level_of_aggregation_space), "50|100") ~ "50m to 100m (e.g., standard buffer)",
                                                 str_detect(str_to_lower(level_of_aggregation_space), "20m|30m") ~ "< 50m (High precision)",
                                                 TRUE ~ NA_character_),
    # Clean Imputation Method
    imputation_method_clean = case_when(str_detect(imputation_method, "None") ~ "None (Complete Case)",
                                        str_detect(imputation_method, "Last|Linear|Multiple") ~ "Statistical / Algorithmic",
                                        imputation_method == "Other" ~ "Other",
                                        TRUE ~ NA_character_)) |>
  select(-temp_freq) |>
  # Order categories
  mutate(# Order GPS Device (Most common to least)
    gps_device = factor(gps_device, levels = c("Smartphone (own device)", "Smartphone (study provided)", "Dedicated GPS logger", "Other")),
    # Order Sampling Frequency (High frequency to low)
    gps_sampling_frequency_clean = factor(gps_sampling_frequency_clean, levels = c("Continuous", "Movement-triggered", "\u2264 1 minute", "> 1 to 5 minutes", "> 5 minutes")),
    # Order Temporal Aggregation (Short to long)
    level_of_aggregation_time_clean = factor(level_of_aggregation_time_clean, levels = c("< 1 hour", "1 to < 24 hours", "24 hours", "> 24 hours", "Multiple scales / Dynamic")),
    # Order Spatial Aggregation (Precise to broad)
    level_of_aggregation_space_clean = factor(level_of_aggregation_space_clean, levels = c("< 50m (High precision)", "50m to 100m (e.g., standard buffer)", "> 100m (e.g., neighbourhood)", "Multiple scales")),
    # Order Imputation Method
    imputation_method_clean = factor(imputation_method_clean, levels = c("None (Complete Case)", "Statistical / Algorithmic", "Other")),
    # Order Open Science Practices (Best practice to least)
    open_data_code = factor(open_data_code, levels = c("Yes - Code and Data Available", "Yes - Data Available Only", "Yes - Code Available Only", "No")))

# Set to the 19 used in qualitative component
df_main_final$n_participants_analytical[df_main_final$study_id == 74] <- 19

# 7. Save Cleaned Data for Analysis
# -------------------------------------------------------------------------
# Create an output directory for analysis-ready data if it doesn't exist
dir.create(here("data", "04_analytic_datasets"), showWarnings = FALSE)

saveRDS(df_main_final, here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))
saveRDS(df_qa_combined, here("data", "04_analytic_datasets", "cleaned_qa_combined.rds"))
