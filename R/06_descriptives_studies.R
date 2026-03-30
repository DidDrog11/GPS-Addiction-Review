# -------------------------------------------------------------------------
# Script: 06_descriptives_studies.R
# Purpose: Generate summary statistics for study characteristics
# Author: David Simons
# Date: 2026-03-30
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
         addictive_behaviour_clean = case_when(str_detect(addictive_behaviour, ",") | str_detect(addictive_behaviour, "(?i)Polysubstance") ~ "Polysubstance/Multiple",
                                               addictive_behaviour %in% c("Tobacco/Nicotine", "Alcohol", "Cannabis", "Opioids", "Gambling") ~ addictive_behaviour,
                                               TRUE ~ "Other"))

# 3. Study Characteristics Summary
# -------------------------------------------------------------------------
table_study_characteristics <- df_analysis |>
  select(addictive_behaviour_clean,
         country,
         study_design,
         n_participants_analytical,
         mean_age,
         perc_female,
         participant_incentives) |>
  tbl_summary(statistic = list(
    all_continuous() ~ "{median} ({p25}, {p75})",
    all_categorical() ~ "{n} ({p}%)"),
    digits = all_continuous() ~ 1,
    missing_text = "Not Reported",
    label = list(addictive_behaviour_clean ~ "Addictive Behaviour",
                 country ~ "Country",
                 study_design ~ "Study Design",
                 n_participants_analytical ~ "Sample Size (Analytical)",
                 mean_age ~ "Mean Age",
                 perc_female ~ "Female (%)",
                 participant_incentives ~ "Incentive Schedule")) |>
  modify_header(label = "**Study Characteristic**") |>
  bold_labels()

# 4. Save Outputs
# -------------------------------------------------------------------------
dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)

table_study_characteristics |>
  as_flex_table() |>
  flextable::save_as_docx(path = here("outputs", "tables", "Table1_Study_Characteristics.docx"))
