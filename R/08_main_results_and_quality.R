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
  mutate(
    addictive_behaviour_clean = case_when(
      str_detect(addictive_behaviour, ",") | str_detect(addictive_behaviour, "(?i)Polysubstance") ~ "Polysubstance/Multiple",
      addictive_behaviour %in% c("Tobacco/Nicotine", "Alcohol", "Cannabis", "Opioids", "Gambling") ~ addictive_behaviour,
      TRUE ~ "Other"
    ),
    behaviour_strat = case_when(
      addictive_behaviour_clean %in% c("Alcohol", "Tobacco/Nicotine") ~ addictive_behaviour_clean,
      TRUE ~ "Other (Cannabis, Opioids, Polysubstance)"
    )
  )

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
  mutate(
    rule_clean = str_replace_all(category_intervention_rule, "_", " "),
    rule_clean = str_to_title(rule_clean)
  ) |>
  count(rule_clean, name = "Frequency") |>
  arrange(desc(Frequency))

if(nrow(valid_rules) > 0) {
  rules_text <- paste(paste0(valid_rules$rule_clean, " (n=", valid_rules$Frequency, ")"), collapse = ", ")
  message(sprintf("Decision Rules Summary: Of the %d experimental studies, valid decision rules were: %s.", 
                  n_interventions, rules_text))
}

# 4. Visualisations: GPS Features by Addictive Behaviour
# -------------------------------------------------------------------------
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
  # Calculate total frequencies to order the bars
  group_by(Category) |>
  mutate(Total_Freq = sum(Frequency)) |>
  ungroup() |>
  mutate(Category = reorder(Category, Total_Freq))

p_features <- ggplot(plot_data_features, aes(x = Category, y = Frequency, fill = behaviour_strat)) +
  geom_col(width = 0.7) +
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
ggsave(here("outputs", "figures", "Figure2_GPS_Features_by_Behaviour.png"), plot = p_features, width = 9, height = 7, dpi = 300, bg = "white")

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
  save_as_docx(path = here("outputs", "tables", "Table6_Quality_Appraisal.docx"))
