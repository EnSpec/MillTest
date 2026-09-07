# paths.R -- single source of truth for where the data lives.
#
# Data for this project is NOT stored in the git repo. It lives on the EnSpec
# lab server. Every script should get its file locations by sourcing this file
# and calling mill_path(), rather than hard-coding an absolute path or calling
# setwd().
#
#   source(here::here("R", "paths.R"))   # or a relative path to this file
#   raw <- read.csv(mill_path("raw_spectra", "Mill24_RawSpec.csv"))
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

#' Build a path inside the Mill24 data root.
#'
#' @param ... path components, passed to file.path()
#' @return an absolute path (not checked for existence)
mill_path <- function(...) {
  file.path(data_root, ...)
}

#' Build a path for a script output, creating the parent directory if needed.
#'
#' Outputs are written under <data_root>/derived/ so they sit next to the
#' inputs on the server and never land in the git repo.
#'
#' @param ... path components below derived/
mill_output_path <- function(...) {
  p <- file.path(data_root, "derived", ...)
  dir.create(dirname(p), recursive = TRUE, showWarnings = FALSE)
  p
}

# NOTE (Phase 1): the sub-directory names used with mill_path() are still being
# finalised together with the server folder reorganisation. Until that lands,
# treat the second argument to mill_path() as provisional.
