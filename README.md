# Use of GPS to detect, predict and intervene on addictive behaviours: A Systematic Review

## Overview
This repository contains the code and reproducible workflow for a systematic review examining the use of GPS data in addiction research. The review protocol is registered at [PROSPERO](https://www.crd.york.ac.uk/PROSPERO/view/CRD420251247450).

**Note:** This repository contains *code only*. Full-text PDFs are stored elsewhere to comply with copyright standards.

## Workflow & Directory Structure

The project follows a linear 8-step workflow, divided into **Phase A (Screening)** and **Phase B (Extraction)**.

### Phase A: Search & Screening
**Goal:** Convert raw database exports into a clean list for screening.

1.  **Searches Run:** Raw `.ris` or `.bib` files are saved locally in `data/01_raw_searches/`.
2.  **Deduplication:**
    * *Script:* `code/01_search_cleaning/01_deduplication.R`
    * *Action:* Merges files and removes duplicates.
3.  **String Matching & Specificity Check:**
    * *Script:* `code/01_search_cleaning/02_string_matching.R`
    * *Action:* Filters citations based on exclusion keywords to reduce noise before human screening.
4.  **Rayyan Upload:**
    * *Script:* `code/01_search_cleaning/03_export_for_rayyan.R`
    * *Action:* Generates a standard import file for Rayyan.
    * *Manual Step:* Team screens Title/Abstracts in Rayyan.

### Phase B: Extraction & Analysis
**Goal:** Link included studies to full texts and extract data into the cloud.

5.  **Full Text Retrieval:**
    * Included articles are identified from Rayyan export.
    * PDFs are stored in the shared Google Drive folder.
6.  **Master Linking List:**
    * A "Master List" Google Sheet is created containing: `Study_ID`, `Title`, `Year`, `PDF_Link`.
7.  **Data Extraction (Google Sheets):**
    * Extractors work in individual Google Sheets.
    * Sheets are generated from the template.
    * *Constraint:* Columns A-E (Study Metadata) are protected; extractors enter data in Columns F onwards.
8.  **Data Processing (R + Google Drive API):**
    * *Script:* `code/02_extraction_analysis/01_fetch_extraction_data.R`
    * *Action:* Authenticates via `googledrive` package, pulls all extraction sheets, binds them into a single dataset, and runs quality checks (e.g., checking for invalid GPS feature definitions).

## Data Extraction

Each included study was extracted by one reviewer and checked by a second, following a Data Extraction Manual (01.01.26). Items not reported in a paper were entered as `NR`. The fields below are the columns of the extraction sheet (`data/03_for_extraction/raw_extraction_*.rds`). Categories listed for drop-down fields are those used across the included studies. Fields marked  were added to the sheet after the manual was written.

<details>
<summary><b>1. Study identification</b></summary>

| Field | Description | Format |
|---|---|---|
| `study_id` | Assigned study ID (from the Full Texts folder) | ID |
| `author`, `year` | First author and publication year | Text, year |
| `country` | Country in which data collection took place | Text |
| `duplicate_sample`  | Whether the sample overlaps with another included study, and which | Text (e.g. "yes, same sample as 11") |

Administrative columns (`nr`, `assigned to`, `double checked by`, `notes`) record the extractor, checker and queries.

</details>

<details>
<summary><b>2. Study design and sample</b></summary>

| Field | Description | Format |
|---|---|---|
| `addictive_behaviour` | Behaviour(s) studied | Alcohol; Tobacco/Nicotine; Cannabis; Opioids; Stimulants; Gambling; Polysubstance; Other |
| `study_design` | Study design | Observational: Longitudinal/Cohort; Observational: Case-crossover; Experimental: RCT; Experimental: JITAI/Microrandomised; Mixed Methods; Qualitative |
| `intervention`  | Whether the study delivered an intervention | yes / no |
| `study_duration_days` | Study duration in days; days of GPS collection if these differ | Number |
| `n_participants_eligible` | Participants eligible to take part | Number |
| `n_participants_analytical` | Participants in the analytical sample | Number |
| `participants_notes` | Notes on the sample | Text |
| `mean_age` | Mean age of the analytical sample; other formats noted in brackets, e.g. "18-29 (age range)" | Number / text |
| `perc_female` | Percentage female | Number |
| `mean_dependence` | Mean dependence; other formats noted in brackets | Number / text |
| `dependence_scales` | Scale(s) used to measure dependence | Text |
| `perc_low_income` | Percentage with low income | Number |
| `perc_low_edu` | Percentage with low educational attainment | Number |
| `perc_low_sep_other` | Any other indicator of socioeconomic position, e.g. "24 (percentage unemployed)" | Text |
| `participant_incentives` | Participant payment | Fixed payment (monetary, vouchers, gift cards); Pro-rated (per day/survey); None; Not reported; Other |

</details>

<details>
<summary><b>3. GPS data collection</b></summary>

| Field | Description | Format |
|---|---|---|
| `gps_device` | Type of GPS device | Smartphone (own device); Smartphone (study provided); Dedicated GPS logger; Other |
| `gps_device_note` | Name or model of the device | Text |
| `gps_sampling_frequency_s` | Sampling interval, converted to seconds | Number / text |
| `gps_wear_time_intended` | Hours per day participants were asked to carry the device | Number |
| `gps_mean_wear_time_reported` | Mean hours per day the device was actually carried | Number |

</details>

<details>
<summary><b>4. Data quality and preprocessing</b></summary>

| Field | Description | Format |
|---|---|---|
| `gps_perc_missing` | Percentage of GPS data excluded for any reason (non-wear, lost device, non-contact, noise) | Number |
| `perc_noisy` | Percentage of GPS data that was noisy (recorded but likely erroneous) | Number |
| `gps_participant_level_cut_offs` | Cut-off for including a participant's data, e.g. ≥ 50% non-missing | Text, coded (see 10) |
| `noise_filtering` | Method of noise detection and removal (data outside the study area = Manual Cleaning) | Manual Cleaning; Speed Thresholds; Accuracy/DOP Thresholds; None Reported; Other |
| `noise_filtering_notes`  | Details of noise filtering | Text |
| `imputation_method` | Handling of missing GPS data | Not Reported; None (Complete Case); Last Observation Carried Forward; Linear Interpolation; Multiple Imputation; Other |
| `imputation_method_other`  | Details if Other | Text |

</details>

<details>
<summary><b>5. Contextual linkage and spatial scale</b></summary>

| Field | Description | Format |
|---|---|---|
| `post_processing_linkage` | Whether GPS data were linked to GIS data (including points of interest) or survey responses such as EMA | Checkbox |
| `ground_truth_tier` | Method used to validate the meaning of a location | Active (EMA Confirmation); Algorithmic (Dwell Time); GIS Buffer/Overlay; Linkage of Raw Coordinates Only; Other (multiple allowed) |
| `ground_truth_tier_notes`  | Details of ground truthing | Text |
| `poi_database` | Source of point-of-interest data linked to GPS | Official Registry; OpenStreetMap; Manual Mapping; Other; N/A |
| `poi_database_other`  | Details if Other | Text |
| `level_of_aggregation_time`  | Temporal unit over which GPS data were summarised | Text |
| `level_of_aggregation_space`  | Spatial unit over which GPS data were summarised, e.g. buffer size | Text |
| `maup_ugcop` | Whether the study acknowledges the Modifiable Areal Unit Problem or the Uncertain Geographic Context Problem | Checkbox |
| `sensitivity_maup` | Whether the study tests the sensitivity of its results to MAUP or UGCoP | Checkbox |
| `sensitivity_maup_notes`  | Details of the sensitivity analysis | Text |
| `anonymity` | Methods used to preserve anonymity, e.g. jittering | Text |

</details>

<details>
<summary><b>6. GPS features and rationale</b></summary>

| Field | Description | Format |
|---|---|---|
| `gps_features` | Features derived from GPS, e.g. entropy, time in bar, radius of gyration | Text, coded (see 10) |
| `gps_features_theoretical_rationale` | Theory cited for the features chosen, in the Introduction or Methods | Text |
| `primary_source_processing` | Primary source cited for the GPS processing method, e.g. ecology, transport science | Text |
| `tradeoff_rationale` | Authors' rationale for trade-offs in device choice and data collection, and their effect on analysis | Text, coded (see 10) |

</details>

<details>
<summary><b>7. Interventions</b></summary>

| Field | Description | Format |
|---|---|---|
| `intervention_decision_rule` | How the study decides to deliver an intervention, e.g. an if-then rule or a geofence | Text, coded (see 10) |
| `intervention_GPS_triggered`  | Content delivered when the GPS trigger fires | Text |
| `bcts_used` | Intervention options or behaviour change techniques, e.g. prompts, goal setting, feedback | Text |

</details>

<details>
<summary><b>8. Results, acceptability and open science</b></summary>

| Field | Description | Format |
|---|---|---|
| `efficacy_results` | Main intervention result | Text, coded (see 10) |
| `observational_results` | Main observational result, e.g. association between time in bars and drinking | Text, coded (see 10) |
| `acceptability` | Participant acceptability, from interviews or surveys | Text |
| `reported_barriers` | Barriers to carrying the device or sharing GPS data | Text, coded (see 10) |
| `open_data_code` | Open sharing of GPS data or code, and ethical considerations | Text |

</details>

<details>
<summary><b>9. Quality appraisal</b></summary>

`quality_appraisal` records which checklist was applied, chosen by study design. Each criterion (`quality_1` … `quality_n`) is rated Yes, No or Other; for Other, `quality_n_other` records CD (cannot determine), NA (not applicable) or NR (not reported). The checklists are the NIH (NHLBI) Study Quality Assessment Tools.

<details>
<summary>Controlled Interventions (14 criteria)</summary>

1. Described as randomised?
2. Adequate randomisation method?
3. Allocation concealed?
4. Participants and providers blinded?
5. Outcome assessors blinded?
6. Groups similar at baseline?
7. Overall drop-out ≤ 20%?
8. Differential drop-out ≤ 15 percentage points?
9. High adherence to intervention protocols?
10. Other interventions avoided or similar between groups?
11. Valid, reliable outcome measures applied consistently?
12. Sample size powered (≥ 80%) for the main outcome?
13. Outcomes and subgroups prespecified?
14. Intention-to-treat analysis?

</details>

<details>
<summary>Pre-Post (12 criteria)</summary>

1. Question or objective clearly stated?
2. Eligibility criteria prespecified and described?
3. Participants representative of the target population?
4. All eligible participants enrolled?
5. Sample size sufficient?
6. Intervention clearly described and delivered consistently?
7. Outcome measures prespecified, valid, reliable and consistent?
8. Outcome assessors blinded?
9. Loss to follow-up ≤ 20% and accounted for?
10. Statistical tests of pre-to-post change?
11. Interrupted time-series design?
12. Group-level intervention analysed appropriately?

</details>

<details>
<summary>Observational (14 criteria)</summary>

1. Research question clearly stated?
2. Study population clearly defined?
3. Participation rate ≥ 50%?
4. Participants from similar populations, with criteria applied uniformly?
5. Sample size justification given?
6. Exposure measured before outcome?
7. Timeframe sufficient to see an association?
8. Different levels of exposure examined?
9. Exposure measures valid, reliable and consistent?
10. Exposure assessed more than once?
11. Outcome measures valid, reliable and consistent?
12. Outcome assessors blinded to exposure?
13. Loss to follow-up ≤ 20%?
14. Key confounders measured and adjusted for?

</details>

</details>

<details>
<summary><b>10. Coding of free-text fields</b></summary>

Free-text fields were condensed into a `_cleaned` column and then mapped to codes using the dictionaries in `dictionaries/raw_dictionaries.rds` (applied in `R/05_data_cleaning.R`).

| Field | Codes |
|---|---|
| `gps_participant_level_cut_offs` | Participant level: all_missing_gps, consecutive_days_missing, gema_compliance_threshold, insufficient_gps, minimum_threshold, no_geofences, unspecified. Day or episode level: daily_missing_gps, episodes_missing_gps |
| `gps_features` | movement_patterns (addiction, distance, speed, variability, unspecified); place_visits (addiction, general); proximity_based_exposure (addiction, disadvantaged_neighbourhood, environmental_context, general); time_weighted_exposure (addiction, disadvantaged_neighbourhood, environmental_context, general); raw_coordinates; unspecified |
| `tradeoff_rationale` | accuracy_constraints, battery_constraints, cost, data_storage_constraints, EMA_integration, participant_burden, privacy_risk, scalability, unspecified |
| `intervention_decision_rule` | enter_location, enter_and_dwell_location, proximity_location, previous_behaviour, self_reported_risk, not_applicable, unspecified |
| `efficacy_results` | positive_effect, mixed_effect, behaviour, urges, engagement, acceptability |
| `observational_results` | positive_association, negative_association, mixed_associations, unspecified_association, indirect_effect, behaviour, craving, negative_affect, stress, descriptive, unspecified |
| `reported_barriers` | battery_constraints, covid_context, data_quality, gps_accuracy, missing_data, participant_burden, privacy_concerns, sampling_limitations, technical_issues, unspecified |

</details>

## Setup & Dependencies

### Prerequisites
* R (v4.0+)
* A Google Account with access to the Shared Drive.

### Installation
1.  Clone this repository.
2.  Open `GPS-Addiction-Review.Rproj`.
3.  Install dependencies:
    ```r
    install.packages(c("tidyverse", "terra", "litsearchr", "googledrive", "googlesheets4"))
    ```

### Authentication
This project uses the `googledrive` package. On first run of any Phase B script, you will be asked to authenticate in your browser. A local token will be cached in `.secrets/` (which is git-ignored).

## License
MIT License
