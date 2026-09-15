##################################################
#
# Title: Particle Size Stat Calculations
#
# Project: Mill Test 2024
#
# Date: 1/22/2026 (rewritten 2026-09-11 for the real ParticleDataFull export
#       format Zach staged -- see note below; the row-index approach this
#       script used before assumed a raw multi-hundred-row LS 13320
#       instrument export with pre-computed summary stats at fixed
#       positions, which is not what landed on the server)
#
# Author: Zach Breuer, Mill Test Team
#
##################################################

# Each file under particle_size/data/<session>/ is one sample x treatment:
# 93 particle-diameter bins ("um") with volume-percent ("Volume", sums to
# 100 per file) plus Treatment/Type/Sample columns repeated on every row.
# Distribution moments (mean, variance, skew, kurtosis) are computed here
# directly from the volume-weighted diameter distribution -- there are no
# pre-computed stats in this export format. Kurtosis is reported on the
# "regular"/Pearson scale (~3 for a normal distribution), matching the old
# script's `Kurtosis + 3` adjustment of an excess-kurtosis instrument value.
# Moments are computed on raw diameter (um), not log-diameter.

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "particle_size")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# particle_size/data/full/ is Zach's consolidated, de-duplicated copy of the
# real 22-individual x 3-treatment dataset (verified 2026-09-15: identical by
# filename and MD5 to the union of his dated distribution/<date>_Zach/
# subfolders). Read from full/ specifically, not particle_size/data/ itself --
# the dated subfolders under distribution/ are pre-consolidation duplicates of
# the same files, and distribution/Jun13/ holds two incomplete single-treatment
# pilot runs (Henry, protocol testing, pre-dates Zach's real campaign) for
# samples not otherwise in the 22-individual set. Reading the parent
# recursively would silently double-count every real sample and pull in the
# pilot files.
csvfolder <- file.path(data_root, "particle_size", "data", "full")
file_list <- list.files(csvfolder, pattern = "\\.csv$", recursive = TRUE, full.names = TRUE)

read_particle_file <- function(path) {
  df <- read.csv(path)
  # Sample/Treatment/Type should be constant within a file (one sample x
  # treatment per export). Found MILL24_0005_SIXT_10_01.$ls.csv with Sample
  # incrementing row-by-row (MILL24_0005, 0006, 0007, ...) instead of
  # staying fixed -- an export/copy-paste artifact, not real data. Flag and
  # skip rather than silently compute moments from garbage groupings.
  if (n_distinct(df$Sample) != 1 || n_distinct(df$Treatment) != 1 || n_distinct(df$Type) != 1) {
    warning(sprintf(
      "skipping %s: Sample/Treatment/Type not constant within the file (export artifact?) -- flag for Zach",
      basename(path)
    ))
    return(NULL)
  }

  w <- df$Volume / sum(df$Volume)
  d <- df$um
  mean_d <- sum(w * d)
  var_d  <- sum(w * (d - mean_d)^2)
  sd_d   <- sqrt(var_d)

  tibble(
    Sample    = df$Sample[1],
    Treatment = df$Treatment[1],
    Type      = df$Type[1],
    Mean      = mean_d,
    Variance  = var_d,
    Skew      = sum(w * (d - mean_d)^3) / sd_d^3,
    Kurtosis  = sum(w * (d - mean_d)^4) / sd_d^4
  )
}

particle_moments <- map(file_list, read_particle_file) %>%
  compact() %>%
  bind_rows()

# --- average moments by growth form x milling treatment (per manuscript methods) ---

particle_summary <- particle_moments %>%
  group_by(Type, Treatment) %>%
  summarise(
    n = n(),
    Mean         = mean(Mean),
    Variance     = mean(Variance),
    Skew         = mean(Skew),
    Kurtosis     = mean(Kurtosis),
    AbsSkew      = mean(abs(Skew)),
    AbsKurtosis  = mean(abs(Kurtosis)),
    .groups = "drop"
  )

print(particle_summary)
write.csv(particle_moments, file.path(out_dir, "particle_size_per_sample.csv"), row.names = FALSE)
write.csv(particle_summary, file.path(out_dir, "particle_size_summary.csv"), row.names = FALSE)
