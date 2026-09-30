##################################################
#
# Title: TPC Extract
#
# Project: Mill Test 2024
#
# Purpose: Combine and clean Mill Test's total phenolic content (TPC) data
# for the EcoSIS deposit. It comes in two batches, in two different
# locations, confirmed 2026-09-17:
#  1. A broadleaf-heavy batch, `ChemResults/Mill Test_{FF,OD}_TPC.xlsx` --
#     a Code/Plant.ID triplicate-QC format (a "TPC Final" sheet of GAE
#     results keyed by an opaque Code, joined against a "Samples" sheet
#     mapping Code -> a free-text Plant.ID). Parsing logic here matches
#     chemistry-sample-handling/code/chemistry_comparison_results.R, which
#     reads these same two files for a different (treatment-comparison)
#     analysis. This batch was run by Erin A. Pierce and Cole Willems.
#  2. A needle-leaved-conifer batch (samples 035-066), which was run later
#     and lives ONLY in chemistry-sample-handling's raw_chem_inputs --
#     never copied into Mill24 at all. Simpler shape: one "TPC clean" sheet
#     per treatment, `Label` IS the sample number directly, no separate
#     metadata sheet needed. This batch was run by Ethan Kanski and 
#     Gabriela Donnangelo.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
chem_sample_handling_root <- Sys.getenv(
  "CHEM_SAMPLE_HANDLING_DATA_ROOT",
  unset = "/Volumes/Enspec/projects/chemistry_sample_handling"
)

out_dir <- file.path(data_root, "derived", "tpc")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- batch 1: broadleaf-heavy, Code/Plant.ID triplicate-QC format ----------
# Codes MFF1-7 / MIL1-7 are calibration standards and triplicate QC re-runs,
# not distinct samples -- excluded via the same non_triplicates filter
# chemistry-sample-handling uses (Code %in% paste0(prefix, 8:37)).

read_broadleaf_tpc <- function(dry_treat, code_prefix) {
  path <- file.path(data_root, "ChemResults", sprintf("Mill Test_%s_TPC.xlsx", dry_treat))

  final <- read_excel(path, sheet = "TPC Final") %>%
    select(Code, MeanGAE = `Mean GAE (mg/g)`, SD)
  meta <- read_excel(path, sheet = "Samples") %>%
    select(Code, Plant_ID = `Plant ID`)

  non_triplicates <- paste0(code_prefix, 8:37)

  left_join(final, meta, by = "Code") %>%
    filter(!is.na(Code), Code %in% non_triplicates) %>%
    mutate(
      Plant_IDNum   = str_extract(Plant_ID, "\\d{3}$"),
      Sample_ID     = paste0("MILL24_0", Plant_IDNum),
      dry_treatment = dry_treat
    ) %>%
    select(Sample_ID, dry_treatment, phenolics_mg_g = MeanGAE, phenolics_sd = SD)
}

broadleaf_tpc <- bind_rows(
  read_broadleaf_tpc("FF", "MFF"),
  read_broadleaf_tpc("OD", "MIL")
)

# --- batch 2: needle-leaved conifers (samples 035-066), Label = sample num --

read_conifer_tpc <- function(file, dry_treat) {
  path <- file.path(chem_sample_handling_root, "raw_chem_inputs", file)
  read_excel(path, sheet = "TPC clean") %>%
    filter(!is.na(Label)) %>%
    transmute(
      Sample_ID     = sprintf("MILL24_%04d", as.integer(Label)),
      dry_treatment = dry_treat,
      phenolics_mg_g = `GAE (mg/g)`,
      phenolics_sd   = SD
    )
}

conifer_tpc <- bind_rows(
  read_conifer_tpc("08042026-FF BALL_GAE.xlsx", "FF"),
  read_conifer_tpc("07302026 - OD BALL_GAE.xlsx", "OD")
)

# --- combine + write ---------------------------------------------------------

tpc_mill_test <- bind_rows(broadleaf_tpc, conifer_tpc) %>%
  arrange(Sample_ID, dry_treatment)

dup_check <- tpc_mill_test %>% count(Sample_ID, dry_treatment) %>% filter(n > 1)
if (nrow(dup_check) > 0) {
  cat("WARNING: overlapping samples between the two TPC batches:\n")
  print(dup_check)
}

write.csv(tpc_mill_test, file.path(out_dir, "tpc_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples: %d broadleaf batch + %d conifer batch) to %s\n",
           nrow(tpc_mill_test), n_distinct(tpc_mill_test$Sample_ID),
           n_distinct(broadleaf_tpc$Sample_ID), n_distinct(conifer_tpc$Sample_ID),
           file.path(out_dir, "tpc_mill_test.csv")))
