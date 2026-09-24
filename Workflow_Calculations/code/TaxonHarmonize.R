##################################################
#
# Title: Taxon Harmonization
#
# Project: Mill Test 2024
#
# Purpose: Resolve this project's species names against the World Flora Online
# taxonomic backbone, so the EcoSIS deposit carries scientific authority
# (accepted name, authorship, family, nomenclatural status) rather than only
# the hand-entered common/scientific names from the field sheet.
#
# Why this runs on a 14-species dataset, where harmonization looks like
# overkill (Henry, 2026-09-24): checking is the point. A deposit that states
# its names were verified against WFO -- and says which version -- is making a
# checkable claim, and 14 names is small enough for a human to review every
# result. Hand-entered names in this file are not guaranteed to be accepted
# names: `Phytolacca decandra` is a case in point.
#
# Runs BEFORE TraitSpectralQC.R (the QC grouping variable is taxon), and after
# EcoSISMetadataSidecar.R, whose output it annotates.
#
# Uses the shared checks in enspec-qc (github.com/EnSpec/enspec-qc):
# set ENSPEC_QC_PATH, or clone it next to this repo.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)

qc_lib_path <- Sys.getenv("ENSPEC_QC_PATH",
                          unset = file.path(dirname(getwd()), "enspec-qc"))
if (!dir.exists(qc_lib_path)) {
  stop("Cannot find enspec-qc. Set ENSPEC_QC_PATH to its location.")
}
source(file.path(qc_lib_path, "R", "taxon_harmonize.R"))
source(file.path(qc_lib_path, "R", "wfo_backbone.R"))
source(file.path(qc_lib_path, "R", "qc_report.R"))

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
out_dir <- file.path(data_root, "derived", "taxonomy")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- config ----------------------------------------------------------------

# The WFO static backbone. Not in any repo (~950 MB). Latest at
# https://www.worldfloraonline.org/downloadData
wfo_backbone_path <- Sys.getenv(
  "WFO_BACKBONE",
  unset = "/Volumes/Enspec/users/henry/WFO_backbones/classification_v.2026.6.csv")

# The newest WFO release we know to exist. WFO publishes no machine-readable
# version index, so this is human-maintained: bump it when someone checks the
# download page, and the currency check becomes exact instead of age-based.
# Last confirmed: nobody yet -- left NULL so the check reports its own
# uncertainty rather than implying the backbone was verified.
wfo_latest_known <- NULL

# Botanist/reviewer-verified corrections. Empty for this project: all 14 names
# resolved without intervention (see the log this script writes). Kept as a
# declared, empty table rather than omitted, so the next person can see that
# overrides are the supported mechanism and that none were needed here.
taxon_overrides <- tibble::tibble(
  from = character(0), to = character(0), reason = character(0)
)

# --- inputs ----------------------------------------------------------------

sidecar_path <- file.path(data_root, "derived", "ecosis",
                          "spectral_metadata_sidecar.csv")
sidecar <- read.csv(sidecar_path)

# `species` here reads like "Sugar Maple (Acer saccharum)" -- a common name
# with the scientific name parenthesized. Pulling the binomial out is
# project-specific parsing, so it lives here rather than in the shared library.
species_table <- sidecar %>%
  distinct(species_code, species) %>%
  mutate(
    common_name = str_trim(str_remove(species, "\\s*\\(.*\\)$")),
    name_entered = str_trim(str_extract(species, "(?<=\\()[^)]+(?=\\))"))
  )

stopifnot(!any(is.na(species_table$name_entered)))

message(sprintf("%d species codes, %d parsed scientific names",
                nrow(species_table), n_distinct(species_table$name_entered)))

# --- 1. Is the backbone current? -------------------------------------------
# Recorded either way: a harmonized name is only reproducible if the backbone
# that produced it is identifiable.
backbone <- wfo_backbone_check(wfo_backbone_path,
                               latest_known = wfo_latest_known)
qc_write_log(backbone$findings, out_dir, "wfo_backbone")

# --- 2. Normalize, then harmonize -----------------------------------------

species_table <- species_table %>%
  mutate(name_standardized = taxon_standardize_names(name_entered),
         name_to_match = taxon_strip_indet(name_standardized))

species_table <- taxon_apply_overrides(species_table, "name_to_match",
                                       taxon_overrides)

message(sprintf("Reading WFO backbone (%s) -- this takes a minute...",
                basename(wfo_backbone_path)))
# The backbone is tab-separated but its fields ARE genuinely double-quoted
# (e.g. "Schoenoxiphium ecklonii var. ecklonii"), including free-text fields
# that embed literal commas and HTML. quote = "" (disable quoting) was tried
# first and is wrong -- it leaves the surrounding quote marks as literal
# characters in every field, which silently corrupted scientificName for all
# 14 species on the first run here (caught because every name looked
# "changed" by harmonization, including ones that should not have). Default
# quote handling ('"') is correct for this file.
wfo_data <- data.table::fread(wfo_backbone_path, sep = "\t",
                              showProgress = FALSE, data.table = FALSE)
message(sprintf("  backbone: %d names", nrow(wfo_data)))

matched <- taxon_match_wfo(species_table, name_col = "name_to_match",
                           wfo_data = wfo_data,
                           keep = c("scientificName", "family",
                                    "scientificNameAuthorship",
                                    "taxonomicStatus", "taxonID"))

rm(wfo_data); invisible(gc())

# --- 3. Classify and check ------------------------------------------------

matched <- taxon_classify_recovery(matched, "scientificName", "family")

# Did harmonization change the name? For a deposit this is the interesting
# column: an entered name that is a synonym gets silently upgraded to the
# accepted one, and a reader deserves to see both.
matched <- matched %>%
  mutate(name_changed = !is.na(scientificName) &
           scientificName != name_to_match)

infra_loss <- taxon_check_infraspecific_loss(
  matched, before = "name_entered", after = "scientificName",
  id_cols = c("species_code", "name_entered"))
qc_write_log(infra_loss, out_dir, "taxon_infraspecific_loss")

taxon_table <- matched %>%
  transmute(species_code, common_name,
            name_entered,
            scientific_name_wfo = scientificName,
            scientific_name_authorship = scientificNameAuthorship,
            family_wfo = family,
            taxonomic_status_wfo = taxonomicStatus,
            wfo_taxon_id = taxonID,
            name_changed, recovery_status,
            wfo_backbone_version = backbone$version$version) %>%
  arrange(species_code)

write.csv(taxon_table, file.path(out_dir, "taxon_harmonized_mill_test.csv"),
          row.names = FALSE)

message("\n== Harmonized taxa ==")
print(as.data.frame(taxon_table %>%
  select(species_code, name_entered, scientific_name_wfo,
         taxonomic_status_wfo, name_changed)))

message(sprintf("\nrecovery: %s",
                paste(sprintf("%s=%d", names(table(taxon_table$recovery_status)),
                              table(taxon_table$recovery_status)),
                      collapse = ", ")))
message(sprintf("names changed by harmonization: %d of %d",
                sum(taxon_table$name_changed), nrow(taxon_table)))

# --- 4. Annotate the sidecar ---------------------------------------------
# Joined on species_code, which is unique in taxon_table by construction, so
# the sidecar's row count must not move. Asserted rather than assumed -- the
# GCFR pipeline lost 9,547 rows to 27,337 on exactly this kind of join.
stopifnot(!any(duplicated(taxon_table$species_code)))

sidecar_annotated <- sidecar %>%
  left_join(taxon_table %>%
              select(species_code, scientific_name_wfo,
                     scientific_name_authorship, family_wfo,
                     taxonomic_status_wfo, wfo_taxon_id,
                     wfo_backbone_version),
            by = "species_code")

stopifnot(nrow(sidecar_annotated) == nrow(sidecar))
stopifnot(!any(is.na(sidecar_annotated$scientific_name_wfo)))

write.csv(sidecar_annotated, sidecar_path, row.names = FALSE)

message(sprintf("\nSidecar updated in place: %d rows x %d columns (was %d columns)",
                nrow(sidecar_annotated), ncol(sidecar_annotated), ncol(sidecar)))
message(sprintf("Taxon table -> %s",
                file.path(out_dir, "taxon_harmonized_mill_test.csv")))
