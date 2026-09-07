# paths.R -- single source of truth for where the data lives.
#
# Data for this project is NOT stored in the git repo. It lives on the EnSpec
# lab server. Every script should get its file locations by sourcing this file
# and using the helpers below, rather than hard-coding an absolute path or
# calling setwd().
#
#   source(here::here("R", "paths.R"))   # or a relative path to this file
#   raw  <- read.csv(raw_spec_file())
#   chem <- read.csv(chem_path("Brookside.csv"))
#   ggsave(mill_output_path("figures", "bias_chart.png"), plot = p)
#
# Override the root without editing this file by setting an environment
# variable before starting R:
#
#   Sys.setenv(MILL24_DATA_ROOT = "/some/other/copy/of/Mill24")
#
# ---------------------------------------------------------------------------

data_root <- Sys.getenv(
  "MILL24_DATA_ROOT",
  unset = "/Volumes/Enspec/projects/Mill24"
)

if (!dir.exists(data_root)) {
  stop(
    "Mill24 data root not found:\n  ", data_root,
    "\nMount the EnSpec server, or set MILL24_DATA_ROOT to a local copy.",
    call. = FALSE
  )
}

# --- server folder names --------------------------------------------------
# Layout is ADDITIVE: existing sub-directories keep their original names
# (ChemResults/ is read directly by other projects on the server, e.g.
# chemistry-sample-handling's isotope side-check -- do not rename it). Only
# the *new* homes for not-yet-staged material were added.
.dirs <- list(
  chem            = "ChemResults",             # existing
  bootstrap       = "BootstrappedData",        # existing (BootstrapCode.R output)
  dry_spec        = "DrySpec",                 # existing (raw .asd)
  leaf_scans      = "LeafScans",               # existing
  lma_training    = "LMA_Processing_Training", # existing
  spectralpredictr = "spectralpredictr",       # NEW  -- SpectralPredictR exports
  field_data      = "field_data",              # NEW  -- sample_info.csv + inputs
  particle_size   = "particle_size",           # NEW  -- LS 13 320 exports
  derived         = "derived"                  # NEW  -- all script outputs
)

#' Build a path inside the Mill24 data root. Low-level; prefer the named
#' helpers below.
#' @param ... path components, passed to file.path()
mill_path <- function(...) file.path(data_root, ...)

#' Raw ASD spectra table (one row per spectral replicate).
raw_spec_file <- function() mill_path("Mill24_RawSpec.csv")

chem_path            <- function(...) mill_path(.dirs$chem, ...)
bootstrap_path       <- function(...) mill_path(.dirs$bootstrap, ...)
dry_spec_path        <- function(...) mill_path(.dirs$dry_spec, ...)
spectralpredictr_path <- function(...) mill_path(.dirs$spectralpredictr, ...)
field_data_path      <- function(...) mill_path(.dirs$field_data, ...)
particle_size_path   <- function(...) mill_path(.dirs$particle_size, ...)

#' Canonical field / leaf-trait metadata table (Species, Type, coords, masses,
#' chlorophyll). Joined into most downstream analyses on Sample_ID.
sample_info_file <- function() field_data_path("sample_info.csv")

#' Build a path for a script OUTPUT, creating the parent directory if needed.
#' Everything lands under <data_root>/derived/ and never in the git repo.
#' @param ... path components below derived/
mill_output_path <- function(...) {
  p <- mill_path(.dirs$derived, ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}
