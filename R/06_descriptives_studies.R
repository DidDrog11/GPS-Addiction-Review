# -------------------------------------------------------------------------
# Script: 06_descriptives_studies.R
# Purpose: Generate summary statistics for study characteristics
# Author: David Simons
# Date: 2026-04-01
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

if (!require("gtsummary")) install.packages("gtsummary")
library(gtsummary)

# 1. Load Analytic Dataset
# -------------------------------------------------------------------------
df_main <- readRDS(here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))

# 2. Data Type Coercion 
# -------------------------------------------------------------------------
df_analysis <- df_main |>
  mutate(year = as.numeric(year),
         n_participants_analytical = as.numeric(n_participants_analytical),
         mean_age = as.numeric(mean_age),
         perc_female = as.numeric(perc_female) * 100,
         study_duration = as.numeric(study_duration_days),
         addictive_behaviour_clean = case_when(str_detect(addictive_behaviour, ",") | str_detect(addictive_behaviour, "(?i)Polysubstance") ~ "Polysubstance/Multiple",
                                               addictive_behaviour %in% c("Tobacco/Nicotine", "Alcohol", "Cannabis", "Opioids", "Gambling") ~ addictive_behaviour,
                                               TRUE ~ "Other"),
         study_design = ifelse(str_detect(study_design, "Observational"), "Observational", study_design),
         design_strat = case_when(str_detect(study_design, "Observational") ~ "Observational",
                                  str_detect(study_design, "Experimental") ~ "Experimental",
                                  str_detect(study_design, "Qualitative|Mixed Methods") ~ "Qualitative / Mixed",
                                  TRUE ~ "Other"),
         country = ifelse(is.na(country), "Not Reported", country),
         behaviour_strat = case_when(addictive_behaviour_clean %in% c("Alcohol", "Tobacco/Nicotine") ~ addictive_behaviour_clean,
                                     TRUE ~ "Other (Cannabis, Opioids, Polysubstance)"))

# 3. Study Characteristics Summary
# -------------------------------------------------------------------------
shared_labels <- list(addictive_behaviour_clean ~ "Addictive Behaviour",
                      country ~ "Country",
                      study_design ~ "Study Design",
                      n_participants_analytical ~ "Sample Size (Analytical)",
                      study_duration ~ "Study Duration (Days)",
                      mean_age ~ "Study-Level Mean Age",
                      perc_female ~ "Female (%)",
                      dependence_measure_clean ~ "Dependence/Severity Measure Used",
                      participant_incentives ~ "Incentive Schedule")

table_by_design <- df_analysis |>
  select(design_strat, study_design,
         addictive_behaviour_clean, country, n_participants_analytical, 
         study_duration, mean_age, perc_female, dependence_measure_clean, participant_incentives) |>
  tbl_summary(by = design_strat,
              statistic = list(all_continuous() ~ "{median} ({p25}, {p75})", 
                               all_categorical() ~ "{n} ({p}%)"),
    digits = all_continuous() ~ 1,
    missing = "ifany", missing_text = "Not Reported",
    label = shared_labels) |>
  add_overall() |>
  modify_header(all_stat_cols() ~ "**{level}**\n(N = {n})")

table_by_behaviour <- df_analysis |>
  select(behaviour_strat, addictive_behaviour_clean,
         study_design, country, n_participants_analytical, 
         study_duration, mean_age, perc_female, dependence_measure_clean, participant_incentives) |>
  tbl_summary(by = behaviour_strat,
              statistic = list(all_continuous() ~ "{median} ({p25}, {p75})", 
                               all_categorical() ~ "{n} ({p}%)"),
    digits = all_continuous() ~ 1,
    missing = "ifany",
    missing_text = "Not Reported",
    label = shared_labels) |>
  modify_header(all_stat_cols() ~ "**{level}**\n(N = {n})")

# 4. Save Outputs
# -------------------------------------------------------------------------
table_study_characteristics <- tbl_merge(tbls = list(table_by_design, table_by_behaviour),
                                         tab_spanner = c("**By Study Design**", "**By Addictive Behaviour**")) |>
  bold_labels()

dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)

table_study_characteristics |>
  as_flex_table() |>
  flextable::fontsize(size = 9, part = "all") |>
  flextable::autofit() |>
  flextable::save_as_docx(path = here("outputs", "tables", "Table1_Study_Characteristics.docx"))
