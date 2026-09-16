##################################################
#
# Title: Particle Size Stat Calculations
#
# Project: Mill Test 2024
#
# Date: 1/22/2026 (rewritten 2026-09-11 for a "clean per-bin" export format
#       that turned out not to be what Zach actually produces; rewritten
#       again 2026-09-15 for the real format -- see note below)
#
# Author: Zach Breuer, Mill Test Team
#
##################################################

# 2026-09-15: the LS 13320 software's own export ("full distribution data")
# is a multi-block text dump (instrument settings, then a [SampleStats]
# section with the software's own pre-computed Mean/Variance/Skew/Kurtosis
# for that run, then a [#Bindiam]/[SizePctY] per-bin distribution table we
# don't need since the moments are already computed for us). This is what
# particle_size/data/full/ actually holds, and what Zach's own
# (pre-cleanup) ParticleStat.R -- still the version he runs day to day --
# reads via fixed row-slice indices (507/530/532/531/49). Verified those
# five indices land exactly on Mean/Variance/Kurtosis/Skew/GroupID in every
# file checked, so the instrument's export format is consistent -- but
# reading by row position is fragile against any future export-software
# change, so this version looks up rows by their label (column 1) instead.
# Kurtosis is converted from the instrument's excess-kurtosis convention to
# the "regular"/Pearson scale (~3 for a normal distribution) via +3, same
# as Zach's original script. GroupID (e.g. "MILL24_0005_SIXT") gives
# Sample + milling treatment directly; growth-form Type isn't in this
# export at all and is joined in from field_data/sample_info.csv.

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
  raw <- read.csv(path, header = FALSE, stringsAsFactors = FALSE)

  get_val <- function(label) {
    idx <- which(raw$V1 == label)
    if (length(idx) == 0) return(NA_character_)
    raw$V2[idx[1]]
  }

  # "Mean" (and potentially other labels) also appears earlier in the file
  # as part of unrelated all-zero settings blocks -- e.g. "Mean, 0, 0, 0"
  # twice before the real distribution stats. Scope the moment lookups to
  # rows at or after [SizeStats], the section that actually holds them.
  # GroupID/Operator appear before [SizeStats] too (and are consistent
  # between their two occurrences in every file checked), so those use the
  # unrestricted lookup above.
  sizestats_idx <- which(raw$V1 == "[SizeStats]")[1]
  get_stat <- function(label) {
    idx <- which(raw$V1 == label & seq_len(nrow(raw)) >= sizestats_idx)
    if (length(idx) == 0) return(NA_character_)
    raw$V2[idx[1]]
  }

  # Filenames look like MILL24_0005_SIXT_10_01.$ls.csv; GroupID inside the
  # file is normally the same "MILL24_0005_SIXT" prefix, but the two can
  # disagree -- confirmed with Zach 2026-09-15 that when a treatment
  # export needed redoing, his workflow was to rename the output file
  # rather than re-run the ~10-minute measurement, which leaves GroupID
  # (baked into the file at export time) stale relative to the renamed
  # file. The filename is the authoritative label in that case; GroupID is
  # kept alongside purely as a provenance note, not used to exclude data.
  expected_group_id <- sub("_[0-9]+_[0-9]+\\..*$", "", basename(path))
  group_id <- get_val("GroupID")

  parts <- str_split(expected_group_id, "_")[[1]]

  tibble(
    Sample              = paste(parts[1], parts[2], sep = "_"),
    Treatment           = parts[3],
    Operator            = get_val("Operator"),
    Mean                = as.numeric(get_stat("Mean")),
    Variance            = as.numeric(get_stat("Variance")),
    Skew                = as.numeric(get_stat("Skew")),
    Kurtosis            = as.numeric(get_stat("Kurtosis")) + 3,
    GroupID_in_file     = group_id,
    GroupID_mismatch    = is.na(group_id) || group_id != expected_group_id
  )
}

particle_moments <- map(file_list, read_particle_file) %>%
  compact() %>%
  bind_rows()

# --- join growth form (not present in the raw export) ----------------------

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  select(Sample_ID, Type) %>%
  distinct()

particle_moments <- particle_moments %>%
  left_join(sample_info, by = c("Sample" = "Sample_ID")) %>%
  mutate(Treatment = recode(Treatment, BALL = "Ball", SIXT = "Fine", TWEN = "Twenty"))

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
