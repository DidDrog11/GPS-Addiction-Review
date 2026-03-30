# read in data from google drive

gs4_auth()

# for flow chart

df0 <- read_sheet("https://docs.google.com/spreadsheets/d/1k1JifoWc7inDVYLh558CKdO5aZApSBlSL2VDiAnYf8Q/edit?gid=0#gid=0")

# main extraction sheets

df1 <- read_sheet("https://docs.google.com/spreadsheets/d/1Qczi3KtAgCIcSWKmEm6tOqCBO0hUHxmlhUXBiCTkcxQ/edit?gid=2016267919#gid=2016267919")
df2 <- read_sheet("https://docs.google.com/spreadsheets/d/1NXWH9WJAKAZ6TtDWxxju2Jk_1xBb017P70X4Xzg9mWk/edit?gid=2016267919#gid=2016267919")

df_combined <- rbind(df1, df2)

# quality appraisal - observational

# quality appraisal - prepost

# quality appraisal - experimental
