##################################################
#
# Title: Leaf Area Extract
#
# Project: Mill Test 2024
#
# Purpose: Pull the per-sample leaf area (from scanned leaf images) used to
# compute leaf mass per area (LMA = dry mass / leaf area) for the EcoSIS
# deposit. `field_data/Mill24_LMA.xlsx` has two sheets: "Sheet2" is the raw
# per-scan breakdown (some samples' leaf material was split across multiple
# scans, e.g. "MILL24_0022_1OF3"/"_2OF3"/"_3OF3"); "Sheet1" is already the
# one-row-per-sample total (confirmed 2026-09-17: Sheet1's single
# "MILL24_0022_" row equals the sum of Sheet2's three sub-scans for that
# sample) -- read from Sheet1 directly rather than re-deriving the sum.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "leaf_area")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

leaf_area_mill_test <- read_excel(
  file.path(data_root, "field_data", "Mill24_LMA.xlsx"), sheet = "Sheet1"
) %>%
  transmute(
    Sample_ID     = str_extract(sampleID, "^MILL24_\\d{4}"),
    leaf_area_cm2 = `area_cm^2`
  )

write.csv(leaf_area_mill_test, file.path(out_dir, "leaf_area_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples) to %s\n",
           nrow(leaf_area_mill_test), n_distinct(leaf_area_mill_test$Sample_ID),
           file.path(out_dir, "leaf_area_mill_test.csv")))
