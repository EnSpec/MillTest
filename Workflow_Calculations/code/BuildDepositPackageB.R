##################################################
#
# Title: Build deposit Package B (Zenodo data record)
#
# Project: Mill Test 2024
#
# Purpose: Assemble the companion data record that sits beside the EcoSIS
# package (Package A, BuildDepositPackageA.R): leaf scan photographs, the
# original .asd instrument files, regenerable spectral intermediates, the
# replicate-pair difference outputs, manuscript analysis outputs, and the raw
# assay workbooks. See data_manifest.md, "Deposit layout".
#
# Run from the repo root, after the whole README run order:
#   Rscript Workflow_Calculations/code/BuildDepositPackageB.R
#
# Left out on purpose:
#   - The raw isotope report, fat-assay workbook and ChemResults/Brookside.csv
#     (lab logs shared with other projects; only the cleaned Mill Test rows
#     ship, in Package A).
#   - The "2022_MillTest" sheet of the inventory workbook (an old equipment
#     pilot on other projects' samples). The other sheets are exported to CSV.
#   - LMA_Processing_Training/ and Pictures/ (training images and apparatus
#     photos, not data for any result), derived/data_join/ and
#     derived/trait_comparisons/ (large, regenerable by the repo code).
#
# Author: Henry Frye (with Claude Code), 2026-10-19
#
##################################################

library(tidyverse)
library(readxl)

data_root <- Sys.getenv("MILL24_DATA_ROOT", unset = "/Volumes/Enspec/projects/Mill24")
chem_sample_handling_root <- Sys.getenv("CHEM_SAMPLE_HANDLING_DATA_ROOT",
                                        unset = "/Volumes/Enspec/projects/chemistry_sample_handling")
pkg <- file.path(data_root, "deposit", "package_B")
readme_src <- file.path(data_root, "derived", "README_package_B_zenodo.txt")
stopifnot("README source missing" = file.exists(readme_src))

unlink(pkg, recursive = TRUE)
dir.create(pkg, recursive = TRUE)
d <- function(...) file.path(data_root, ...)

# Copy a whole folder (optionally only files matching `pattern`) keeping its
# internal structure. Returns the number of files copied.
copy_tree <- function(from, to_dir, pattern = NULL, exclude = NULL) {
  stopifnot(dir.exists(from))
  rel <- list.files(from, recursive = TRUE, pattern = pattern)
  if (!is.null(exclude)) rel <- rel[!grepl(exclude, rel)]
  for (r in rel) {
    dest <- file.path(pkg, to_dir, r)
    dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
    stopifnot(file.copy(file.path(from, r), dest))
  }
  length(rel)
}
put <- function(from, to_dir, rename = NULL) {
  stopifnot(file.exists(from))
  dir.create(file.path(pkg, to_dir), recursive = TRUE, showWarnings = FALSE)
  stopifnot(file.copy(from, file.path(pkg, to_dir, if (is.null(rename)) basename(from) else rename)))
}

n <- list()

# --- raw instrument files and photographs -------------------------------------
n$asd    <- copy_tree(d("DrySpec"), "DrySpec", pattern = "\\.asd$")
n$leaf   <- copy_tree(d("LeafScans"), "LeafScans", pattern = "\\.jpg$")

# --- regenerable spectral intermediates ------------------------------------------
put(d("spectralpredictr", "SpectralPredictR_VN_jumpcorrected_spectra.csv"), "spectral_intermediates")
put(d("spectralpredictr", "SpectralPredictR_5nmresampled_spectra.csv"), "spectral_intermediates")

# --- replicate-pair difference spectra (BootstrapCode.R output) ------------------------
n$diff <- copy_tree(d("BootstrappedData"), "BootstrappedData", pattern = "\\.csv$")

# --- manuscript analysis outputs (small; code regenerates them) ---------------------------
for (sub in c("spectral_difference", "spectral_difference_vn", "grind_variance",
              "treatment_agreement", "bootstrap")) {
  invisible(copy_tree(d("derived", sub), file.path("analysis_outputs", sub)))
}
invisible(copy_tree(d("derived", "maps"), file.path("analysis_outputs", "maps"), exclude = "tile_cache"))
# Includes the two saved brms fits (*_model.rds, ~280 MB each; re-fitting takes hours).
invisible(copy_tree(d("derived", "anova"), file.path("analysis_outputs", "anova")))
put(d("derived", "qc_review", "qc_review_plots.pdf"), "qc_review")

# --- leaf-area code (the notebook the interns used for the leaf scans) ---------------------
# Copied from the repo, where it was added 2026-10-19 from
# BioScape/ground_data/Workflow6_LeafArea_Code_Correct/Code/old_code/.
leaf_nb <- "Workflow_Calculations/code/leaf_area/leaf_area_approvedbyTing.ipynb"
stopifnot("run from the repo root" = file.exists(leaf_nb))
put(leaf_nb, "leaf_area_code")

# --- raw assay workbooks (Mill Test only; checked cell by cell for other projects) ---------
rw <- "raw_workbooks"
put(d("ChemResults", "Ankom_Primary_Template_Zach_MillFF.xlsx"), rw)
put(d("ChemResults", "Ankom_Primary_Template_Zach_MillOD.xlsx"), rw)
put(d("ChemResults", "Mill Test_FF_TPC.xlsx"), rw)
put(d("ChemResults", "Mill Test_OD_TPC.xlsx"), rw)
put(file.path(chem_sample_handling_root, "raw_chem_inputs", "08042026-FF BALL_GAE.xlsx"), rw)
put(file.path(chem_sample_handling_root, "raw_chem_inputs", "07302026 - OD BALL_GAE.xlsx"), rw)
put(d("field_data", "Mill24_LMA.xlsx"), rw)

# Inventory workbook: one CSV per sheet, minus the 2022 pilot sheet, which
# concerns other projects' samples.
inv_path <- d("field_data", "mill_test_inventory_data_log.xlsx")
inv_dir <- file.path(pkg, rw, "inventory_data_log_csv")
dir.create(inv_dir, recursive = TRUE)
for (sh in setdiff(excel_sheets(inv_path), "2022_MillTest")) {
  x <- suppressMessages(read_excel(inv_path, sheet = sh, .name_repair = "minimal"))
  write.csv(x, file.path(inv_dir, paste0(gsub("[^A-Za-z0-9]+", "_", sh), ".csv")), row.names = FALSE, na = "")
}

invisible(file.copy(readme_src, file.path(pkg, "README.txt")))

# --- checks ------------------------------------------------------------------------------------
stopifnot(
  "expected 2418 .asd files" = n$asd == 2418,
  "expected 101 leaf scan jpgs" = n$leaf == 101,
  "no 2022 pilot sheet may ship" = !any(grepl("2022", list.files(inv_dir))),
  "expected the two brms fits (calcium, nitrogen)" = sum(grepl("_model\\.rds$", list.files(pkg, recursive = TRUE))) == 2
)
asd <- list.files(file.path(pkg, "DrySpec"), recursive = TRUE, pattern = "\\.asd$")
stopifnot("an .asd file is not a MILL24 sample" = all(grepl("^MILL24_", basename(asd))))
stopifnot("one bootstrap output per sample x comparison expected (66 x 4)" = n$diff == 264)

files <- list.files(pkg, recursive = TRUE)
files <- files[files != "MANIFEST_md5.txt"]
sums <- tools::md5sum(file.path(pkg, files))
writeLines(sprintf("%s  %s", sums, files), file.path(pkg, "MANIFEST_md5.txt"))
sizes <- file.size(file.path(pkg, files))
cat(sprintf("Package B: %d files, %.1f MB, written to %s\n", length(files), sum(sizes) / 1e6, pkg))
print(as.data.frame(tibble(top_folder = sub("/.*", "", files), mb = sizes / 1e6) %>%
                      group_by(top_folder) %>% summarise(files = n(), mb = round(sum(mb), 1))))
