# -------------------------------------------------------------------------
# Script: 08_main_results_and_quality.R
# Purpose: Generate summary statistics for GPS results and quality appraisal
# Author: David Simons & Olga Perski
# Date: 2026-04-01
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

if (!require("gtsummary")) install.packages("gtsummary")
if (!require("flextable")) install.packages("flextable")
library(gtsummary)
library(flextable)
library(ggplot2)

# 1. Load Analytic Datasets
# -------------------------------------------------------------------------
df_main <- readRDS(here("data", "04_analytic_datasets", "cleaned_main_extraction.rds"))
df_qa   <- readRDS(here("data", "04_analytic_datasets", "cleaned_qa_combined.rds"))

# Prepare behaviour stratification
df_main <- df_main |>
  mutate(addictive_behaviour_clean = case_when(str_detect(addictive_behaviour, ",") | str_detect(addictive_behaviour, "(?i)Polysubstance") ~ "Polysubstance/Multiple",
                                               addictive_behaviour %in% c("Tobacco/Nicotine", "Alcohol", "Cannabis", "Opioids", "Gambling") ~ addictive_behaviour,
                                               TRUE ~ "Other"),
    behaviour_strat = case_when(addictive_behaviour_clean %in% c("Alcohol", "Tobacco/Nicotine") ~ addictive_behaviour_clean,
                                TRUE ~ "Other (Cannabis, Opioids, Polysubstance)"))

n_studies <- nrow(df_main)

# 2. GPS Features per Study (Median, IQR, Range)
# -------------------------------------------------------------------------
df_feature_counts <- df_main |>
  select(study_id, category_gps_features_all) |>
  drop_na(category_gps_features_all) |>
  # Count the number of features by counting separators (+1)
  mutate(n_features = str_count(category_gps_features_all, ";") + 1)

feature_summary <- summary(df_feature_counts$n_features)
median_features <- feature_summary["Median"]
iqr_features    <- IQR(df_feature_counts$n_features)
min_features    <- feature_summary["Min."]
max_features    <- feature_summary["Max."]

message(sprintf("GPS Features per study: Median = %.1f, IQR = %.1f, Range = [%d - %d]", 
                median_features, iqr_features, min_features, max_features))

# GPS QA
is_reported <- function(x) {
  !is.na(x) & !str_detect(str_to_lower(x), "^not reported$|^nr$|^unspecified$|^none$")
}

get_mode <- function(x) {
  x_clean <- x[is_reported(x)]
  if (length(x_clean) == 0) return("-")
  freq_table <- sort(table(x_clean), decreasing = TRUE)
  paste0(names(freq_table)[1], " (n=", freq_table[1], ")")
}

get_median_str <- function(x) {
  x_num <- as.numeric(as.character(x[is_reported(x)]))
  x_num <- x_num[!is.na(x_num)]
  if (length(x_num) == 0) return("-")
  paste0("Median: ", round(median(x_num), 1))
}

n_total <- nrow(df_main)

df_gps_reporting <- tibble(`Practice` = c("P1: Report brand/model of GPS device",
                                          "P2: Report sampling frequency",
                                          "P3: Report intended wear time",
                                          "P4: Report missing GPS data (% total)",
                                          "P5: Identify method of GPS noise filtering",
                                          "P6: Specify imputation method",
                                          "P7: Report post-processing data linkage",
                                          "P8: Report criteria for participant inclusion (cut-offs)"),
                           `Reported (N)` = c(sum(is_reported(df_main$gps_device)),
                                              sum(is_reported(df_main$gps_sampling_frequency_clean)),
                                              sum(is_reported(df_main$gps_wear_time_intended)),
                                              sum(is_reported(df_main$gps_perc_missing)),
                                              sum(is_reported(df_main$noise_filtering)),
                                              sum(is_reported(df_main$imputation_method_clean)),
                                              sum(is_reported(df_main$post_processing_linkage)),
                                              sum(is_reported(df_main$category_cutoff_participant))),
                           `Most frequent (or median)` = c(get_mode(df_main$gps_device),
                                                           get_mode(df_main$gps_sampling_frequency_clean),
                                                           get_mode(df_main$gps_wear_time_intended),
                                                           get_median_str(df_main$gps_perc_missing),
                                                           get_mode(df_main$noise_filtering),
                                                           get_mode(df_main$imputation_method_clean),
                                                           get_mode(df_main$post_processing_linkage),
                                                           get_mode(df_main$category_cutoff_participant))) |>
  mutate(`Reported (%)` = round((`Reported (N)` / n_total) * 100, 1),
         `Studies meeting criteria, n (%)` = sprintf("%d (%.1f%%)", `Reported (N)`, `Reported (%)`),
         `Most frequent (or median)` = case_when(str_detect(Practice, "P7") ~ str_replace_all(`Most frequent (or median)`, "TRUE", "Yes"),
                                                 str_detect(Practice, "P8") ~ str_replace_all(`Most frequent (or median)`, "_", " ") |> 
                                                   str_to_title() |> 
                                                   str_replace_all("Gps", "GPS"),
                                                 TRUE ~ `Most frequent (or median)`)) |>
  select(`Practice`, `Studies meeting criteria, n (%)`, `Most frequent (or median)`)

# Create the Flextable
table_gps_reporting <- df_gps_reporting |>
  flextable() |>
  set_header_labels(`Practice` = "Practices reported",
                    `Studies meeting criteria, n (%)` = "Studies meeting criteria, n (%)",
                    `Most frequent (or median)` = "Most frequent (number of studies or median)") |>
  bold(part = "header") |>
  align(j = 2:3, align = "center", part = "all") |>
  width(j = 1, width = 2.5) |>
  width(j = 2, width = 1.5) |>
  width(j = 3, width = 2.5) |>
  fontsize(size = 9, part = "all") |>
  autofit()

# Export
dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
table_gps_reporting |>
  save_as_docx(path = here("outputs", "tables", "Table3_GPS_Reporting_Standards.docx"))

# 3. Decision Rules (Intervention Studies Only)
# -------------------------------------------------------------------------
# Filter to only Experimental designs
df_interventions <- df_main |>
  filter(str_detect(study_design, "Experimental"))

n_interventions <- nrow(df_interventions)

valid_rules <- df_interventions |>
  select(study_id, category_intervention_rule) |>
  drop_na(category_intervention_rule) |>
  filter(category_intervention_rule != "not_applicable") |>
  separate_longer_delim(category_intervention_rule, delim = regex(";\\s*")) |>
  mutate(rule_clean = str_replace_all(category_intervention_rule, "_", " "),
         rule_clean = str_to_title(rule_clean)) |>
  count(rule_clean, name = "Frequency") |>
  arrange(desc(Frequency))

if(nrow(valid_rules) > 0) {
  rules_text <- paste(paste0(valid_rules$rule_clean, " (n=", valid_rules$Frequency, ")"), collapse = ", ")
  message(sprintf("Decision Rules Summary: Of the %d experimental studies, valid decision rules were: %s.", 
                  n_interventions, rules_text))
}

# 4. Visualisations: GPS Features by Addictive Behaviour
# -------------------------------------------------------------------------
feature_hierarchy <- c(
  "Unspecified",
  "Time Weighted Metrics: General",
  "Time Weighted Exposure: Environmental Context",
  "Time Weighted Exposure: Disadvantaged Neighbourhood",
  "Time Weighted Exposure: Addiction",
  "Movement Patterns: Unspecified",
  "Movement Patterns: Variability",
  "Movement Patterns: Speed",
  "Movement Patterns: Distance",
  "Movement Patterns: Addiction",
  "Raw Coordinates",
  "Place Visits: General",
  "Place Visits: Addiction",
  "Proximity Based Exposure: General",
  "Proximity Based Exposure: Environmental Context",
  "Proximity Based Exposure: Disadvantaged Neighbourhood",
  "Proximity Based Exposure: Addiction"
)

plot_data_features <- df_main |>
  select(study_id, behaviour_strat, category_gps_features_all) |>
  drop_na(category_gps_features_all) |>
  separate_longer_delim(category_gps_features_all, delim = regex(";\\s*")) |>
  mutate(Category = str_replace_all(category_gps_features_all, "_", " "),
         Category = str_to_title(Category),
         Category = str_replace_all(Category, "Gps", "GPS"),
         Category = str_replace_all(Category, "Patterns", "Patterns:"),
         Category = str_replace_all(Category, "Visits", "Visits:"),
         Category = str_replace_all(Category, "Exposure", "Exposure:"),
         Category = str_replace_all(Category, "Metrics", "Metrics:")) |>
  count(Category, behaviour_strat, name = "Frequency") |>
  # Order logically by methodological family rather than total frequency
  mutate(Category = factor(Category, levels = feature_hierarchy)) |>
  arrange(Category)

p_features <- ggplot(plot_data_features, aes(x = Category, y = Frequency, fill = behaviour_strat)) +
  geom_col(width = 0.7) +
  geom_text(aes(label = Frequency), position = position_stack(vjust = 0.5), size = 3, colour = "white", fontface = "bold") +
  coord_flip() +
  labs(title = "GPS Features Utilised by Addictive Behaviour",
       x = NULL, 
       y = "Number of Studies",
       fill = "Addictive Behaviour") +
  scale_fill_viridis_d(option = "mako", begin = 0.2, end = 0.8) +
  theme_minimal() +
  theme(axis.text.y = element_text(size = 9, face = "bold"),
        legend.position = "bottom",
        panel.grid.major.y = element_blank(),
        plot.title = element_text(face = "bold", margin = margin(b = 15)))

dir.create(here("outputs", "figures"), showWarnings = FALSE, recursive = TRUE)
ggsave(here("outputs", "figures", "Figure3_GPS_Features_by_Behaviour.png"), plot = p_features, width = 10, height = 7, dpi = 300, bg = "white")

# 5. Quality Appraisal Individual
# -------------------------------------------------------------------------

# Controlled Interventions
qa_questions_controlled <- c("Question 1 - Was the study described as randomised, a randomised trial, a randomised clinical trial, or an RCT?",
                             "Question 2 - Was the method of randomisation adequate (i.e., use of randomly generated assignment)?",
                             "Question 3 - Was the treatment allocation concealed (so that assignments could not be predicted)?",
                             "Question 4 - Were study participants and providers blinded to treatment group assignment?",
                             "Question 5 - Were the people assessing the outcomes blinded to the participants' group assignments?",
                             "Question 6 - Were the groups similar at baseline on important characteristics that could affect outcomes (e.g., demographics, risk factors, co-morbid conditions)?",
                             "Question 7 - Was the overall drop-out rate from the study at endpoint 20% or lower of the number allocated to treatment?",
                             "Question 8 - Was the differential drop-out rate (between treatment groups) at endpoint 15 percentage points or lower?",
                             "Question 9 - Was there high adherence to the intervention protocols for each treatment group?",
                             "Question 10 - Were other interventions avoided or similar in the groups (e.g., similar background treatments)?",
                             "Question 11 - Were outcomes assessed using valid and reliable measures, implemented consistently across all study participants?",
                             "Question 12 - Did the authors report that the sample size was sufficiently large to be able to detect a difference in the main outcome between groups with at least 80% power?",
                             "Question 13 - Were outcomes reported or subgroups analysed prespecified (i.e., identified before analyses were conducted)?",
                             "Question 14 - Were all randomised participants analysed in the group to which they were originally assigned, i.e., did they use an intention-to-treat analysis?")

# Combine into a single paragraph for document output
qa_paragraph <- paste(qa_questions_controlled, collapse = "\n")

# Categorise the studies
df_qa_controlled_rated <- df_qa |>
  filter(qa_design_tool == "Controlled Interventions") |>
  mutate(overall_rating = case_when(# 1. Fatal Flaws -> POOR
    # Triggered by 'No' OR 'Other' (NR, CD, NA) on drop-out (Q7, Q8), ITT (Q14), or Randomisation (Q2)
    quality_7 %in% c("No", "Other") | 
    quality_8 %in% c("No", "Other") | 
    quality_14 %in% c("No", "Other") | 
    quality_2 %in% c("No", "Other") ~ "Poor",
      
    # 2. Strong Methodology -> GOOD
    # Must explicitly be 'Yes' on all key internal validity checks
    quality_2 == "Yes" & quality_3 == "Yes" & quality_5 == "Yes" & quality_6 == "Yes" ~ "Good",
    
    # 3. Everything else -> FAIR
    TRUE ~ "Fair"))

# Check the distribution
table(df_qa_controlled_rated$overall_rating, useNA = "ifany")

# Pre-post
qa_questions_prepost <- c("Question 1 - Was the study question or objective clearly stated?",
                          "Question 2 - Were eligibility/selection criteria for the study population prespecified and clearly described?",
                          "Question 3 - Were the participants in the study representative of those who would be eligible for the test/service/intervention in the general or clinical population of interest?",
                          "Question 4 - Were all eligible participants that met the prespecified entry criteria enrolled?",
                          "Question 5 - Was the sample size sufficiently large to provide confidence in the findings?",
                          "Question 6 - Was the test/service/intervention clearly described and delivered consistently across the study population?",
                          "Question 7 - Were the outcome measures prespecified, clearly defined, valid, reliable, and assessed consistently across all study participants?",
                          "Question 8 - Were the people assessing the outcomes blinded to the participants' exposures/interventions?",
                          "Question 9 - Was the loss to follow-up after baseline 20% or less? Were those lost to follow-up accounted for in the analysis?",
                          "Question 10 - Did the statistical methods examine changes in outcome measures from before to after the intervention? Were statistical tests done that provided p values for the pre-to-post changes?",
                          "Question 11 - Were outcome measures of interest taken multiple times before the intervention and multiple times after the intervention (i.e., did they use an interrupted time-series design)?",
                          "Question 12 - If the intervention was conducted at a group level (e.g., a whole hospital, a community, etc.) did the statistical analysis take into account the use of individual-level data to determine effects at the group level?")

# Combine into a single paragraph for document output (or bullet points later)
qa_paragraph_prepost <- paste(qa_questions_prepost, collapse = "\n")

df_qa_prepost_rated <- df_qa |>
  filter(qa_design_tool == "Pre-Post") |>
  mutate(overall_rating = case_when(# 1. Fatal Flaws -> POOR
    # Triggered by 'No' or 'Other' (NR/CD/NA) on stats (Q10), outcomes (Q7), or follow-up (Q9)
    quality_10 %in% c("No", "Other") | 
    quality_7 %in% c("No", "Other") | 
    quality_9 %in% c("No", "Other") ~ "Poor",
    
    # 2. Strong Methodology -> GOOD
    # Must pass key internal validity: eligibility (Q2), intervention delivery (Q6), plus the criticals above
    quality_2 == "Yes" & quality_6 == "Yes" & quality_7 == "Yes" & quality_9 == "Yes" & quality_10 == "Yes" ~ "Good",
      
    # 3. Everything else -> FAIR
    TRUE ~ "Fair"))

# Check the distribution
table(df_qa_prepost_rated$overall_rating, useNA = "ifany")

# Observational
qa_questions_observational <- c("Question 1 - Was the research question or objective in this paper clearly stated?",
                                "Question 2 - Was the study population clearly specified and defined?",
                                "Question 3 - Was the participation rate of eligible persons at least 50%?",
                                "Question 4 - Were all the subjects selected or recruited from the same or similar populations (including the same time period)? Were inclusion and exclusion criteria for being in the study prespecified and applied uniformly to all participants?",
                                "Question 5 - Was a sample size justification, power description, or variance and effect estimates provided?",
                                "Question 6 - For the analyses in this paper, were the exposure(s) of interest measured prior to the outcome(s) being measured?",
                                "Question 7 - Was the timeframe sufficient so that one could reasonably expect to see an association between exposure and outcome if it existed?",
                                "Question 8 - For exposures that can vary in amount or level, did the study examine different levels of the exposure as related to the outcome (e.g., categories of exposure, or exposure measured as continuous variable)?",
                                "Question 9 - Were the exposure measures (independent variables) clearly defined, valid, reliable, and implemented consistently across all study participants?",
                                "Question 10 - Was the exposure(s) assessed more than once over time?",
                                "Question 11 - Were the outcome measures (dependent variables) clearly defined, valid, reliable, and implemented consistently across all study participants?",
                                "Question 12 - Were the outcome assessors blinded to the exposure status of participants?",
                                "Question 13 - Was loss to follow-up after baseline 20% or less?",
                                "Question 14 - Were key potential confounding variables measured and adjusted statistically for their impact on the relationship between exposure(s) and outcome(s)?")

qa_paragraph_observational <- paste(qa_questions_observational, collapse = "\n")

df_qa_observational_rated <- df_qa |>
  filter(qa_design_tool == "Observational") |>
  mutate(overall_rating = case_when(# 1. Fatal Flaws -> POOR
    # Triggered by 'No' or 'Other' (NR/CD/NA) on Exposure Prior (Q6), Valid Exposures (Q9), 
    # Valid Outcomes (Q11), Follow-up Retention (Q13), or Confounding (Q14)
    quality_6 %in% c("No", "Other") |
    quality_9 %in% c("No", "Other") | 
    quality_11 %in% c("No", "Other") | 
    quality_13 %in% c("No", "Other") | 
    quality_14 %in% c("No", "Other") ~ "Poor",
      
    # 2. Strong Methodology -> GOOD
    # Must pass the criticals above, plus have a clearly defined population (Q2), 
    # >50% participation (Q3), uniform selection criteria (Q4), and sufficient timeframe (Q7)
    quality_2 == "Yes" & quality_3 == "Yes" & quality_4 == "Yes" & 
    quality_6 == "Yes" & quality_7 == "Yes" & quality_9 == "Yes" & 
    quality_11 == "Yes" & quality_13 == "Yes" & quality_14 == "Yes" ~ "Good",
      
    # 3. Everything else -> FAIR
    TRUE ~ "Fair"))

table(df_qa_observational_rated$overall_rating, useNA = "ifany")

# Combine all rated QA datasets back together
df_qa_fully_rated <- bind_rows(df_qa_controlled_rated,
                               df_qa_prepost_rated,
                               df_qa_observational_rated)

# Check the final distribution across all study types
table(df_qa_fully_rated$qa_design_tool, df_qa_fully_rated$overall_rating, useNA = "ifany")

# Reusable function for QA supplementary export
export_qa_supp_table <- function(data, questions_vec, doc_title, file_name, n_questions) {
  
  df_clean <- data |>
    select(study_id, overall_rating, starts_with("quality_"))
  
  # Replace "Other" with the specific text from the _other column
  for(i in 1:n_questions) {
    col_base <- paste0("quality_", i)
    col_other <- paste0("quality_", i, "_other")
    
    # Safety check in case a tool has fewer questions (e.g., Pre-Post has 12)
    if(col_base %in% names(df_clean) && col_other %in% names(df_clean)) {
      df_clean[[col_base]] <- ifelse(
        df_clean[[col_base]] == "Other" & !is.na(df_clean[[col_other]]),
        df_clean[[col_other]],
        df_clean[[col_base]])
    }
  }
  
  # Drop the _other columns and clean up names
  df_clean <- df_clean |>
    select(-ends_with("_other")) |>
    rename_with(~ str_replace(.x, "quality_", "Q"), starts_with("quality_")) |>
    rename(`Study` = study_id, `Quality Rating` = overall_rating) |>
    relocate(`Quality Rating`, .after = everything())
  
  # Build the Flextable
  ft <- df_clean |>
    flextable() |>
    bold(part = "header") |>
    align(j = 2:ncol(df_clean), align = "center", part = "all") |>
    fontsize(size = 9, part = "all") |>
    autofit()
  
  # Export to Word
  dir.create(here("outputs", "tables"), showWarnings = FALSE, recursive = TRUE)
  
  doc <- read_docx() |>
    body_add_par(doc_title, style = "heading 1")
  
  for (q in questions_vec) {
    doc <- doc |> body_add_par(q, style = "Normal")
  }
  
  doc <- doc |>
    body_add_par("", style = "Normal") |> 
    body_add_flextable(ft)
  
  print(doc, target = here("outputs", "tables", file_name))
}

if (!require("officer")) install.packages("officer")
library(officer)

export_qa_supp_table(data = df_qa_controlled_rated,
                     questions_vec = qa_questions_controlled,
                     doc_title = "Quality Assessment: Controlled Interventions",
                     file_name = "supplementary_qa_controlled.docx",
                     n_questions = 14)

export_qa_supp_table(data = df_qa_prepost_rated,
                     questions_vec = qa_questions_prepost,
                     doc_title = "Quality Assessment: Before-After (Pre-Post) Studies",
                     file_name = "supplementary_qa_prepost.docx",
                     n_questions = 12)

export_qa_supp_table(data = df_qa_observational_rated,
                     questions_vec = qa_questions_observational,
                     doc_title = "Quality Assessment: Observational Cohort Studies",
                     file_name = "supplementary_qa_observational.docx",
                     n_questions = 14)

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

df_qa_summary |>
  as_grouped_data(groups = "Study Design") |>
  as_flextable() |>
  bold(j = 1, i = ~ !is.na(`Study Design`), bold = TRUE, part = "body") |>
  fontsize(size = 9, part = "all") |>
  autofit() |>
  save_as_docx(path = here("outputs", "tables", "Supp_Table2_Quality_Appraisal.docx"))

# 7. Visualisations: Outcomes by Effect Direction
# -------------------------------------------------------------------------
library(ggplot2)
library(dplyr)
library(tidyr)
library(stringr)

plot_data_outcomes <- df_main |>
  mutate(combined_outcomes = coalesce(category_efficacy, category_observational)) |>
  drop_na(combined_outcomes) |>
  mutate(effect_direction = str_extract(combined_outcomes, "^[^;]+"),
         specific_outcomes = str_remove(combined_outcomes, "^[^;]+;\\s*")) |>
  mutate(effect_direction = case_when(str_detect(effect_direction, "positive") ~ "Positive",
                                      str_detect(effect_direction, "negative") ~ "Negative",
                                      str_detect(effect_direction, "mixed") ~ "Mixed",
                                      str_detect(effect_direction, "descriptive") ~ "Descriptive",
                                      str_detect(effect_direction, "unspecified") ~ "Unspecified",
                                      TRUE ~ "Other"),
         effect_direction = factor(effect_direction, levels = c("Positive", "Mixed", "Negative", "Unspecified", "Descriptive")),
         design_strat = case_when(str_detect(study_design, "Experimental") ~ "Experimental",
                                  str_detect(study_design, "Observational") ~ "Observational",
                                  str_detect(study_design, "Mixed") ~ "Mixed Methods",
                                  str_detect(study_design, "Qualitative") ~ "Qualitative",
                                  TRUE ~ "Other"),
         design_strat = factor(design_strat, levels = c("Experimental", "Observational", "Mixed Methods", "Qualitative"))) |>
  separate_longer_delim(specific_outcomes, delim = regex(";\\s*")) |>
  mutate(Outcome = str_replace_all(specific_outcomes, "_", " "),
         Outcome = str_to_title(Outcome)) |>
  select(effect_direction, Outcome, behaviour_strat, design_strat)

set.seed(42) 
p_outcomes <- ggplot(plot_data_outcomes, aes(x = effect_direction, y = Outcome)) +
  annotate("rect", xmin = 4.5, xmax = 5.5, ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "grey40") +
  geom_jitter(aes(colour = behaviour_strat, shape = design_strat), 
              width = 0.25, height = 0.25, size = 3, alpha = 0.8) +
  labs(title = "Reported Outcomes by Effect Direction, Addictive Behaviour, and Study Design",
       x = "Reported Direction of Effect / Association",
       y = "Reported Outcome Type",
       colour = "Addictive Behaviour",
       shape = "Study Design") +
  scale_colour_manual(values = c("#E69F00", "#56B4E9", "#009E73")) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
        axis.text.y = element_text(face = "bold"),
        legend.position = "bottom",
        legend.box = "vertical",
        panel.grid.major = element_line(colour = "grey90"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", margin = margin(b = 15)))

dir.create(here("outputs", "figures"), showWarnings = FALSE, recursive = TRUE)

ggsave(filename = here("outputs", "figures", "Figure5_Outcomes_by_Direction.png"), 
       plot = p_outcomes, 
       width = 11, 
       height = 9, 
       dpi = 300, 
       bg = "white")

# 8. Visualisations: GPS Features by Effect Direction
# -------------------------------------------------------------------------
plot_data_features_dir <- df_main |>
  mutate(combined_outcomes = coalesce(category_efficacy, category_observational)) |>
  drop_na(combined_outcomes, category_gps_features_all) |>
  mutate(effect_direction = str_extract(combined_outcomes, "^[^;]+"),
         effect_direction = case_when(str_detect(effect_direction, "positive") ~ "Positive",
                                      str_detect(effect_direction, "negative") ~ "Negative",
                                      str_detect(effect_direction, "mixed") ~ "Mixed",
                                      str_detect(effect_direction, "descriptive") ~ "Descriptive",
                                      str_detect(effect_direction, "unspecified") ~ "Unspecified",
                                      TRUE ~ "Other"),
         effect_direction = factor(effect_direction, levels = c("Positive", "Mixed", "Negative", "Unspecified", "Descriptive")),
         design_strat = case_when(str_detect(study_design, "Experimental") ~ "Experimental",
                                  str_detect(study_design, "Observational") ~ "Observational",
                                  str_detect(study_design, "Mixed") ~ "Mixed Methods",
                                  str_detect(study_design, "Qualitative") ~ "Qualitative",
                                  TRUE ~ "Other"),
         design_strat = factor(design_strat, levels = c("Experimental", "Observational", "Mixed Methods", "Qualitative"))) |>
  separate_longer_delim(category_gps_features_all, delim = regex(";\\s*")) |>
  mutate(Feature = str_replace_all(category_gps_features_all, "_", " "),
         Feature = str_to_title(Feature),
         Feature = str_replace_all(Feature, "Gps", "GPS"),
         Feature = str_replace_all(Feature, "Ema", "EMA"),
         Feature = str_replace_all(Feature, "Patterns", "Patterns:"),
         Feature = str_replace_all(Feature, "Visits", "Visits:"),
         Feature = str_replace_all(Feature, "Exposure", "Exposure:"),
         Feature = str_replace_all(Feature, "Metrics", "Metrics:"),
         # Apply the manual hierarchical factor ordering
         Feature = factor(Feature, levels = feature_hierarchy)) |>
  select(effect_direction, Feature, behaviour_strat, design_strat)

set.seed(42) 
p_features_dir <- ggplot(plot_data_features_dir, aes(x = effect_direction, y = Feature)) +
  annotate("rect", xmin = 3.5, xmax = 5.5, ymin = -Inf, ymax = Inf, alpha = 0.15, fill = "grey40") +
  geom_jitter(aes(colour = behaviour_strat, shape = design_strat), 
              width = 0.25, height = 0.25, size = 3, alpha = 0.8) +
  labs(title = "Reported GPS Features by Effect Direction, Addictive Behaviour, and Study Design",
       x = "Reported Direction of Effect / Association",
       y = "Utilised GPS Feature",
       colour = "Addictive Behaviour",
       shape = "Study Design") +
  scale_colour_manual(values = c("#E69F00", "#56B4E9", "#009E73")) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1, face = "bold"),
        axis.text.y = element_text(face = "bold"),
        legend.position = "bottom",
        legend.box = "vertical",
        panel.grid.major = element_line(colour = "grey90"),
        panel.grid.minor = element_blank(),
        plot.title = element_text(face = "bold", margin = margin(b = 15)))

dir.create(here("outputs", "figures"), showWarnings = FALSE, recursive = TRUE)

ggsave(filename = here("outputs", "figures", "Figure6_Features_by_Direction.png"), 
       plot = p_features_dir, 
       width = 11, 
       height = 9, 
       dpi = 300, 
       bg = "white")
