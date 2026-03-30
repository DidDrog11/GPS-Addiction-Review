source(here::here("R", "00_setup.R"))

citations_for_screening <- read_xlsx(here("data", "02_processed", "citations_to_screen_2025-12-30_OP.xlsx"), guess_max = 5000)

set.seed(123)
sampled_subset <- citations_for_screening |>
  slice_sample(prop = 0.2, replace = FALSE)

# write_xlsx(sampled_subset, here("data", "02_processed", "citations_to_screen_2025-12-30_DS.xlsx"))

# After screening
screened_citations_for_agreement <- read_xlsx(here("data", "02_processed", "citations_to_screen_2025-12-30_DS.xlsx"), guess_max = 5000)

post_screening <- citations_for_screening |>
  select(-DS_rating) |>
  left_join(screened_citations_for_agreement |>
              select(study_id, DS_rating), by = "study_id")

# write_xlsx(post_screening, here("data", "02_processed", "screened_citations_2025-12-30_OP_DS.xlsx"))

agreement <- citations_for_screening |>
  select(-DS_rating) |>
  left_join(screened_citations_for_agreement |>
              select(study_id, DS_rating), by = "study_id") |>
  drop_na(DS_rating)

positive_agreement <- agreement |>
  filter(OP_rating == "yes" & DS_rating == "yes")

negative_agreement <- agreement |>
  filter(OP_rating == "no" & DS_rating == "no")

disagreement <- agreement |>
  filter(OP_rating != DS_rating)|>
  relocate(DS_rating, .after = OP_rating)
