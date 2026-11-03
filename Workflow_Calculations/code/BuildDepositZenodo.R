##################################################
#
# Title: Build the combined Zenodo deposit and the slim EcoSIS copy
#
# Project: Mill Test 2024
#
# Purpose: Merge the two packages built by BuildDepositPackageA.R (spectra,
# per-spectrum metadata, QC, cleaned chemistry) and BuildDepositPackageB.R
# (instrument files, photographs, intermediates, raw workbooks) into ONE record
# for Zenodo, with a single README and checksum list, and write a zip of it.
# Also writes a slim EcoSIS package (spectra and per-spectrum metadata only)
# for discoverability; Zenodo is the primary, citable source. See
# data_manifest.md, "Deposit layout".
#
# Run after BuildDepositPackageA.R and BuildDepositPackageB.R, from the repo
# root:
#   Rscript Workflow_Calculations/code/BuildDepositZenodo.R
#
# The two packages have no file paths in common except README.txt and
# MANIFEST_md5.txt, which are replaced here; the script stops if that changes.
#
# Author: Henry Frye (with Claude Code), 2026-11-03
#
##################################################

library(tidyverse)

data_root <- Sys.getenv("MILL24_DATA_ROOT", unset = "/Volumes/Enspec/projects/Mill24")
dep <- file.path(data_root, "deposit")
pkg_a <- file.path(dep, "package_A")
pkg_b <- file.path(dep, "package_B")
out <- file.path(dep, "zenodo_record")
slim <- file.path(dep, "ecosis_slim")
readme_src <- file.path(data_root, "derived", "README_zenodo_deposit.txt")
slim_readme_src <- file.path(data_root, "derived", "README_ecosis_slim.txt")
zip_path <- file.path(dep, "Mill24_data_record.zip")
stopifnot("README source missing" = file.exists(readme_src),
          "slim README source missing" = file.exists(slim_readme_src))

# Both source packages must match their own checksum lists before anything is
# merged from them.
verify <- function(pkg) {
  m <- readLines(file.path(pkg, "MANIFEST_md5.txt"))
  hash <- sub("  .*$", "", m)
  rel <- sub("^[0-9a-f]{32}  ", "", m)
  actual <- unname(tools::md5sum(file.path(pkg, rel)))
  name <- basename(pkg)
  stopifnot(
    "checksum mismatch or missing file in a source package" = identical(actual, hash),
    "source package has files not in its manifest" =
      setequal(c(rel, "MANIFEST_md5.txt"), list.files(pkg, recursive = TRUE))
  )
  cat(sprintf("%s: %d files match their manifest\n", name, length(rel)))
}
verify(pkg_a)
verify(pkg_b)

skip <- c("README.txt", "MANIFEST_md5.txt")
fa <- setdiff(list.files(pkg_a, recursive = TRUE), skip)
fb <- setdiff(list.files(pkg_b, recursive = TRUE), skip)
stopifnot("packages A and B share file paths" = length(intersect(fa, fb)) == 0)

unlink(out, recursive = TRUE)
dir.create(out, recursive = TRUE)
copy_in <- function(pkg, rel) {
  for (r in rel) {
    dir.create(dirname(file.path(out, r)), recursive = TRUE, showWarnings = FALSE)
    # Hard link where the volume allows it (package B is 1.1 GB); copy otherwise.
    if (!suppressWarnings(file.link(file.path(pkg, r), file.path(out, r))))
      stopifnot(file.copy(file.path(pkg, r), file.path(out, r)))
  }
}
copy_in(pkg_a, fa)
copy_in(pkg_b, fb)
stopifnot(file.copy(readme_src, file.path(out, "README.txt")))

files <- setdiff(list.files(out, recursive = TRUE), "MANIFEST_md5.txt")
stopifnot("unexpected file count" = length(files) == length(fa) + length(fb) + 1,
          "stray macOS files" = !any(grepl("(^|/)(\\.DS_Store|__MACOSX|\\._)", files)))
sums <- tools::md5sum(file.path(out, files))
writeLines(sprintf("%s  %s", sums, files), file.path(out, "MANIFEST_md5.txt"))
sizes <- file.size(file.path(out, files))
cat(sprintf("Zenodo record: %d files, %.1f MB, written to %s\n", length(files) + 1, sum(sizes) / 1e6, out))

# Zenodo does not take folders through the web form (and caps files per record),
# so the record ships as one zip, with README.txt also uploaded beside it so the
# record page is readable without unzipping.
unlink(zip_path)
owd <- setwd(dep)
stopifnot(system2("zip", c("-r", "-X", "-q", shQuote(basename(zip_path)), "zenodo_record")) == 0)
setwd(owd)
cat(sprintf("Zip: %s (%.1f MB)\n", zip_path, file.size(zip_path) / 1e6))

# --- slim EcoSIS copy -------------------------------------------------------------------
unlink(slim, recursive = TRUE)
dir.create(slim, recursive = TRUE)
for (f in c("Mill24_spectra_jumpcorrected.csv", "spectral_metadata_sidecar_with_qc_flags.csv"))
  stopifnot(file.copy(file.path(pkg_a, f), file.path(slim, f)))
stopifnot(file.copy(slim_readme_src, file.path(slim, "README.txt")))
sf <- setdiff(list.files(slim, recursive = TRUE), "MANIFEST_md5.txt")
writeLines(sprintf("%s  %s", tools::md5sum(file.path(slim, sf)), sf), file.path(slim, "MANIFEST_md5.txt"))
cat(sprintf("EcoSIS slim: %d files, %.1f MB, written to %s\n", length(sf) + 1,
            sum(file.size(file.path(slim, sf))) / 1e6, slim))
