# -------------------------------------------------------------------------
# Script: 07_descriptives_gps.R
# Purpose: Generate summary statistics for GPS methodology and results
# Author: David Simons & Olga Perski
# Date: 2026-04-01
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

if (!require("gtsummary")) install.packages("gtsummary")
library(gtsummary)
if (!require("flextable")) install.packages("flextable")
library(flextable)

# 1. Load Analytic Datasets
# -------------------------------------------------------------------------
df_main <- readRDS(here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))
df_qa   <- readRDS(here("data", "04_analytic_datasets", "cleaned_qa_combined.rds"))

n_studies <- nrow(df_main)

# 2. Data Preparation for Stratification
# -------------------------------------------------------------------------
df_gps <- df_main |>
  mutate(addictive_behaviour_clean = case_when(str_detect(addictive_behaviour, ",") | str_detect(addictive_behaviour, "(?i)Polysubstance") ~ "Polysubstance/Multiple",
                                               addictive_behaviour %in% c("Tobacco/Nicotine", "Alcohol", "Cannabis", "Opioids", "Gambling") ~ addictive_behaviour,
                                               TRUE ~ "Other"),
    design_strat = case_when(str_detect(study_design, "Observational") ~ "Observational",
                             str_detect(study_design, "Experimental") ~ "Experimental",
                             str_detect(study_design, "Qualitative|Mixed Methods") ~ "Qualitative / Mixed",
                             TRUE ~ "Other"),
    behaviour_strat = case_when(addictive_behaviour_clean %in% c("Alcohol", "Tobacco/Nicotine") ~ addictive_behaviour_clean,
                                TRUE ~ "Other (Cannabis, Opioids, Polysubstance)"))

# 3. GPS Methodology Summary (Stratified)
# -------------------------------------------------------------------------
shared_gps_labels <- list(
  gps_device ~ "GPS Device Type",
  gps_sampling_frequency_clean ~ "Sampling Frequency",
  imputation_method_clean ~ "Imputation Method",
  level_of_aggregation_time_clean ~ "Temporal Aggregation",
  level_of_aggregation_space_clean ~ "Spatial Aggregation",
  acceptability ~ "Acceptability Reported",
  open_data_code ~ "Open Data / Code Available",
  maup_ugcop ~ "MAUP/UGCoP Considered",
  sensitivity_maup ~ "Sensitivity Analysis for MAUP"
)

# Table 2A: By Study Design
table_gps_design <- df_gps |>
  select(design_strat,
         gps_device, gps_sampling_frequency_clean, imputation_method_clean,
         level_of_aggregation_time_clean, level_of_aggregation_space_clean,
         acceptability, open_data_code, maup_ugcop, sensitivity_maup) |>
  tbl_summary(by = design_strat,
              statistic = list(all_categorical() ~ "{n} ({p}%)"),
              missing = "ifany", 
              missing_text = "Not Reported",
              label = shared_gps_labels ) |>
  add_overall() |>
  modify_header(all_stat_cols() ~ "**{level}**\n(N = {n})")

# Table 2B: By Addictive Behaviour
table_gps_behaviour <- df_gps |>
  select(behaviour_strat,
         gps_device, gps_sampling_frequency_clean, imputation_method_clean,
         level_of_aggregation_time_clean, level_of_aggregation_space_clean,
         acceptability, open_data_code, maup_ugcop, sensitivity_maup) |>
  tbl_summary(by = behaviour_strat,
              statistic = list(all_categorical() ~ "{n} ({p}%)"),
              missing = "ifany", 
              missing_text = "Not Reported",
              label = shared_gps_labels) |>
  modify_header(all_stat_cols() ~ "**{level}**\n(N = {n})")

table_gps_methodology <- tbl_merge(
  tbls = list(table_gps_design, table_gps_behaviour),
  tab_spanner = c("**By Study Design**", "**By Addictive Behaviour**")) |>
  bold_labels() |>
  modify_table_body(~ .x |> mutate(across(where(is.character), ~ str_replace_all(., "0 \\(NA%\\)", "0 (0%)"))))

dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)

table_gps_methodology |>
  as_flex_table() |>
  flextable::fontsize(size = 9, part = "all") |>
  flextable::autofit() |>
  flextable::save_as_docx(path = here("outputs", "tables", "Table2_GPS_Methodology.docx"))

# 4. Multi-Select Frequencies (Methodology Dictionaries)
# -------------------------------------------------------------------------
calculate_multi_frequencies <- function(data, column_name, total_n) {
  data |>
    select(study_id, {{ column_name }}) |>
    drop_na({{ column_name }}) |>
    separate_longer_delim({{ column_name }}, delim = regex(";\\s*")) |>
    count({{ column_name }}, name = "Frequency") |>
    mutate(Percentage = (Frequency / total_n) * 100,
           `Formatted Result` = sprintf("%d (%.1f%%)", Frequency, Percentage),
           Category = str_replace_all({{ column_name }}, "_", " "),
           Category = str_to_title(Category),
           Category = str_replace_all(Category, "Gps", "GPS"),
           Category = str_replace_all(Category, "Ema", "EMA"),
           Category = str_replace_all(Category, "Gema", "GEMA")) |>
    select(Category, Frequency, Percentage, `Formatted Result`) |>
    arrange(desc(Frequency))
  }

calculate_multi_comma <- function(data, column_name, total_n) {
  data |>
    select(study_id, {{ column_name }}) |>
    drop_na({{ column_name }}) |>
    separate_longer_delim({{ column_name }}, delim = regex(",\\s*")) |>
    count({{ column_name }}, name = "Frequency") |>
    mutate(Percentage = (Frequency / total_n) * 100,
           `Formatted Result` = sprintf("%d (%.1f%%)", Frequency, Percentage),
           Category = {{ column_name }}) |>
    select(Category, Frequency, Percentage, `Formatted Result`) |>
    arrange(desc(Frequency))
}

calculate_stratified_multi <- function(data, column_name, group_var, delim_regex = ";\\s*") {
  group_totals <- data |> count({{ group_var }}, name = "group_total")
  
  data |>
    select(study_id, {{ group_var }}, {{ column_name }}) |>
    drop_na({{ column_name }}) |>
    separate_longer_delim({{ column_name }}, delim = regex(delim_regex)) |>
    mutate(Category = str_replace_all({{ column_name }}, "_", " "),
           Category = str_to_title(Category),
           Category = str_replace_all(Category, "Gps", "GPS"),
           Category = str_replace_all(Category, "Ema", "EMA")) |>
    count({{ group_var }}, Category, name = "Frequency") |>
    left_join(group_totals, by = join_by({{ group_var }})) |>
    mutate(Percentage = (Frequency / group_total) * 100,
           Formatted = sprintf("%d (%.1f%%)", Frequency, Percentage)) |>
    select({{ group_var }}, Category, Formatted) |>
    pivot_wider(names_from = {{ group_var }}, values_from = Formatted, values_fill = "0 (0.0%)")
}

freq_cutoffs   <- calculate_multi_frequencies(df_gps, category_cutoff_participant, n_studies)
freq_tradeoffs <- calculate_multi_frequencies(df_gps, category_tradeoff, n_studies)
freq_barriers  <- calculate_multi_frequencies(df_gps, category_barriers, n_studies)
freq_ground_truth <- calculate_multi_comma(df_gps, ground_truth_tier, n_studies)
freq_noise_filter <- calculate_multi_comma(df_gps, noise_filtering, n_studies)

cutoffs_by_design <- calculate_stratified_multi(df_gps, category_cutoff_participant, design_strat)
cutoffs_by_behav  <- calculate_stratified_multi(df_gps, category_cutoff_participant, behaviour_strat)

ground_by_design  <- calculate_stratified_multi(df_gps, ground_truth_tier, design_strat, delim_regex = ",\\s*")
ground_by_behav   <- calculate_stratified_multi(df_gps, ground_truth_tier, behaviour_strat, delim_regex = ",\\s*")

noise_by_design   <- calculate_stratified_multi(df_gps, noise_filtering, design_strat, delim_regex = ",\\s*")
noise_by_behav    <- calculate_stratified_multi(df_gps, noise_filtering, behaviour_strat, delim_regex = ",\\s*")

trade_by_design   <- calculate_stratified_multi(df_gps, category_tradeoff, design_strat)
trade_by_behav    <- calculate_stratified_multi(df_gps, category_tradeoff, behaviour_strat)

barriers_by_design <- calculate_stratified_multi(df_gps, category_barriers, design_strat)
barriers_by_behav  <- calculate_stratified_multi(df_gps, category_barriers, behaviour_strat)

join_strats <- function(overall, design, behav, var_name) {
  overall |>
    select(Category, `Overall N (%)` = `Formatted Result`) |>
    left_join(design, by = "Category") |>
    left_join(behav, by = "Category") |>
    mutate(Variable = var_name) |>
    relocate(Variable, Category, `Overall N (%)`)
}

df_combined_dictionaries <- bind_rows(join_strats(freq_cutoffs, cutoffs_by_design, cutoffs_by_behav, "Participant Cut-offs"),
                                      join_strats(freq_ground_truth, ground_by_design, ground_by_behav, "Ground Truth Tier"),
                                      join_strats(freq_noise_filter, noise_by_design, noise_by_behav, "Noise Filtering"),
                                      join_strats(freq_tradeoffs, trade_by_design, trade_by_behav, "Methodological Trade-offs"),
                                      join_strats(freq_barriers, barriers_by_design, barriers_by_behav, "Reported Barriers")) |>
  mutate(across(everything(), ~ replace_na(., "0 (0.0%)"))) |>
  select(Variable,
         Category,
         `Overall N (%)`,
         Experimental, Observational, `Qualitative / Mixed`,
         Alcohol, `Tobacco/Nicotine`, `Other (Cannabis, Opioids, Polysubstance)`)

table3_dictionaries <- df_combined_dictionaries |>
  as_grouped_data(groups = "Variable") |>
  as_flextable() |>
  set_header_labels(Category = "Reported Category",
                    `Other (Cannabis, Opioids, Polysubstance)` = "Other") |>
  add_header_row(top = TRUE, 
                 values = c("", "", "By Study Design", "By Addictive Behaviour"), 
                 colwidths = c(1, 1, 3, 3)) |>
  align(i = 1, part = "header", align = "center") |>
  bold(part = "header") |>
  bold(j = 1, i = ~ !is.na(Variable), bold = TRUE, part = "body") |>
  fontsize(size = 9, part = "all") |>
  autofit()

dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)

table3_dictionaries |>
  save_as_docx(path = here("outputs", "tables", "Table3_GPS_Methodology_Dictionaries.docx"))

# 5. Visualisations: Trade-off Reasons
# -------------------------------------------------------------------------
library(ggplot2)

plot_data_tradeoffs <- df_gps |>
  select(study_id, design_strat, category_tradeoff) |>
  drop_na(category_tradeoff) |>
  separate_longer_delim(category_tradeoff, delim = regex(";\\s*")) |>
  mutate(Category = str_replace_all(category_tradeoff, "_", " "),
         Category = str_to_title(Category),
         Category = str_replace_all(Category, "Gps", "GPS"),
         Category = str_replace_all(Category, "Ema", "EMA")) |>
  count(Category, design_strat, name = "Frequency") |>
  # Calculate total frequencies to order the bars
  group_by(Category) |>
  mutate(Total_Freq = sum(Frequency)) |>
  ungroup() |>
  mutate(Category = reorder(Category, Total_Freq))

p_tradeoffs <- ggplot(plot_data_tradeoffs, aes(x = Category, y = Frequency, fill = design_strat)) +
  geom_col(width = 0.7) +
  coord_flip() +
  labs(title = "Reported Methodological Trade-offs by Study Design", 
       x = NULL, 
       y = "Number of Studies",
       fill = "Study Design") +
  scale_fill_viridis_d(option = "mako", begin = 0.2, end = 0.8) +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 10, face = "bold"),
        legend.position = "bottom",
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold", margin = margin(b = 15)))

dir.create(here("outputs", "figures"), showWarnings = FALSE, recursive = TRUE)
ggsave(filename = here("outputs", "figures", "Figure1_Methodological_Tradeoffs.png"), plot = p_tradeoffs, width = 8, height = 6, dpi = 300, bg = "white")
