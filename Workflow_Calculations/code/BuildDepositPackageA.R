##################################################
#
# Title: Build EcoSIS deposit Package A
#
# Project: Mill Test 2024
#
# Purpose: Assemble the EcoSIS package (spectra, per-spectrum metadata
# sidecar with QC flags, and the cleaned Mill Test chemistry and particle-size
# tables) into a single folder, check it, and write a checksum list. Package B
# (Zenodo data record: leaf scans, .asd files, regenerable intermediates,
# raw workbooks) is assembled separately. See data_manifest.md, "Deposit
# layout".
#
# Everything is copied from outputs of the pipeline; nothing is edited here
# except the spectra table, which is reformatted (see below). Run after the
# whole README run order, including TraitSpectralQC.R and QCReviewPlots.R,
# from the repo root:
#   Rscript Workflow_Calculations/code/BuildDepositPackageA.R
#
# Not shipped in either package, on purpose: the raw isotope report, the
# fat-assay workbook and ChemResults/Brookside.csv. Each is a log shared with
# other projects and contains unrelated samples; the cleaned Mill Test
# extracts (chemistry/) replace them.
#
# Author: Henry Frye (with Claude Code), 2026-10-19
#
##################################################

library(tidyverse)
library(data.table)

data_root <- Sys.getenv("MILL24_DATA_ROOT", unset = "/Volumes/Enspec/projects/Mill24")
pkg <- file.path(data_root, "deposit", "package_A")
readme_src <- file.path(data_root, "derived", "README_package_A_ecosis.txt")
stopifnot("README source missing" = file.exists(readme_src))

# Rebuild from scratch so a stale file from an earlier build cannot ship.
unlink(pkg, recursive = TRUE)
dir.create(pkg, recursive = TRUE)

put <- function(from, to_dir, rename = NULL) {
  stopifnot(file.exists(from))
  dir.create(file.path(pkg, to_dir), recursive = TRUE, showWarnings = FALSE)
  ok <- file.copy(from, file.path(pkg, to_dir, rename %||% basename(from)))
  stopifnot(ok)
}
`%||%` <- function(a, b) if (is.null(a)) b else a
d <- function(...) file.path(data_root, ...)

# --- 1. spectra --------------------------------------------------------------
# The deduplicated, jump-corrected spectra (2376 unique scans; one row per
# sidecar row). Mill24_RawSpec.csv is NOT shipped: it carries 18 extra rows,
# the earlier scans of three re-scanned replicate sets (0034 FF_SIXT, 0037
# FF_BALL, 0059 FF_BALL), and the two files agree to 1.5e-7 on every kept scan
# (checked 2026-10-19 against the later scan of each duplicate). Column 1 is
# renamed `spectra` to match the sidecar key; wavelength headers drop the R
# "X" prefix (bare nm, as in the original Mill24_RawSpec.csv). Values are
# written to 7 decimal places.
spec <- fread(d("spectralpredictr", "SpectralPredictR_raw_spectra.csv"))
setnames(spec, 1, "spectra")
wl <- sub("^X", "", names(spec)[-1])
stopifnot("wavelength columns are not 350..2500 nm in 1 nm steps" = identical(as.numeric(wl), as.numeric(350:2500)))
setnames(spec, names(spec)[-1], wl)
num_cols <- names(spec)[-1]
spec[, (num_cols) := lapply(.SD, round, digits = 7), .SDcols = num_cols]
dir.create(pkg, showWarnings = FALSE)
fwrite(spec, file.path(pkg, "Mill24_spectra_jumpcorrected.csv"))

# --- 2. sidecar and QC ---------------------------------------------------------
put(d("derived", "ecosis", "spectral_metadata_sidecar.csv"), ".")
put(d("derived", "qc", "spectral_metadata_sidecar_with_qc_flags.csv"), ".")
qc_files <- list.files(d("derived", "qc"), full.names = TRUE)
qc_files <- qc_files[basename(qc_files) != "spectral_metadata_sidecar_with_qc_flags.csv"]  # shipped at top level
for (f in qc_files) put(f, "qc")
put(d("derived", "qc_review", "qc_review_decisions.csv"), "qc")

# --- 3. predicted traits ---------------------------------------------------------
put(d("spectralpredictr", "DimensionsDryTraitPredictions.csv"), "predicted_traits")

# --- 4. field data -----------------------------------------------------------------
put(d("field_data", "sample_info.csv"), "field_data")
put(d("derived", "field", "sample_coordinates.csv"), "field_data")
put(d("derived", "field", "cross_project_sample_links.csv"), "field_data")
for (f in list.files(d("field_data", "raw_coordinates"), full.names = TRUE)) put(f, file.path("field_data", "raw_coordinates"))

# --- 5. particle size -----------------------------------------------------------------
put(d("derived", "particle_size", "particle_size_per_sample.csv"), "particle_size")
put(d("derived", "particle_size", "particle_size_summary.csv"), "particle_size")
for (f in list.files(d("particle_size", "data", "full"), pattern = "\\.csv$", recursive = TRUE, full.names = TRUE))
  put(f, file.path("particle_size", "raw_exports"))
for (f in list.files(d("particle_size", "data", "distribution", "Jun13"), pattern = "\\.csv$", full.names = TRUE))
  put(f, file.path("particle_size", "raw_exports_pilot_Jun13"))

# --- 6. cleaned chemistry (Mill Test rows only) ------------------------------------------
chem <- c(isotope = "isotope_mill_test.csv", tpc = "tpc_mill_test.csv",
          ankom = "ankom_mill_test.csv", ankom = "ankom_blanks_mill_test.csv",
          ankom = "ankom_sample_weights_mill_test.csv", ankom = "ankom_reported_vs_recomputed.csv",
          fat_assay = "fat_assay_mill_test.csv", brookside = "brookside_mill_test.csv",
          leaf_area = "leaf_area_mill_test.csv")
for (i in seq_along(chem)) put(d("derived", names(chem)[i], chem[[i]]), "chemistry")

# --- 7. taxonomy -------------------------------------------------------------------------
for (f in list.files(d("derived", "taxonomy"), pattern = "\\.csv$", full.names = TRUE)) put(f, "taxonomy")

invisible(file.copy(readme_src, file.path(pkg, "README.txt")))

# --- checks --------------------------------------------------------------------------------
sidecar <- read.csv(file.path(pkg, "spectral_metadata_sidecar.csv"))
flagged <- read.csv(file.path(pkg, "spectral_metadata_sidecar_with_qc_flags.csv"))
stopifnot(
  "spectra and sidecar keys differ" = setequal(spec$spectra, sidecar$spectra),
  "spectra ids are not unique" = !anyDuplicated(spec$spectra),
  "sidecar `spectra` not unique" = !anyDuplicated(sidecar$spectra),
  "flagged sidecar rows differ from the plain sidecar" = identical(flagged$spectra, sidecar$spectra),
  "no reflectance values should be missing" = !anyNA(spec[, ..num_cols])
)
# Nothing from another project: every Sample_ID in the cleaned chemistry files
# and sample_info must be a MILL24 sample.
for (f in list.files(file.path(pkg, "chemistry"), full.names = TRUE)) {
  x <- read.csv(f)
  id <- intersect(c("Sample_ID", "sample_name"), names(x))
  if (length(id) > 0) {
    bad <- x[[id[1]]][!grepl("^MILL24_", x[[id[1]]]) & !is.na(x[[id[1]]]) & !grepl("BLANK", x[[id[1]]], ignore.case = TRUE)]
    if (length(bad) > 0) stop(sprintf("%s has non-MILL24 sample ids: %s", basename(f), paste(head(bad), collapse = ", ")))
  }
}
si <- read.csv(file.path(pkg, "field_data", "sample_info.csv"))
stopifnot("sample_info has non-MILL24 ids" = all(grepl("^MILL24_", si$Sample_ID)))

# --- checksums and size ------------------------------------------------------------------------
files <- list.files(pkg, recursive = TRUE)
files <- files[files != "MANIFEST_md5.txt"]
sums <- tools::md5sum(file.path(pkg, files))
writeLines(sprintf("%s  %s", sums, files), file.path(pkg, "MANIFEST_md5.txt"))

sizes <- file.size(file.path(pkg, files))
cat(sprintf("Package A: %d files, %.1f MB, written to %s\n", length(files), sum(sizes) / 1e6, pkg))
top <- tibble(file = files, mb = sizes / 1e6) %>% arrange(desc(mb)) %>% head(5)
print(as.data.frame(top))
