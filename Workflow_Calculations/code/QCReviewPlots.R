##################################################
#
# Title: QC Review Plots (spectral shape flags)
#
# Project: Mill Test 2024
#
# Purpose: Plot every spectrum carrying a spectral shape flag
# (spectral_group_outlier = replicate angle to the medoid; spectral_pca_review
# = within-sample and between-sample PCA distance) so a reviewer can decide
# whether each one is a bad scan to remove or a real spectrum to keep with its
# flag. One page per replicate set (sample x mill treatment x dry treatment,
# ~6 scans). Ported from the ACRES review step (step3_qc_review_plots.R).
#
# Top panel: SNV spectra over the range the shape checks use (the basis for
# review). Bottom panel: reflectance, for context.
#   - some scans in the set flagged: flagged scans in colour against the set's
#     other scans (grey);
#   - whole set flagged (PCA between-sample, or every scan flagged): the set's
#     scans in colour against the other replicate sets of the same species,
#     mill treatment and drying treatment (grey).
#
# Also writes a decisions template (one row per spectrum on a reviewed page).
# Fill in `decision` (keep_flag / remove / discuss) and save it as
# review_decisions_file below; a re-run keeps any decisions already entered.
#
# Run after TraitSpectralQC.R, from the repo root:
#   Rscript Workflow_Calculations/code/QCReviewPlots.R
#
# Outputs go to derived/qc_review/, NOT derived/qc/, because
# TraitSpectralQC.R clears derived/qc/ at the start of each run.
#
# Author: Henry Frye (with Claude Code), 2026-10-19
#
##################################################

library(tidyverse)
library(cowplot)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
qc_lib_path <- Sys.getenv("ENSPEC_QC_PATH", unset = "/Users/henryfrye/enspec/enspec-qc")
source(file.path(qc_lib_path, "R", "spectral_transforms.R"))  # snv_over_range()

# Must match shape_qc_transform in qc_config_milltest.R
shape_range <- c(400, 2450)
asd_splices <- c(1000, 1800)

qc_dir  <- file.path(data_root, "derived", "qc")
out_dir <- file.path(data_root, "derived", "qc_review")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
out_pdf <- file.path(out_dir, "qc_review_plots.pdf")
review_decisions_file <- file.path(out_dir, "qc_review_decisions.csv")

# --- flags -------------------------------------------------------------------
angle <- read.csv(file.path(qc_dir, "spectral_group_outlier_flags.csv"))
pca   <- read.csv(file.path(qc_dir, "spectral_pca_review_flags.csv"))

# Per-spectrum flag text. Between-sample PCA flags are on a whole replicate
# set (measure_id) and carry no spectrum id.
spec_flags <- bind_rows(
  angle %>% transmute(spectra, flag = "spectral_group_outlier",
                      detail = sprintf("angle %.2f deg", spectral_angle_deg)),
  pca %>% filter(level == "within_sample") %>%
    transmute(spectra, flag = "spectral_pca_review",
              detail = sprintf("within-sample PCA z %.1f", distance_robust_z))
) %>%
  group_by(spectra) %>%
  summarise(qc_flags = paste(unique(flag), collapse = "; "),
            detail = paste(detail, collapse = "; "), .groups = "drop")

between <- pca %>% filter(level == "between_sample") %>%
  transmute(measure_id, between_detail = sprintf("between-sample PCA z %.1f", distance_robust_z))

# --- spectra -----------------------------------------------------------------
sidecar <- read.csv(file.path(data_root, "derived", "ecosis", "spectral_metadata_sidecar.csv")) %>%
  select(spectra, sample_name, species_code, mill_treatment, dry_treatment, replicate)
sidecar <- sidecar %>%
  mutate(measure_id = paste(sample_name, mill_treatment, dry_treatment, sep = "_"))
# measure_id format used by TraitSpectralQC.R (sample_MILL_DRY). Check it
# against the PCA table rather than assume.
stopifnot("measure_id format differs from TraitSpectralQC.R" =
            all(pca$measure_id %in% sidecar$measure_id))

spec <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_raw_spectra.csv"),
                 check.names = FALSE)
names(spec)[1] <- "spectra"
wave_cols <- grep("^X[0-9]+$", names(spec), value = TRUE)
spec <- spec %>% filter(spectra %in% sidecar$spectra)

to_long <- function(df, value) {
  df %>%
    pivot_longer(-spectra, names_to = "wavelength", values_to = value) %>%
    mutate(wavelength = as.numeric(gsub("[^0-9.]", "", wavelength)))
}
snv <- snv_over_range(spec %>% select(spectra, all_of(wave_cols)), wave_cols, shape_range, "spectra")
long <- to_long(spec %>% select(spectra, all_of(wave_cols)), "reflectance") %>%
  left_join(to_long(snv, "snv"), by = c("spectra", "wavelength")) %>%
  left_join(sidecar, by = "spectra") %>%
  left_join(spec_flags, by = "spectra") %>%
  mutate(n_flags = if_else(is.na(qc_flags), 0L, 1L))

# --- review units: replicate sets with any flag --------------------------------
sets <- sidecar %>%
  group_by(measure_id) %>%
  summarise(n_reps = n(), .groups = "drop") %>%
  left_join(spec_flags %>% left_join(sidecar, by = "spectra") %>%
              count(measure_id, name = "n_flagged"), by = "measure_id") %>%
  left_join(between, by = "measure_id") %>%
  mutate(n_flagged = replace_na(n_flagged, 0L),
         between_sample = !is.na(between_detail)) %>%
  filter(n_flagged > 0 | between_sample) %>%
  arrange(measure_id)

# One label per scan for the legend.
scan_labels <- long %>% distinct(spectra, qc_flags, detail, measure_id) %>%
  mutate(label = if_else(is.na(qc_flags), paste0(spectra, " (not flagged)"),
                         paste0(spectra, ": ", qc_flags, " [", detail, "]")))

splice_lines <- geom_vline(xintercept = asd_splices + 0.5, linetype = "dashed",
                           colour = "grey40", linewidth = 0.3)

plot_set <- function(mid) {
  s <- sets %>% filter(measure_id == mid)
  own <- long %>% filter(measure_id == mid)
  sp <- own$species_code[1]
  whole_set <- s$between_sample || s$n_flagged == s$n_reps

  if (!whole_set) {
    grey <- own %>% filter(n_flags == 0)
    colored <- own %>% filter(n_flags > 0)
    subtitle <- sprintf("%d of %d scans flagged; grey = the set's unflagged scans", s$n_flagged, s$n_reps)
  } else {
    grey <- long %>% filter(species_code == sp, measure_id != mid,
                            mill_treatment == own$mill_treatment[1],
                            dry_treatment == own$dry_treatment[1])
    colored <- own
    subtitle <- sprintf("Whole set flagged (%d of %d scans%s); grey = other %s sets, same mill and dry treatment (n = %d sets)",
                        s$n_flagged, s$n_reps,
                        if (s$between_sample) paste0(", ", s$between_detail) else "",
                        sp, n_distinct(grey$measure_id))
  }
  labs_i <- scan_labels %>% filter(measure_id == mid)
  grey_col <- if (whole_set) "grey80" else "grey70"

  panel <- function(y, ylab, filt = identity) {
    ggplot() +
      geom_line(data = filt(grey), aes(wavelength, .data[[y]], group = spectra),
                colour = grey_col, linewidth = 0.35) +
      geom_line(data = filt(colored), aes(wavelength, .data[[y]], colour = spectra), linewidth = 0.6) +
      splice_lines +
      scale_colour_discrete(breaks = labs_i$spectra, labels = str_wrap(labs_i$label, 95),
                            name = NULL, drop = FALSE) +
      labs(x = "Wavelength (nm)", y = ylab) +
      theme_bw(base_size = 10)
  }
  p_snv  <- panel("snv", sprintf("SNV (%g-%g nm)", shape_range[1], shape_range[2]),
                  function(d) filter(d, !is.na(snv))) + labs(x = NULL) +
    theme(legend.position = "bottom", legend.direction = "vertical", legend.text = element_text(size = 7))
  p_refl <- panel("reflectance", "Reflectance") + theme(legend.position = "none")

  title <- ggdraw() + draw_label(sprintf("%s  |  %s", mid, sp), fontface = "bold", x = 0.01, hjust = 0, size = 12) +
    draw_label(subtitle, x = 0.01, y = 0.15, hjust = 0, size = 8)
  cap <- ggdraw() + draw_label(
    "Top: SNV spectra, the basis for review. Bottom: reflectance. Dashed: detector splices (1000|1001, 1800|1801 nm); spectra are jump-corrected.",
    x = 0.01, hjust = 0, size = 7)
  leg <- get_legend(p_snv)
  plot_grid(title,
            plot_grid(p_snv + theme(legend.position = "none"), p_refl, ncol = 1, rel_heights = c(2, 1), align = "v"),
            leg, cap, ncol = 1, rel_heights = c(0.08, 1, 0.22, 0.04))
}

pdf(out_pdf, width = 10, height = 9)
for (mid in sets$measure_id) print(plot_set(mid))
invisible(dev.off())

# --- decisions template ----------------------------------------------------------
# One row per spectrum on a reviewed page: flagged scans, plus every scan of a
# set flagged as a whole at the between-sample level.
template <- sidecar %>%
  filter(measure_id %in% sets$measure_id) %>%
  left_join(spec_flags, by = "spectra") %>%
  left_join(between, by = "measure_id") %>%
  filter(!is.na(qc_flags) | !is.na(between_detail)) %>%
  mutate(qc_flags = case_when(
           !is.na(qc_flags) & !is.na(between_detail) ~ paste0(qc_flags, "; spectral_pca_review (between_sample)"),
           !is.na(between_detail) ~ "spectral_pca_review (between_sample)",
           TRUE ~ qc_flags),
         detail = case_when(
           !is.na(detail) & !is.na(between_detail) ~ paste0(detail, "; ", between_detail),
           !is.na(between_detail) ~ between_detail,
           TRUE ~ detail)) %>%
  mutate(plot_page = match(measure_id, sets$measure_id)) %>%
  select(spectra, measure_id, plot_page, qc_flags, detail) %>%
  distinct()

existing <- if (file.exists(review_decisions_file)) read.csv(review_decisions_file, colClasses = "character") else NULL
template <- template %>%
  left_join(if (is.null(existing)) tibble(spectra = character(0), decision = character(0), reviewer = character(0),
                                          review_date = character(0), rationale = character(0))
            else existing %>% select(spectra, decision, reviewer, review_date, rationale),
            by = "spectra") %>%
  mutate(across(c(decision, reviewer, review_date, rationale), ~ replace_na(.x, ""))) %>%
  arrange(plot_page, spectra)
write.csv(template, file.path(out_dir, "qc_review_decisions_template.csv"), row.names = FALSE)

message(sprintf("Wrote %s: %d pages (%d sets with some scans flagged, %d whole-set)",
                out_pdf, nrow(sets),
                sum(!(sets$between_sample | sets$n_flagged == sets$n_reps)),
                sum(sets$between_sample | sets$n_flagged == sets$n_reps)))
message(sprintf("Decisions template: %s (%d spectra). Copy to %s and fill decision = keep_flag / remove / discuss.",
                file.path(out_dir, "qc_review_decisions_template.csv"), nrow(template), review_decisions_file))
