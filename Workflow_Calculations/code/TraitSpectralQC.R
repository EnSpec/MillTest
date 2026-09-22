##################################################
#
# TraitSpectralQC.R
#
# Project: Mill Test 2024
#
# Purpose: Apply the shared enspec-qc trait + spectral QC checks to the
# Mill Test EcoSIS deposit, using qc_config_milltest.R for everything
# project-specific (grouping variables, bounds, thresholds). First real
# implementation of the hybrid QC standard decided 2026-09-20 -- see
# CLAUDE.md "Data QC standard" section.
#
# FLAG-ONLY for this deposit (timeboxed, per Henry 2026-09-20): every
# check below only flags. qc_apply_removals() from enspec-qc is not
# called. Output: cleaned-data-with-flag-columns, per-check flag CSVs, and
# a combined QC report -- nothing dropped silently.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(smatr)  # used inside enspec-qc's qc_covariation_outliers() (smatr::sma());
                # declared here too so renv's dependency scan picks it up --
                # enspec-qc lives outside this project and is only source()'d
                # at runtime, invisible to renv's static scan otherwise.

# --- locations -----------------------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT", unset = "/Volumes/Enspec/projects/Mill24")
qc_lib_path <- Sys.getenv("ENSPEC_QC_PATH", unset = "/Users/henryfrye/enspec/enspec-qc")

get_script_dir <- function() {
  args <- commandArgs(trailingOnly = FALSE)
  hit <- grep("^--file=", args)
  if (length(hit) == 0) return(getwd())  # interactive/sourced fallback
  dirname(normalizePath(sub("^--file=", "", args[hit])))
}

source(file.path(qc_lib_path, "R", "trait_qc.R"))
source(file.path(qc_lib_path, "R", "spectral_qc.R"))
source(file.path(qc_lib_path, "R", "qc_report.R"))
source(file.path(get_script_dir(), "qc_config_milltest.R"))

out_dir <- file.path(data_root, "derived", "qc")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- inputs ----------------------------------------------------------------
sidecar <- read.csv(file.path(data_root, "derived", "ecosis", "spectral_metadata_sidecar.csv"))

sidecar <- sidecar %>%
  mutate(
    species_dry_treatment     = paste(species_code, dry_treatment, sep = "_"),
    growth_form_mill_treatment = paste(growth_form, mill_treatment, sep = "_"),
    measure_id = paste(sample_name, mill_treatment, dry_treatment, sep = "_")  # one spectral replicate set
  )

flag_list <- list()

# =========================================================================
# 1. TRAIT QC
# =========================================================================
message("== Trait QC ==")

# ---- 1a. Hard-bounds sweep (physical + literature; flag only here) -----
# Run once against the full per-spectrum sidecar -- hard bounds don't
# depend on the grouping/dedup level, and flagging every affected spectrum
# row is useful for tracing which rows a deposit-level flag touches.
trait_id_cols <- c("spectra", "sample_name", "species_code", "growth_form",
                   "mill_treatment", "dry_treatment", "replicate")

hard_bounds_flags <- qc_hard_bounds(sidecar, bounds_table, trait_id_cols)
flag_list[["hard_bounds"]] <- qc_write_log(hard_bounds_flags, out_dir, "trait_hard_bounds")

# ---- 1b. Magnitude-shift + distribution checks, per trait category -----
# Dedup to the level each trait category actually varies at (see
# qc_config_milltest.R comments) before running group-based checks, so a
# trait broadcast across 6 replicate rows isn't treated as 6 independent
# observations.
run_group_checks_for_category <- function(category_name, spec) {
  dedup_cols <- unique(c(spec$dedup_by, "species_code", "growth_form",
                        "mill_treatment", "dry_treatment", spec$group_var))
  dedup_cols <- dedup_cols[dedup_cols %in% names(sidecar)]

  cat_df <- sidecar %>%
    select(all_of(unique(c(dedup_cols, spec$traits)))) %>%
    distinct()

  id_cols <- spec$dedup_by

  for (tr in spec$traits) {
    if (!tr %in% names(cat_df)) next

    mag_flags <- qc_magnitude_shift(cat_df, spec$group_var, tr, id_cols,
                                    log10_threshold = thresholds$magnitude_log10)
    if (nrow(mag_flags) > 0) {
      flag_list[[paste0(category_name, "_", tr, "_magnitude")]] <<-
        qc_write_log(mag_flags, out_dir, paste0(category_name, "_", tr, "_magnitude"))
    }

    dist_flags <- qc_distribution_outliers(cat_df, spec$group_var, tr, id_cols,
                                           z_threshold = thresholds$distribution_z)
    if (nrow(dist_flags) > 0) {
      flag_list[[paste0(category_name, "_", tr, "_distribution")]] <<-
        qc_write_log(dist_flags, out_dir, paste0(category_name, "_", tr, "_distribution"))
    }
  }
}

for (cat_name in names(trait_groups)) {
  message(sprintf(" -- category: %s", cat_name))
  run_group_checks_for_category(cat_name, trait_groups[[cat_name]])
}

# ---- 1c. Leave-one-out bad-measure check on wide replicate sets ---------
# Pivot each wide replicate set long so the within-individual leave-one-out
# check can see the replicates as replicates (see qc_config_milltest.R's
# `replicate_column_sets` for why this layout is easy to miss).
for (set_name in names(replicate_column_sets)) {
  spec <- replicate_column_sets[[set_name]]
  present_cols <- spec$cols[spec$cols %in% names(sidecar)]
  if (length(present_cols) < 2) next

  long_df <- sidecar %>%
    select(all_of(unique(c(spec$dedup_by, "species_code", "growth_form", present_cols)))) %>%
    distinct() %>%
    pivot_longer(all_of(present_cols),
                names_to = paste0(set_name, "_replicate"),
                values_to = paste0(set_name, "_value"))

  loo_flags <- qc_bad_single_measure(
    long_df,
    group_var = spec$group_var,
    value_col = paste0(set_name, "_value"),
    id_cols = c(spec$dedup_by, "species_code", paste0(set_name, "_replicate")),
    ratio_threshold = thresholds$bad_measure_ratio
  )
  if (nrow(loo_flags) > 0) {
    flag_list[[paste0(set_name, "_bad_replicate")]] <-
      qc_write_log(loo_flags, out_dir, paste0(set_name, "_bad_replicate"))
  }
}

# ---- 1d. Covariation checks --------------------------------------------
tree_dedup <- sidecar %>% distinct(sample_name, species_code, growth_form,
                                   nitrogen_IRMS_mg_g, carbon_mg_g, lma_g_m2)

for (i in seq_len(nrow(covariation_pairs))) {
  pr <- covariation_pairs[i, ]
  covar_flags <- qc_covariation_outliers(
    tree_dedup, trait1 = pr$trait1, trait2 = pr$trait2,
    id_cols = c("sample_name", "species_code", "growth_form"),
    log_scale = pr$log_scale, z_threshold = thresholds$covariation_z
  )
  if (nrow(covar_flags) > 0) {
    flag_list[[paste0("covariation_", pr$trait1, "_", pr$trait2)]] <-
      qc_write_log(covar_flags, out_dir, paste0("covariation_", pr$trait1, "_", pr$trait2))
  }
}

# =========================================================================
# 2. SPECTRAL QC
# =========================================================================
message("\n== Spectral QC ==")

# Use the jump-corrected, PRE-normalization spectra (data_manifest.md:
# "jump-corrected spectra, pre-normalization") -- this is the actual 0-1
# reflectance data matching the deposit sidecar's column_units = "Fraction".
# SpectralPredictR_5nmresampled_spectra.csv is NOT reflectance -- it's the
# vector-normalized, 5nm-resampled spectra used for trait prediction (see
# data_manifest.md and the CLAUDE.md FLAG on spectrolab::normalize()); a
# vector-normalized spectrum has near-constant magnitude by construction
# (median ~0.02, full-spectrum range ~0.03 -- confirmed 2026-09-22), which
# made every spectrum look "flat" against physically-meaningful reflectance
# thresholds. Caught by actually running this against real data.
spec_raw <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_raw_spectra.csv"),
                     check.names = FALSE)
names(spec_raw)[1] <- "spectra"

wave_cols <- grep("^X[0-9]+$", names(spec_raw), value = TRUE)

spec_joined <- spec_raw %>%
  left_join(sidecar %>% select(spectra, sample_name, species_code, growth_form,
                               mill_treatment, dry_treatment, replicate, measure_id),
           by = "spectra") %>%
  filter(!is.na(sample_name))  # guard against any join misses

spec_id_cols <- c("spectra", "sample_name", "species_code", "growth_form",
                  "mill_treatment", "dry_treatment", "replicate")

flat_flags <- qc_spectral_flat(spec_joined, wave_cols, spec_id_cols,
                               flat_range_threshold = thresholds$spectral_flat_range,
                               low_thresh = thresholds$spectral_flat_low,
                               high_thresh = thresholds$spectral_flat_high)
flag_list[["spectral_flat"]] <- qc_write_log(flat_flags, out_dir, "spectral_flat")

range_flags <- qc_spectral_out_of_range(spec_joined, wave_cols, spec_id_cols)
flag_list[["spectral_out_of_range"]] <- qc_write_log(range_flags, out_dir, "spectral_out_of_range")

# Grouping unit = one spectral replicate set (sample x mill treatment x dry
# treatment, ~6 replicates) -- matches how the manuscript's own bootstrap
# procedure treats replicate sets (BootstrapCode.R), and is the level at
# which "the probe wasn't on the sample right for this one scan" would show
# up against its own siblings.
group_outlier_flags <- qc_spectral_group_outliers(spec_joined, "measure_id", wave_cols, spec_id_cols,
                                                   min_n = 4, z_threshold = thresholds$spectral_angle_z)
flag_list[["spectral_group_outlier"]] <- qc_write_log(group_outlier_flags, out_dir, "spectral_group_outlier")

# =========================================================================
# 3. COMBINED REPORT
# =========================================================================
message("\n== Building combined QC report ==")
check_counts <- qc_build_report(flag_list, out_dir = out_dir)

# ---- Broadcast every check's flags down to the per-spectrum grain -------
# The deposit's actual row grain is one row per spectrum (the sidecar).
# Checks above flag at coarser grains (sample_name; sample_name x
# dry_treatment; sample_name x mill_treatment) -- this is the project-
# specific join enspec-qc::qc_build_report() deliberately leaves undone
# (see its docstring). Broadcasting a sample-level flag means every
# spectrum row for that sample/treatment combo inherits the flag, since
# that's the grain the deposit is actually shipped at.
broadcast_to_spectra <- function(flag_df, check_name) {
  join_cols <- intersect(c("spectra", "sample_name", "dry_treatment", "mill_treatment"), names(flag_df))
  if ("spectra" %in% join_cols) {
    spectra_hit <- flag_df$spectra
  } else if (length(join_cols) > 0) {
    spectra_hit <- sidecar %>%
      semi_join(flag_df %>% distinct(across(all_of(join_cols))), by = join_cols) %>%
      pull(spectra)
  } else {
    return(NULL)
  }
  tibble::tibble(spectra = unique(spectra_hit), flag_source = check_name)
}

quality_flag_long <- bind_rows(lapply(names(flag_list), function(nm) {
  broadcast_to_spectra(flag_list[[nm]], nm)
}))

quality_flag_by_spectrum <- sidecar %>%
  distinct(spectra) %>%
  left_join(
    quality_flag_long %>%
      group_by(spectra) %>%
      summarise(quality_flag = paste(sort(unique(flag_source)), collapse = "; "),
               n_checks_flagged = n(), .groups = "drop"),
    by = "spectra"
  ) %>%
  mutate(quality_flag = replace_na(quality_flag, ""),
        n_checks_flagged = replace_na(n_checks_flagged, 0L))

write.csv(quality_flag_by_spectrum, file.path(out_dir, "qc_quality_flag_by_spectrum.csv"), row.names = FALSE)

# Deposit-ready sidecar copy with the flag columns carried in, alongside
# (not replacing) the original spectral_metadata_sidecar.csv -- per the QC
# standard's "flag columns carried into the deposit" output contract.
sidecar_with_flags <- sidecar %>%
  select(-species_dry_treatment, -growth_form_mill_treatment, -measure_id) %>%
  left_join(quality_flag_by_spectrum, by = "spectra")

write.csv(sidecar_with_flags, file.path(out_dir, "spectral_metadata_sidecar_with_qc_flags.csv"), row.names = FALSE)

n_flagged_spectra <- sum(quality_flag_by_spectrum$quality_flag != "")
message(sprintf("\n%d of %d spectra (%.1f%%) carry at least one QC flag",
                n_flagged_spectra, nrow(quality_flag_by_spectrum),
                100 * n_flagged_spectra / nrow(quality_flag_by_spectrum)))
flag_reason_counts <- quality_flag_by_spectrum %>%
  filter(quality_flag != "") %>%
  count(quality_flag, sort = TRUE) %>%
  as.data.frame()
print(head(flag_reason_counts, 30))

message(sprintf("\nDone. Flag CSVs + qc_check_summary.csv + qc_quality_flag_by_spectrum.csv + spectral_metadata_sidecar_with_qc_flags.csv written to %s", out_dir))
message("Flag-only run (per 2026-09-20 policy) -- no values were removed from any deposit file.")
