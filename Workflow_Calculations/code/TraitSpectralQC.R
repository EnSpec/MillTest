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
  if (length(hit) > 0) return(dirname(normalizePath(sub("^--file=", "", args[hit]))))
  # Interactive/sourced fallback: working directory is either the repo root
  # (the .Rproj location) or the script's own folder.
  code_dir <- file.path(getwd(), "Workflow_Calculations", "code")
  if (file.exists(file.path(code_dir, "qc_config_milltest.R"))) code_dir else getwd()
}

source(file.path(qc_lib_path, "R", "trait_qc.R"))
source(file.path(qc_lib_path, "R", "spectral_qc.R"))
source(file.path(qc_lib_path, "R", "spectral_transforms.R"))  # snv_over_range()
source(file.path(qc_lib_path, "R", "qc_report.R"))
source(file.path(get_script_dir(), "qc_config_milltest.R"))

out_dir <- file.path(data_root, "derived", "qc")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Clear this directory's previous contents before writing. Several outputs here
# are written conditionally -- a per-check flag table only appears when that
# check fires, and spectra_qc_cleaned.csv only when a spectrum is actually
# removed -- so without this, a file from an earlier run survives into a later
# one and misrepresents it. That is not hypothetical: after the 2026-09-24
# ANKOM fix stopped both the physical-bounds and cascade checks from firing,
# this directory still held their 2026-09-23 flag tables, plus a
# spectra_qc_cleaned.csv from the run whose removal bug dropped 18 whole
# spectra. Anyone reading the directory would have taken all three as current.
# The whole point of shipping a QC report is that it describes this run.
old_outputs <- c(Sys.glob(file.path(out_dir, "*_flags.csv")),
                 file.path(out_dir, c("qc_check_summary.csv",
                                      "qc_quality_flag_by_spectrum.csv",
                                      "removal_log.csv",
                                      "spectra_qc_cleaned.csv",
                                      "spectral_jump_correction_status.csv",
                                      "spectral_metadata_sidecar_with_qc_flags.csv")))
old_outputs <- old_outputs[file.exists(old_outputs)]
if (length(old_outputs) > 0) {
  invisible(file.remove(old_outputs))
  message(sprintf("Cleared %d output(s) from a previous QC run", length(old_outputs)))
}

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

# Run as two separate checks so the outputs keep the distinction a reader
# actually needs: "physically impossible" vs "outside the compiled literature
# range". Only the first is ever removal-eligible (see qc_config_milltest.R).
physical_flags <- qc_hard_bounds(sidecar, removable_bounds, trait_id_cols)
flag_list[["trait_physical_bounds"]] <- qc_write_log(physical_flags, out_dir, "trait_physical_bounds")

literature_flags <- qc_hard_bounds(sidecar, flag_only_bounds, trait_id_cols)
flag_list[["trait_literature_bounds"]] <- qc_write_log(literature_flags, out_dir, "trait_literature_bounds")

# Sequential-assay cascade: a failure early in a sequential wash puts every
# trait derived after it in doubt. Runs off the physical-bounds failures,
# since those are the unambiguous ones. With no physical-bounds failures there
# is nothing to cascade from -- and a zero-row flag table carries no columns to
# select on, so skip rather than subset it.
for (chain_name in names(sequential_assay_chains)) {
  if (nrow(physical_flags) == 0) break
  spec <- sequential_assay_chains[[chain_name]]
  cascade <- qc_sequential_cascade(
    physical_flags %>% distinct(across(all_of(c(spec$key_cols, "trait_flagged")))),
    chain = spec$chain,
    key_cols = spec$key_cols
  )
  if (nrow(cascade) > 0) {
    flag_list[[paste0(chain_name, "_cascade")]] <-
      qc_write_log(cascade, out_dir, paste0(chain_name, "_cascade"))
    if (!identical(spec$policy, "flag")) {
      warning(sprintf("chain '%s' has policy '%s' but only 'flag' is wired up", chain_name, spec$policy))
    }
  }
}

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

# ---- 1d. Assay-specific checks (Henry, 2026-09-23) ---------------------

# Phenolics replicate precision. Uses the TPC sheets' own reported SD across
# their duplicate/triplicate measures (carried through by TPCExtract.R), so
# this asks "did the assay agree with itself", which no other check here can.
# Dedup to sample x dry treatment -- the grain TPC was actually run at.
tpc_level <- sidecar %>%
  select(sample_name, species_code, dry_treatment, phenolics_mg_g, phenolics_sd) %>%
  distinct()

phenolics_cv_flags <- qc_relative_error(
  tpc_level, value_col = "phenolics_mg_g", error_col = "phenolics_sd",
  id_cols = c("sample_name", "species_code", "dry_treatment"),
  max_cv = thresholds$phenolics_max_cv
)
flag_list[["phenolics_relative_error"]] <- qc_write_log(phenolics_cv_flags, out_dir, "phenolics_relative_error")

# ANKOM blank-bag leak check. Batch-level: a leaking blank implicates every
# sample processed alongside it, so a flagged batch is propagated to all of
# that batch's samples below rather than left as a standalone note.
ankom_blanks_path <- file.path(data_root, "derived", "ankom", "ankom_blanks_mill_test.csv")
if (file.exists(ankom_blanks_path)) {
  ankom_blanks <- read.csv(ankom_blanks_path)

  blank_drift <- qc_blank_drift(
    ankom_blanks,
    id_cols = c("batch", "bag_number"),
    tare_col = "bag_tare_g",
    step_cols = c("weight_after_ndf_g", "weight_after_adf_g", "weight_after_adl_g"),
    increase_threshold = thresholds$ankom_blank_increase
  )
  qc_write_log(blank_drift, out_dir, "ankom_blank_drift")
  print(blank_drift)

  # Propagate only batches that breach the threshold. A blank that gains a
  # trace amount is worth recording (above) but shouldn't condemn 23 samples.
  bad_batches <- blank_drift %>% filter(exceeds_threshold) %>% pull(batch) %>% unique()
  if (length(bad_batches) > 0) {
    batch_flags <- sidecar %>%
      filter(dry_treatment %in% bad_batches, !is.na(hemicellulose_mg_g)) %>%
      distinct(sample_name, species_code, dry_treatment) %>%
      mutate(batch = dry_treatment,
             reason = "ANKOM blank bag gained weight beyond threshold -- batch contamination suspected",
             check = "ankom_batch_contamination")
    flag_list[["ankom_batch_contamination"]] <-
      qc_write_log(batch_flags, out_dir, "ankom_batch_contamination")
  } else {
    message(sprintf("  ankom_blank_drift: %d blank/step gains recorded, none above the %.0f%% threshold -- no batch condemned",
                    nrow(blank_drift), 100 * thresholds$ankom_blank_increase))
  }
} else {
  message("  ankom_blank_drift: SKIPPED -- run AnkomExtract.R to produce ankom_blanks_mill_test.csv")
}

# ANKOM spreadsheet arithmetic. The workbooks report each fiber fraction as a
# formula over the typed-in weights; AnkomExtract.R recomputes the same
# fractions straight from the protocol and writes both side by side. A
# disagreement means the workbook's arithmetic is broken -- a relative cell
# reference that slipped a row, so the formula reads a neighbouring sample's
# weight. The values such a formula produces are entirely plausible and match
# their own batch, so no bounds, group or literature check can see them; only
# recomputation can (found 2026-09-24, two rows of the FF sheet).
# Flag-only here: the deposit already carries the recomputed values, so this
# records the defect for whoever fixes the source workbook.
# ANKOM start weight. The protocol calls for 0.5 g +/- 0.05 per bag, and that
# weight is the denominator of all three fiber fractions -- so a wrong one
# scales every trait for that sample without making any of them look
# impossible. Flag-only: a small deviation is a protocol deviation, not bad
# data (Henry, 2026-09-24).
ankom_weights_path <- file.path(data_root, "derived", "ankom",
                                "ankom_sample_weights_mill_test.csv")
if (file.exists(ankom_weights_path)) {
  ankom_weight_flags <- qc_hard_bounds(
    read.csv(ankom_weights_path), ankom_weight_bounds,
    id_cols = c("sample_name", "dry_treatment")
  )
  flag_list[["ankom_start_weight"]] <-
    qc_write_log(ankom_weight_flags, out_dir, "ankom_start_weight")
  if (nrow(ankom_weight_flags) > 0) {
    cat("  !! ANKOM start weights outside the protocol window:\n")
    print(as.data.frame(ankom_weight_flags))
  }
} else {
  message("  ankom_start_weight: SKIPPED -- run AnkomExtract.R to produce ankom_sample_weights_mill_test.csv")
}

ankom_recompute_path <- file.path(data_root, "derived", "ankom",
                                  "ankom_reported_vs_recomputed.csv")
if (file.exists(ankom_recompute_path)) {
  ankom_formula_flags <- qc_derived_mismatch(
    read.csv(ankom_recompute_path),
    id_cols = c("sample_name", "dry_treatment", "trait"),
    reported_col = "sheet_value",
    recomputed_col = "recomputed",
    # 0.01 mg/g is far below what this assay can resolve, so anything above
    # it is a defect rather than floating-point noise
    tolerance = 0.01
  )
  flag_list[["ankom_formula_mismatch"]] <-
    qc_write_log(ankom_formula_flags, out_dir, "ankom_formula_mismatch")
  if (nrow(ankom_formula_flags) > 0) {
    cat("  !! ANKOM workbook formulas disagree with the protocol (recomputed values used in the deposit):\n")
    print(as.data.frame(ankom_formula_flags %>%
      select(sample_name, dry_treatment, trait, reported, recomputed, difference)))
  }
} else {
  message("  ankom_formula_mismatch: SKIPPED -- run AnkomExtract.R to produce ankom_reported_vs_recomputed.csv")
}

# ---- 1e. Covariation checks --------------------------------------------
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

# `spectra` must be a unique key on both sides or this join silently
# multiplies rows, which quietly corrupts every downstream group statistic
# (a 6-replicate set reads as 7, medoid selection sees a phantom scan, PCA
# centroids get dragged). This is not hypothetical: the sidecar carried 42
# duplicated spectra ids until 2026-09-23 because it wasn't applying
# SpectralPredictR.R's keep-the-later-scan rule. Assert rather than trust.
stopifnot(
  "sidecar `spectra` must be unique -- rerun EcoSISMetadataSidecar.R" =
    !any(duplicated(sidecar$spectra)),
  "spectral file `spectra` must be unique" =
    !any(duplicated(spec_raw$spectra))
)

spec_joined <- spec_raw %>%
  left_join(sidecar %>% select(spectra, sample_name, species_code, growth_form,
                               mill_treatment, dry_treatment, replicate, measure_id),
           by = "spectra") %>%
  filter(!is.na(sample_name))  # guard against any join misses

stopifnot("join changed row count -- check key uniqueness" =
            nrow(spec_joined) <= nrow(spec_raw))

spec_id_cols <- c("spectra", "sample_name", "species_code", "growth_form",
                  "mill_treatment", "dry_treatment", "replicate")

flat_flags <- qc_spectral_flat(spec_joined, wave_cols, spec_id_cols,
                               flat_range_threshold = thresholds$spectral_flat_range,
                               low_thresh = thresholds$spectral_flat_low,
                               high_thresh = thresholds$spectral_flat_high)
flag_list[["spectral_flat"]] <- qc_write_log(flat_flags, out_dir, "spectral_flat")

range_flags <- qc_spectral_out_of_range(spec_joined, wave_cols, spec_id_cols)
flag_list[["spectral_out_of_range"]] <- qc_write_log(range_flags, out_dir, "spectral_out_of_range")

# Single-band checks on reflectance (R350 ceiling, NIR plateau floor): "this
# scan measured nothing". Both are removals -- see removal_policy.
for (check_name in names(spectral_band_checks)) {
  cfg <- spectral_band_checks[[check_name]]
  flag_list[[check_name]] <- qc_write_log(
    qc_spectral_band_threshold(spec_joined, wave_cols, spec_id_cols,
                               band = cfg$band, upper = cfg$upper, lower = cfg$lower),
    out_dir, check_name)
}

# ---- SNV spectra for the shape checks (replicate angle, PCA review) ----
stopifnot("only SNV is implemented for the shape checks" = shape_qc_transform$method == "snv")
spec_shape <- snv_over_range(spec_joined, wave_cols, shape_qc_transform$range,
                             keep_cols = c(spec_id_cols, "measure_id"))
shape_cols <- setdiff(names(spec_shape), c(spec_id_cols, "measure_id"))
message(sprintf("Shape checks on SNV spectra, %g-%g nm (%d bands)",
                shape_qc_transform$range[1], shape_qc_transform$range[2], length(shape_cols)))

# Grouping unit = one spectral replicate set (sample x mill treatment x dry
# treatment, ~6 replicates) -- matches how the manuscript's own bootstrap
# procedure treats replicate sets (BootstrapCode.R), and is the level at
# which "the probe wasn't on the sample right for this one scan" would show
# up against its own siblings.
stopifnot("the angle threshold is calibrated as an absolute angle" =
            thresholds$spectral_angle_method == "absolute")
# Called once with a negative threshold to get every non-reference angle, so
# the distribution behind the configured threshold is reported each run.
all_angles <- qc_spectral_group_outliers(spec_shape, "measure_id", shape_cols, spec_id_cols,
                                         min_n = 4,
                                         reference = spectral_angle_reference,
                                         method = "absolute", angle_max_deg = -1)
angle_q <- quantile(all_angles$spectral_angle_deg, c(0.5, 0.95, 0.99, 1))
message(sprintf("Replicate angle to medoid (deg, n=%d): median %.3f, 95th %.3f, 99th %.3f, max %.3f",
                nrow(all_angles), angle_q[1], angle_q[2], angle_q[3], angle_q[4]))
flag_list[["spectral_group_outlier"]] <- qc_write_log(
  all_angles %>%
    filter(spectral_angle_deg > thresholds$spectral_angle_max_deg) %>%
    mutate(threshold = thresholds$spectral_angle_max_deg),
  out_dir, "spectral_group_outlier")

# Splice-jump check: only meaningful on spectra that have NOT been jump
# corrected, because the correction removes the evidence by construction.
# Report whether the file we're reading is already corrected rather than
# silently producing a vacuous all-clear.
jump_status <- qc_detect_jump_corrected(spec_joined, wave_cols, splices = qc_splice_defaults("asd"))
write.csv(jump_status, file.path(out_dir, "spectral_jump_correction_status.csv"), row.names = FALSE)
print(jump_status)
if (any(jump_status$likely_corrected)) {
  message("  spectral_splice_jump: SKIPPED -- these spectra are already jump-corrected.")
  message("  (To run this check, read the uncorrected DrySpec/*.asd binaries; see CLAUDE.md.)")
} else {
  splice_flags <- qc_spectral_splice_jump(spec_joined, wave_cols, spec_id_cols,
                                          splices = qc_splice_defaults("asd"))
  flag_list[["spectral_splice_jump"]] <- qc_write_log(splice_flags, out_dir, "spectral_splice_jump")
}

# PCA review flags, two levels, one global fit, on SNV spectra. Review-only
# by policy.
pca_flags <- qc_spectral_pca_flags(
  spec_shape, shape_cols, spec_id_cols,
  sample_var = "measure_id", group_var = "species_code",
  n_pc = thresholds$pca_n_pc,
  within_z = thresholds$pca_within_z,
  between_z = thresholds$pca_between_z
)
flag_list[["spectral_pca_review"]] <- qc_write_log(pca_flags, out_dir, "spectral_pca_review")

# =========================================================================
# 3. COMBINED REPORT
# =========================================================================
message("\n== Building combined QC report ==")
# unit_col = sample_name so the summary reports distinct samples affected
# alongside raw flag rows. Without it the row counts badly overstate things:
# one bad per-sample chemistry value broadcasts to 18-36 spectrum rows, which
# is how ~96 real sample x trait problems presented as 2772 flags.
check_counts <- qc_build_report(flag_list, out_dir = out_dir, unit_col = "sample_name")

# ---- Broadcast every check's flags down to the per-spectrum grain -------
# The deposit's actual row grain is one row per spectrum (the sidecar).
# Checks above flag at coarser grains (sample_name; sample_name x
# dry_treatment; sample_name x mill_treatment) -- this is the project-
# specific join enspec-qc::qc_build_report() deliberately leaves undone
# (see its docstring). Broadcasting a sample-level flag means every
# spectrum row for that sample/treatment combo inherits the flag, since
# that's the grain the deposit is actually shipped at.
broadcast_to_spectra <- function(flag_df, check_name) {
  # A check that fired on nothing has nothing to broadcast, and a zero-row
  # table carries no columns to inspect -- so bail before the guard below.
  if (is.null(flag_df) || nrow(flag_df) == 0) return(NULL)

  join_cols <- intersect(c("spectra", "sample_name", "dry_treatment", "mill_treatment"), names(flag_df))
  # A flag table must identify WHICH sample it is about. Without `spectra` or
  # `sample_name` the semi_join below matches on treatment alone and silently
  # flags every spectrum in that treatment -- 1188 rows instead of 18, and it
  # looks like a plausible result rather than an error. This bit once, when a
  # new check's table carried `Sample_ID` instead of `sample_name`: the name
  # was intersected away, leaving only `dry_treatment` to join on.
  if (!any(c("spectra", "sample_name") %in% join_cols)) {
    stop(sprintf(
      "check '%s': flag table has no `spectra` or `sample_name` column (has: %s). Broadcasting it would flag every spectrum matching its treatment columns. Rename the sample identifier to `sample_name`.",
      check_name, paste(names(flag_df), collapse = ", ")))
  }
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

# ---- Removals (only checks named in removal_policy) ---------------------
# Two DIFFERENT mechanisms, and conflating them is destructive: trait flag
# tables carry a `spectra` column too (for traceability), so treating every
# removal check as spectrum-level would delete whole spectrum rows because
# one chemistry value was bad. One negative hemicellulose would have taken
# 18 perfectly good spectra with it.
#
#   spectrum-level - the scan itself isn't a measurement of anything
#     (R350 >= 0.9 means the puck or white reference got read; a NIR plateau
#     below 0.3 means the probe wasn't on a sample). Drop the row.
#   trait-level    - one value is impossible but the scan is fine. NA that
#     value only, keep the row.
spectrum_removal_checks <- intersect(
  removal_policy,
  c("spectral_band_threshold", "spectral_nir_plateau_floor", "spectral_flat",
    "spectral_out_of_range")
)
trait_removal_checks <- intersect(removal_policy, c("trait_physical_bounds"))

removal_spectra <- unique(unlist(lapply(spectrum_removal_checks, function(check_name) {
  df <- flag_list[[check_name]]
  if (is.null(df) || nrow(df) == 0 || !"spectra" %in% names(df)) return(character(0))
  df$spectra
})))

removal_log <- bind_rows(lapply(removal_policy, function(check_name) {
  df <- flag_list[[check_name]]
  if (is.null(df) || nrow(df) == 0) return(NULL)
  df %>% mutate(removed_by = check_name, removal_date = Sys.Date())
}))
# When nothing was removed, still write a readable table rather than a 3-byte
# file with no header. "Nothing was removed" is a claim the deposit makes, so
# it should be a file a reader can actually open and see is empty -- an
# unparseable one asserts nothing.
if (nrow(removal_log) == 0) {
  removal_log <- tibble::tibble(spectra = character(0), trait_flagged = character(0),
                                value = double(0), removed_by = character(0),
                                removal_date = as.Date(character(0)))
}
write.csv(removal_log, file.path(out_dir, "removal_log.csv"), row.names = FALSE)

# Trait-level removals: NA the offending VALUE, not the row -- the rest of
# that sample's measurements are fine. Applies to physically impossible
# values only (Henry, 2026-09-23: "any negative values should be dropped and
# logged"). Keyed on spectra so every broadcast copy of the bad value is
# cleared, not just the first.
trait_removals <- bind_rows(flag_list[trait_removal_checks])

if (nrow(trait_removals) > 0) {
  for (tr in unique(trait_removals$trait_flagged)) {
    if (!tr %in% names(sidecar)) next
    hit <- trait_removals$spectra[trait_removals$trait_flagged == tr]
    n_before <- sum(!is.na(sidecar[[tr]]))
    sidecar[[tr]][sidecar$spectra %in% hit] <- NA
    message(sprintf("  removed %s: %d values NA'd (%d -> %d non-missing)",
                    tr, length(unique(hit)), n_before, sum(!is.na(sidecar[[tr]]))))
  }
  message(sprintf("Trait values dropped as physically impossible: %d rows across %d trait(s)",
                  nrow(trait_removals), length(unique(trait_removals$trait_flagged))))
} else {
  message("No physically impossible trait values to drop.")
}

message(sprintf("\nRemoval policy: %s", paste(removal_policy, collapse = ", ")))
message(sprintf("Spectra removed (whole rows): %d", length(removal_spectra)))

# Deposit-ready sidecar copy with the flag columns carried in, alongside
# (not replacing) the original spectral_metadata_sidecar.csv -- per the QC
# standard's "flag columns carried into the deposit" output contract.
sidecar_with_flags <- sidecar %>%
  select(-species_dry_treatment, -growth_form_mill_treatment, -measure_id) %>%
  left_join(quality_flag_by_spectrum, by = "spectra") %>%
  filter(!spectra %in% removal_spectra)

write.csv(sidecar_with_flags, file.path(out_dir, "spectral_metadata_sidecar_with_qc_flags.csv"), row.names = FALSE)

# If anything was removed, the spectra themselves have to be filtered to
# match, or the deposit would ship a spectrum with no metadata row.
if (length(removal_spectra) > 0) {
  spec_clean <- spec_raw %>% filter(!spectra %in% removal_spectra)
  write.csv(spec_clean, file.path(out_dir, "spectra_qc_cleaned.csv"), row.names = FALSE)
  message(sprintf("Wrote spectra_qc_cleaned.csv (%d of %d spectra retained)",
                  nrow(spec_clean), nrow(spec_raw)))
} else {
  message("No spectra removed -- the existing spectral files need no filtering.")
}

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
message(sprintf("Policy: flag-only except %s (see removal_log.csv).",
                paste(removal_policy, collapse = ", ")))
message(sprintf("  spectra dropped (whole rows): %d | trait values NA'd: %d",
                length(removal_spectra), nrow(trait_removals)))
