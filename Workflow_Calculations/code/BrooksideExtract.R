##################################################
#
# Title: Brookside Extract
#
# Project: Mill Test 2024
#
# Purpose: Pull the Mill Test rows out of the shared Brookside Labs
# submission log for the EcoSIS deposit, and convert everything to a
# consistent mg/g unit. `ChemResults/Brookside.csv` is NOT a Mill Test file
# in origin -- confirmed 2026-09-17: it's a running multi-project lab
# submission log (BIOSCAPE, ABOVE, MONGOLIA, LSNP24, LNG24, and others all
# appear in the same Sample_ID column, several repeated hundreds of times as
# a bulk project label rather than a real per-sample ID). Only the 60 rows
# whose Sample_ID starts "MILL24_" are this project's. `ChemistryAnalysis.R`
# already reads this same file for the manuscript's own N/Ca RMSE analysis,
# but only keeps Nitrogen/Calcium and doesn't filter by project (it happens
# to work there only because a left_join + `filter(!is.na(...))` silently
# drops all the non-Mill_Test/non-numeric rows downstream) -- this script is
# the first place that filters explicitly and reports the full element
# panel, for the EcoSIS deposit specifically.
#
# One assay per sample (oven-dried, 20-mesh material only, per the
# manuscript's methods) -- not per drying/milling treatment. This matches
# ChemistryAnalysis.R's own treatment of this file: the single Brookside
# value per sample is the shared ground truth every treatment's spectrally
# predicted value gets compared against, not itself specific to one
# treatment's material.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "brookside")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Brookside.csv carries a UTF-8 BOM on the first header cell; without
# fileEncoding the first column name is mangled and filter()/select() fail.
brookside_raw <- read.csv(file.path(data_root, "ChemResults", "Brookside.csv"),
                          fileEncoding = "UTF-8-BOM")

# Below-detection values are reported as e.g. "< 10.0" -- floored to half the
# detection limit, matching the convention already used for this exact lab's
# reports elsewhere (WisTraits/Code/hytraits_data_create.R's clean_lt_values).
clean_lt_values <- function(x) {
  case_when(
    str_detect(x, "<") ~ as.numeric(str_extract(x, "[0-9.]+")) / 2,
    TRUE ~ as.numeric(x)
  )
}

brookside_mill_test <- brookside_raw %>%
  filter(str_starts(Sample_ID, "MILL24_")) %>%
  transmute(
    Sample_ID,
    # macronutrients reported as % dry mass -> mg/g
    nitrogen_mg_g   = clean_lt_values(Nitrogen)    * 10,
    phosphorus_mg_g = clean_lt_values(Phosphorous) * 10,
    magnesium_mg_g  = clean_lt_values(Magnesium)   * 10,
    potassium_mg_g  = clean_lt_values(Potassium)   * 10,
    calcium_mg_g    = clean_lt_values(Calcium)     * 10,
    sulfur_mg_g     = clean_lt_values(Sulfur)      * 10,
    # micronutrients reported as ppm -> mg/g (confirmed by value range --
    # e.g. Boron/Iron/Manganese aren't labeled "(ppm)" in the header like
    # Copper/Zinc/Aluminum/Sodium are, but their values are only sane as ppm)
    boron_mg_g      = clean_lt_values(Boron)          / 1000,
    iron_mg_g       = clean_lt_values(Iron)           / 1000,
    manganese_mg_g  = clean_lt_values(Manganese)      / 1000,
    copper_mg_g     = clean_lt_values(Copper..ppm.)   / 1000,
    zinc_mg_g       = clean_lt_values(Zinc..ppm.)     / 1000,
    aluminum_mg_g   = clean_lt_values(Aluminum..ppm.) / 1000,
    sodium_mg_g     = clean_lt_values(Sodium...ppm.)  / 1000
  ) %>%
  distinct()

dup_check <- brookside_mill_test %>% count(Sample_ID) %>% filter(n > 1)
if (nrow(dup_check) > 0) {
  cat("WARNING: duplicate Brookside submissions for the same Sample_ID:\n")
  print(dup_check)
}

write.csv(brookside_mill_test, file.path(out_dir, "brookside_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples) to %s\n",
           nrow(brookside_mill_test), n_distinct(brookside_mill_test$Sample_ID),
           file.path(out_dir, "brookside_mill_test.csv")))
cat("Excluded the log's other rows: BIOSCAPE, ABOVE, MONGOLIA, LSNP24, LNG24, and other unrelated project submissions.\n")
