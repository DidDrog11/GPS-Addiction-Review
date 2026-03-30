# -------------------------------------------------------------------------
# Script: 07_descriptives_gps.R
# Purpose: Generate summary statistics for GPS methodology and results
# Author: David Simons
# Date: 2026-03-30
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

if (!require("gtsummary")) install.packages("gtsummary")
library(gtsummary)

# 1. Load Analytic Datasets
# -------------------------------------------------------------------------
df_main <- readRDS(here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))
df_qa   <- readRDS(here("data", "04_analytic_datasets", "cleaned_qa_combined.rds"))

n_studies <- nrow(df_main)

# 2. GPS Methodology Summary (Single-Choice Variables)
# -------------------------------------------------------------------------
table_gps_methodology <- df_main |>
  select(
    gps_device,
    gps_sampling_frequency_clean,
    imputation_method_clean,          
    level_of_aggregation_time_clean,  
    level_of_aggregation_space_clean,
    acceptability,
    open_data_code,
    maup_ugcop,
    sensitivity_maup
  ) |>
  tbl_summary(
    statistic = list(all_categorical() ~ "{n} ({p}%)"),
    missing_text = "Not Reported",
    label = list(
      gps_device ~ "GPS Device Type",
      gps_sampling_frequency_clean ~ "Sampling Frequency (Seconds)",
      imputation_method_clean ~ "Imputation Method",
      level_of_aggregation_time_clean ~ "Temporal Aggregation",
      level_of_aggregation_space_clean ~ "Spatial Aggregation",
      acceptability ~ "Acceptability Reported",
      open_data_code ~ "Open Data / Code Available",
      maup_ugcop ~ "MAUP/UGCoP Considered",
      sensitivity_maup ~ "Sensitivity Analysis for MAUP"
    )
  ) |>
  modify_header(label = "**Methodological Variable**") |>
  bold_labels()

# Export the main methodology table
dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)

table_gps_methodology |>
  as_flex_table() |>
  flextable::save_as_docx(path = here("outputs", "tables", "Table2_GPS_Methodology.docx"))

# 4. Multi-Select Frequencies (Dictionaries)
# -------------------------------------------------------------------------
# Helper function to unnest semicolon-separated columns and calculate % of total studies
calculate_multi_frequencies <- function(data, column_name, total_n) {
  data |>
    select(study_id, {{ column_name }}) |>
    drop_na({{ column_name }}) |>
    separate_longer_delim({{ column_name }}, delim = regex(";\\s*")) |>
    # Merge "craving" and "cravings"
    mutate({{ column_name }} := str_replace(str_to_lower({{ column_name }}), "^craving$", "cravings")) |>
    count({{ column_name }}, name = "Frequency") |>
    mutate(
      Percentage = (Frequency / total_n) * 100,
      `Formatted Result` = sprintf("%d (%.1f%%)", Frequency, Percentage),
      Category = str_replace_all({{ column_name }}, "_", " "),
      Category = str_to_title(Category),
      Category = str_replace_all(Category, "Gps", "GPS"),
      Category = str_replace_all(Category, "Ema", "EMA")
    ) |>
    select(Category, Frequency, Percentage, `Formatted Result`) |>
    arrange(desc(Frequency))
}

calculate_multi_comma <- function(data, column_name, total_n) {
  data |>
    select(study_id, {{ column_name }}) |>
    drop_na({{ column_name }}) |>
    separate_longer_delim({{ column_name }}, delim = regex(",\\s*")) |>
    count({{ column_name }}, name = "Frequency") |>
    mutate(
      Percentage = (Frequency / total_n) * 100,
      `Formatted Result` = sprintf("%d (%.1f%%)", Frequency, Percentage),
      Category = {{ column_name }} 
    ) |>
    select(Category, Frequency, Percentage, `Formatted Result`) |>
    arrange(desc(Frequency))
}

freq_features      <- calculate_multi_frequencies(df_main, category_gps_features_all, n_studies)
freq_cutoffs       <- calculate_multi_frequencies(df_main, category_cutoff_participant, n_studies)
freq_tradeoffs     <- calculate_multi_frequencies(df_main, category_tradeoff, n_studies)
freq_barriers      <- calculate_multi_frequencies(df_main, category_barriers, n_studies)
freq_decision_rule <- calculate_multi_frequencies(df_main, category_intervention_rule, n_studies)
freq_efficacy      <- calculate_multi_frequencies(df_main, category_efficacy, n_studies)
freq_observational <- calculate_multi_frequencies(df_main, category_observational, n_studies)

freq_ground_truth  <- calculate_multi_comma(df_main, ground_truth_tier, n_studies)
freq_noise_filter  <- calculate_multi_comma(df_main, noise_filtering, n_studies)

# Bundle them into a list of tabs and export to Excel
list_of_freqs <- list(
  "GPS Features"        = freq_features,
  "Ground Truth"        = freq_ground_truth,
  "Noise Filtering"     = freq_noise_filter,
  "Participant Cutoffs" = freq_cutoffs,
  "Tradeoffs"           = freq_tradeoffs,
  "Barriers"            = freq_barriers,
  "Decision Rules"      = freq_decision_rule,
  "Efficacy"            = freq_efficacy,
  "Observational"       = freq_observational
)

writexl::write_xlsx(list_of_freqs, here("outputs", "tables", "Table3_GPS_Categorical_Frequencies.xlsx"))

# 5. Quality Appraisal Summary
# -------------------------------------------------------------------------
df_qa_summary <- df_qa |>
  select(qa_design_tool, starts_with("quality_")) |>
  select(-ends_with("_other")) |>
  pivot_longer(cols = starts_with("quality_"),
               names_to = "question",
               values_to = "response") |>
  drop_na(response) |>
  mutate(q_num = as.numeric(str_extract(question, "\\d+"))) |>
  count(qa_design_tool, q_num, response) |>
  group_by(qa_design_tool, q_num) |>
  mutate(percentage = (n / sum(n)) * 100,
         formatted_res = sprintf("%d (%.1f%%)", n, percentage)) |>
  ungroup() |>
  select(qa_design_tool, q_num, response, formatted_res) |>
  pivot_wider(names_from = response,
              values_from = formatted_res,
              values_fill = "0 (0.0%)") |>
  arrange(qa_design_tool, q_num) |>
  mutate(Question = paste("Question", q_num)) |>
  select(`Study Design` = qa_design_tool, Question, Yes, No, Other)

writexl::write_xlsx(list("QA Summary" = df_qa_summary), 
                    here("outputs", "tables", "Table4_Quality_Appraisal_Frequencies.xlsx"))

