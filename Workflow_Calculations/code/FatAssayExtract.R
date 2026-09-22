##################################################
#
# Title: Fat Assay Extract
#
# Project: Mill Test 2024
#
# Purpose: Pull the Mill Test rows out of the shared fat-assay-development
# workbook for the EcoSIS deposit. `Defat_test_samples.xlsx` was a method
# validation exercise that ran the same defatting/oil-extraction protocol on
# samples from two unrelated projects side by side in the same sheets -- 8
# MILL24_* samples here, 8 SHIFT-project samples (identified only by a bare
# numeric sample number, cross-referenced against that workbook's own
# "Samples" sheet, which is entirely SHIFT-project metadata). The raw file
# can't go into this deposit as-is without leaking the other project's
# sample data into this DOI. This script filters to just the Mill Test rows.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
fat_assay_path <- Sys.getenv(
  "MILL24_FAT_ASSAY_XLSX",
  unset = "/Volumes/Enspec/projects/fat_assay_development/raw_data/Defat_test_samples.xlsx"
)

out_dir <- file.path(data_root, "derived", "fat_assay")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- extract Mill Test rows only --------------------------------------------

read_mill_sheet <- function(sheet, dry_treat) {
  read_excel(fat_assay_path, sheet = sheet) %>%
    rename(Sample_ID = `Sample Number`) %>%
    mutate(Sample_ID = as.character(Sample_ID)) %>%
    filter(str_starts(Sample_ID, "MILL24_")) %>%
    transmute(
      Sample_ID         = Sample_ID,
      dry_treatment     = dry_treat,
      sample_weight_mg  = `Sample Weight (mg)`,
      oil_mass_mg       = `Oil Mass (mg)`,
      # % oil by mass -> mg/g, for unit consistency with the rest of the
      # deposit's chemistry values
      oil_content_mg_g  = `% Oil Content` * 10
    )
}

fat_assay <- bind_rows(
  read_mill_sheet("FF Results", "FF"),
  read_mill_sheet("OD Results", "OD")
)

write.csv(fat_assay, file.path(out_dir, "fat_assay_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples) to %s\n",
           nrow(fat_assay), n_distinct(fat_assay$Sample_ID),
           file.path(out_dir, "fat_assay_mill_test.csv")))
cat("Excluded the workbook's other rows: unrelated SHIFT-project samples in FF/OD Results, and the entire 'Samples' sheet.\n")
