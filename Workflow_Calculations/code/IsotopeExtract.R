##################################################
#
# Title: Isotope Extract
#
# Project: Mill Test 2024
#
# Purpose: Pull the Mill Test rows out of the shared isotope report for the
# EcoSIS deposit. `Report - 13C15N - BIOCORE_05.26.26.xlsx` is not a Mill
# Test file in origin -- its own metadata block says Study = "BIOCORE", and
# only its "Run2" sheets contain Mill Test rows (11 samples x FF/OD = 22
# rows), mixed in among ~60 unrelated Biocore Tree samples run in the same
# batch (confirmed 2026-09-17). Per chemistry-sample-handling/CLAUDE.md,
# this isotope comparison is itself a small side-check for that project's
# samples, not manuscript-scope analysis for either project -- the raw file
# can't go into this deposit as-is without leaking Biocore Tree sample data.
# This script filters to just the Mill Test rows.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
isotope_path <- Sys.getenv(
  "MILL24_ISOTOPE_XLSX",
  unset = file.path(data_root, "ChemResults", "Report - 13C15N - BIOCORE_05.26.26.xlsx")
)

out_dir <- file.path(data_root, "derived", "isotope")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- delta values (per-mille C/N isotope ratios) ----------------------------
# Header row (row 9 in the sheet) has awkward unicode column names -- supply
# our own via col_names + skip, same approach as SpectralMeasurementMetadata.R.
# Sheet name itself uses delta/permille unicode characters that don't survive
# this R installation's locale reliably -- addressed by sheet position
# (4 sheets total: delta Run1, Weight% Run1, delta Run2, Weight% Run2) instead
# of by name.

delta <- read_excel(
  isotope_path, sheet = 3, skip = 9,
  col_names = c("Sample", "sample_start_time", "d13C_measured", "d13C_scale_adj",
               "d15N_measured", "d15N_scale_adj", paste0("c", 7:8))
) %>%
  filter(str_starts(Sample, "MILL24_")) %>%
  separate_wider_delim(Sample, delim = "_", names = c("Mill", "SampleNum", "DryTreat"),
                       cols_remove = FALSE) %>%
  transmute(
    Sample_ID     = paste(Mill, SampleNum, sep = "_"),
    dry_treatment = DryTreat,
    d13C          = d13C_scale_adj,
    d15N          = d15N_scale_adj
  )

# --- weight %C / %N ----------------------------------------------------------

weight_pct <- read_excel(
  isotope_path, sheet = 4, skip = 9,
  col_names = c("Sample", "weight_amount_mg", "measured_C_pct", "measured_N_pct")
) %>%
  filter(str_starts(Sample, "MILL24_")) %>%
  separate_wider_delim(Sample, delim = "_", names = c("Mill", "SampleNum", "DryTreat"),
                       cols_remove = FALSE) %>%
  transmute(
    Sample_ID          = paste(Mill, SampleNum, sep = "_"),
    dry_treatment      = DryTreat,
    # weight % -> mg/g, for unit consistency with the rest of the deposit's
    # chemistry values. "IRMS" in the nitrogen name distinguishes this
    # elemental-analyzer/IRMS-derived %N from Brookside's separate
    # combustion-based nitrogen_mg_g elemental-panel value.
    carbon_mg_g        = as.numeric(measured_C_pct) * 10,
    nitrogen_IRMS_mg_g = as.numeric(measured_N_pct) * 10
  )

# --- join + write ------------------------------------------------------------

isotope_mill_test <- delta %>%
  full_join(weight_pct, by = c("Sample_ID", "dry_treatment"))

write.csv(isotope_mill_test, file.path(out_dir, "isotope_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples) to %s\n",
           nrow(isotope_mill_test), n_distinct(isotope_mill_test$Sample_ID),
           file.path(out_dir, "isotope_mill_test.csv")))
cat("Excluded the workbook's other rows: Run1 (predates Mill Test samples), calibration standards/blanks, and ~60 unrelated Biocore Tree samples in Run2.\n")
