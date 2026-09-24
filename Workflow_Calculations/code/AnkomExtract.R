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

ankom_path <- function(dry_treat) {
  file.path(data_root, "ChemResults",
            sprintf("Ankom_Primary_Template_Zach_Mill%s.xlsx", dry_treat))
}

# --- derive the fiber fractions from the raw weights ------------------------
# These workbooks report each fraction as a spreadsheet formula over the
# typed-in weights. We do NOT read those reported columns as the deposit
# value, because the arithmetic itself turned out to be unreliable: two rows
# of the FF sheet had formulas whose relative cell references had slipped by
# one row, so they read a neighbouring sample's weight (found 2026-09-24 --
# see the mismatch report this script writes). The values those formulas
# produced were entirely plausible, so nothing but recomputation could catch
# it.
#
# Recomputed here straight from the protocol, which is the authority for this
# assay and is where the template's own formulas came from:
#   Hobbie_Ankom_Protocol_Frye_edited2025.docx (Frye, the lab's ANKOM
#   implementation lead), sections "Calculations" under NDF / ADF / ADL.
#
#   blank bag correction  C_step = blank bag wt. after step / blank bag tare
#   % left after NDF      = (wt_NDF - tare * C_NDF) * 100 / sample wt.
#   % hemicellulose       = ((wt_NDF - tare * C_NDF)
#                            - (wt_ADF - tare * C_ADF)) * 100 / sample wt.
#   % left after ADF      = (wt_ADF - tare * C_ADF) * 100 / sample wt.
#   % cellulose           = ((wt_ADF - tare * C_ADF)
#                            - (wt_ADL - tare * C_ADL)) * 100 / sample wt.
#   % lignin+recalcitrant = (wt_ADL - tare * C_ADL) * 100 / sample wt.
#
# Each batch of 24 carries one empty blank bag, whose weight after each wash
# gives that batch's correction factor (protocol step 4).
read_ankom_sheet <- function(dry_treat) {
  raw <- read_excel(ankom_path(dry_treat))

  blank <- raw %>% filter(str_detect(str_to_upper(SampleID), "BLANK"))
  stopifnot(nrow(blank) == 1)

  c_ndf <- as.double(blank$Weigth_After_NDF) / as.double(blank$BagTare)
  c_adf <- as.double(blank$Weight_After_ADF) / as.double(blank$BagTare)
  c_adl <- as.double(blank$Weight_After_ADL) / as.double(blank$BagTare)

  raw %>%
    filter(!str_detect(str_to_upper(SampleID), "BLANK"), !is.na(SampleID)) %>%
    transmute(
      Sample_ID     = SampleID,
      dry_treatment = dry_treat,
      tare          = as.double(BagTare),
      sample_wt     = as.double(SampleWt),
      # residue remaining after each wash, blank-corrected
      resid_ndf     = as.double(Weigth_After_NDF) - tare * c_ndf,
      resid_adf     = as.double(Weight_After_ADF) - tare * c_adf,
      resid_adl     = as.double(Weight_After_ADL) - tare * c_adl,
      # the three reported fractions, as % of sample dry mass -> mg/g
      hemicellulose_mg_g = (resid_ndf - resid_adf) * 100 / sample_wt * 10,
      cellulose_mg_g     = (resid_adf - resid_adl) * 100 / sample_wt * 10,
      lignin_recal_mg_g  = resid_adl * 100 / sample_wt * 10,
      # what the workbook itself reports, kept only to check against
      sheet_hemicellulose_mg_g = as.double(Perc_Hemiceullose) * 10,
      sheet_cellulose_mg_g     = as.double(Percent_Cellulose) * 10,
      sheet_lignin_recal_mg_g  = as.double(Percent_Lignin_recalcitrants) * 10
    )
}

ankom_all <- bind_rows(
  read_ankom_sheet("FF"),
  read_ankom_sheet("OD")
)

# --- reported vs. recomputed, written out for the QC step to check ----------
# Both numbers claim to be the same function of the same weights, so any
# disagreement is a defect in the workbook. The comparison itself belongs in
# the QC run (TraitSpectralQC.R, via enspec-qc's qc_derived_mismatch()), so
# that a bad formula shows up in the deposit's QC report alongside every other
# flag rather than only as a warning here. This script's job is to put both
# numbers side by side.
reported_vs_recomputed <- ankom_all %>%
  pivot_longer(
    cols = starts_with("sheet_"),
    names_to = "trait", names_prefix = "sheet_", values_to = "sheet_value"
  ) %>%
  mutate(recomputed = case_when(
    trait == "hemicellulose_mg_g" ~ hemicellulose_mg_g,
    trait == "cellulose_mg_g"     ~ cellulose_mg_g,
    trait == "lignin_recal_mg_g"  ~ lignin_recal_mg_g
  )) %>%
  transmute(Sample_ID, dry_treatment, trait, sheet_value, recomputed)

write.csv(reported_vs_recomputed,
          file.path(out_dir, "ankom_reported_vs_recomputed.csv"), row.names = FALSE)

cat(sprintf("Wrote %d reported-vs-recomputed comparisons to %s\n",
            nrow(reported_vs_recomputed),
            file.path(out_dir, "ankom_reported_vs_recomputed.csv")))

# Recomputed values are the ones that go forward: they follow the protocol
# directly and cannot inherit a shifted cell reference from the workbook.
ankom_mill_test <- ankom_all %>%
  select(Sample_ID, dry_treatment,
         hemicellulose_mg_g, cellulose_mg_g, lignin_recal_mg_g)

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
