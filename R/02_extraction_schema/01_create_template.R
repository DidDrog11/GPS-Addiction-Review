# -------------------------------------------------------------------------
# Script: 01_create_template.R
# Purpose: Create the Master Data Extraction Template in Google Drive
# -------------------------------------------------------------------------

source(here::here("R", "00_setup.R"))

# 1. Define the Schema (The Columns)
# -------------------------------------------------------------------------
# We define columns and their 'Type' (Text, Dropdown, Checkbox)
# This helps us format the sheet later.

schema <- tribble(
  ~Column, ~Type, ~Options,
  "Study_ID", "Locked", NA,
  "Reviewer_Name", "Text", NA,
  "Extraction_Date", "Date", NA,
  
  # --- STUDY CHARACTERISTICS ---
  "Study_Design", "Dropdown", "Observational (Cross-sectional), Observational (Longitudinal/Cohort), Experimental (RCT), Experimental (Quasi/Natural), Qualitative, Review/Meta-analysis",
  "Target_Population", "Dropdown", "Adults (18+), Adolescents (12-17), Mixed, Other",
  "Addiction_Type", "Dropdown", "Alcohol, Tobacco/Nicotine, Cannabis, Opioids, Gambling, Polysubstance, Other",
  "Sample_Size", "Numeric", NA,
  
  # --- GPS METHODOLOGY (The Core) ---
  "Device_Type", "Dropdown", "Smartphone (Own), Smartphone (Study Provisioned), Dedicated GPS Logger, Wearable (Smartwatch), Other",
  "Sampling_Frequency", "Text", NA, 
  "Ground_Truthing_Method", "Dropdown", "Tier A: Active Confirmation (EMA), Tier B: Algorithmic Inference (Dwell/Speed), Tier C: Database Linkage (GIS Overlay), Tier D: None/Raw Coordinates",
  "POI_Database_Source", "Dropdown", "Google Places, OpenStreetMap, Foursquare, Government Registry, Manual Mapping, N/A",
  "Privacy_Method", "Dropdown", "None Reported, Obfuscation/Blurring, Aggregation, Encryption Only, Other",
  
  # --- ANALYSIS ---
  "GPS_Features_Extracted", "Text", NA, # e.g. Entropy, Radius of Gyration
  "Analytical_Approach", "Text", NA,
  "Key_Findings", "Text", NA,
  
  # --- QUALITY & RISK ---
  "Reported_Missing_Data", "Dropdown", "Yes, No",
  "Missing_Data_Handling", "Text", NA,
  "Battery_Drain_Mentioned", "Dropdown", "Yes, No",
  "MAUP_Acknowledged", "Dropdown", "Yes, No"
)

# 2. Create the Template Dataframe
# -------------------------------------------------------------------------
# Create an empty dataframe with these column names
template_df <- setNames(data.frame(matrix(ncol = nrow(schema), nrow = 0)), schema$Column)

# 3. Upload to Google Drive
# -------------------------------------------------------------------------
# Find the project root again (safely)
root <- drive_find(pattern = "GPS_Addiction_Systematic_Review", type = "folder", n_max = 1)
admin_folder <- drive_find(pattern = "99_Admin", type = "folder", path = root)

# Write the sheet
ss <- gs4_create(
  name = "MASTER_EXTRACTION_TEMPLATE",
  sheets = list(Extraction_Form = template_df)
)

# Move it to the Admin folder
drive_mv(ss, path = admin_folder)

# 4. Apply Formatting (The "Hack" for Dropdowns)
# -------------------------------------------------------------------------
# googlesheets4 cannot natively add Data Validation rules yet.
# However, we can add a second sheet called "Dropdown_Options" to store the lists,
# and then you (the human) can manually set the Data Validation rules in the GUI once.
# This is safer than trying to hack the API via R.

# Create a dataframe of options
options_list <- schema |>
  filter(Type == "Dropdown") |>
  select(Column, Options) |>
  separate_rows(Options, sep = ", ")

# Add this sheet to the workbook
sheet_write(options_list, ss, sheet = "Dropdown_Options")

message("Template created successfully!")
message("URL: ", gs4_browse(ss))
message("\nACTION REQUIRED: Open the sheet and manually set Data Validation rules using the 'Dropdown_Options' tab.")