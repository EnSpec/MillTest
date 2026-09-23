##################################################
#
# Title: Ankom Extract
#
# Project: Mill Test 2024
#
# Purpose: Clean the ANKOM fiber assay (hemicellulose/cellulose/recalcitrant
# lignin) workbooks for the EcoSIS deposit. Unlike the fat assay and isotope
# workbooks, these two files are clean Mill-Test-only data (verified
# 2026-09-17: all SampleIDs are MILL24_* or the BLANK QC row, no other
# project mixed in) -- this is a units conversion + tidy pass, not a
# project-filtering one. Cleaning logic (percent -> mg/g conversion, dropping
# the BLANK row) matches the parsing already tested in
# chemistry-sample-handling/code/chemistry_comparison_results.R, which reads
# these same two files for that project's own (different) analysis.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "ankom")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

read_ankom_sheet <- function(dry_treat) {
  path <- file.path(data_root, "ChemResults",
                    sprintf("Ankom_Primary_Template_Zach_Mill%s.xlsx", dry_treat))
  read_excel(path) %>%
    filter(SampleID != "BLANK", !is.na(SampleID)) %>%
    transmute(
      Sample_ID           = SampleID,
      dry_treatment       = dry_treat,
      hemicellulose_mg_g  = as.double(Perc_Hemiceullose) * 10,
      cellulose_mg_g      = as.double(Percent_Cellulose) * 10,
      lignin_recal_mg_g   = as.double(Percent_Lignin_recalcitrants) * 10
    )
}

ankom_mill_test <- bind_rows(
  read_ankom_sheet("FF"),
  read_ankom_sheet("OD")
)

write.csv(ankom_mill_test, file.path(out_dir, "ankom_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique Mill Test samples) to %s\n",
           nrow(ankom_mill_test), n_distinct(ankom_mill_test$Sample_ID),
           file.path(out_dir, "ankom_mill_test.csv")))

# --- blank bags: keep them, they are the batch's QC control -----------------
# The BLANK row is an empty bag carried through the same NDF -> ADF -> ADL
# wash sequence as the batch's real samples. It should only ever LOSE weight;
# a gain means the bag leaked and took on material, which means it was
# shedding sample material too and every sample in that batch is suspect
# (Henry, 2026-09-23 -- ~1% gain is a threshold in common use elsewhere).
# Filtering these out and keeping only the sample rows threw away the one
# piece of batch-level quality information these workbooks carry.
read_ankom_blanks <- function(dry_treat) {
  path <- file.path(data_root, "ChemResults",
                    sprintf("Ankom_Primary_Template_Zach_Mill%s.xlsx", dry_treat))
  read_excel(path) %>%
    filter(str_detect(str_to_upper(SampleID), "BLANK")) %>%
    transmute(
      batch              = dry_treat,
      dry_treatment      = dry_treat,
      bag_number         = as.character(Bag_Number),
      bag_tare_g         = as.double(BagTare),
      weight_after_ndf_g = as.double(Weigth_After_NDF),
      weight_after_adf_g = as.double(Weight_After_ADF),
      weight_after_adl_g = as.double(Weight_After_ADL)
    )
}

ankom_blanks <- bind_rows(read_ankom_blanks("FF"), read_ankom_blanks("OD"))

write.csv(ankom_blanks, file.path(out_dir, "ankom_blanks_mill_test.csv"), row.names = FALSE)

cat(sprintf("Wrote %d blank-bag rows to %s\n", nrow(ankom_blanks),
           file.path(out_dir, "ankom_blanks_mill_test.csv")))
