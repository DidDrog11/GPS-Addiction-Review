# exclusions and reasons

df01 <- df0 %>%
  mutate(
    exclusion_label = case_when(
      exclusion_reason == "No Individual-Level GPS Analysis" ~ 1,
      exclusion_reason == "No Individual-Level GPS Analysis, Not an Addictive Behaviour" ~ 1,
      exclusion_reason == "Not Empirical" ~ 2,
      exclusion_reason == "GPS Data Not Linked to Addictive Behaviour" ~ 3,
      exclusion_reason == "Not an Addictive Behaviour" ~ 4,
      TRUE ~ NA_real_
    )
  )

df01 %>%
  count(screening_decision_OP) %>%
  mutate(percent = n / sum(n) * 100)

df01 %>%
  filter(screening_decision_OP == "EXCLUDE") %>%
  count(exclusion_label) %>%
  mutate(percent = n / sum(n) * 100)

# create PRISMA flow chart

prisma_data <- PRISMA_data(
  database_results = 4217,
  register_results = 0,
  other_results = 3,
  duplicates_removed = 1000,
  records_screened = 3220,
  records_excluded = 3119,
  fulltext_assessed = 101,
  fulltext_excluded = 41,
  reasons = c(
    "No individual-level GPS analysis (n = 35)",
    "Not empirical (n = 3)",
    "GPS not linked to addictive behaviour (n = 2)",
    "Not addictive behaviour (n = 1)"
  ),
  included = 60
)
