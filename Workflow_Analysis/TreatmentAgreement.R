########################################
#
# Title: Treatment agreement and reference-offset sensitivity
#
# Project: Mill Test 2024
#
# Date: 2026-10-12
#
# Why this script exists
# ----------------------
# Chemistry was assayed once per tree, on oven-dried (OD) 20-mesh material
# (Brookside). ChemistryAnalysis.R scores every drying x milling treatment's
# spectral prediction against that single reference, so a lower NRMSE means
# "closer to the OD 20-mesh chemistry", not "more accurate". Neither drying
# method gives a true value (oven drying can volatilize carbon; freeze-drying
# under vacuum can too), so this script asks what the design can and cannot
# support, using only data already in hand:
#
#   1. Agreement with the common reference, per treatment cell: Lin's
#      concordance correlation coefficient (CCC) split into precision (r) and
#      accuracy (Cb), plus Bland-Altman bias and limits of agreement, and RMSE
#      split into bias^2 + scatter^2.
#   2. Break-even offset: how large a treatment-specific difference between
#      the true concentration of a freeze-dried (FF) sample and the OD
#      reference would have to be to erase the FF NRMSE advantage. Compared
#      with the FF - OD offset actually measured on the isotope pairs (n = 11)
#      and, for calcium, with proxy bounds scaled from the measured N and C
#      offsets (Ca is not volatile, so no direct offset estimate exists).
#   3. Reference-free treatment agreement: FF vs OD (within milling treatment)
#      and milling vs milling (within drying treatment) predicted values for
#      the same tree.
#   4. Within-tree check: does the model recover the measured FF - OD shift in
#      N on the isotope pairs?
#   5. IRMS (OD) vs Brookside N on the same trees: the offset between the
#      isotope and reference assays.
#
# Assumptions to state wherever these results are quoted
# ------------------------------------------------------
# * The OD cells are taken to have zero offset from the OD 20-mesh reference
#   (same material class); only the differential FF - OD offset is varied.
# * One offset is applied to a whole FF cell (a constant shift of its
#   reference). A concentration-dependent offset is explored only through the
#   relative-offset scenarios.
# * The isotope aliquots' milling treatment is not recorded in the extract
#   (IsotopeExtract.R); ball-mill only is believed but unconfirmed, so the
#   within-tree check is reported for all three milling treatments.
# * n = 11 isotope pairs: the offset CI is wide and N and C only.
#
# Lin's CCC is coded here (not epiR) to avoid a new renv dependency; it
# follows Lin (1989) with the z-transform interval used by epiR::epi.ccc.
#
########################################

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "treatment_agreement")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- helpers ------------------------------------------------------------

# Lin's concordance correlation coefficient with a z-transform 95% CI.
# Population (n) variances in the CCC itself, as in Lin (1989).
lin_ccc <- function(x, y) {
  ok <- complete.cases(x, y)
  x <- x[ok]; y <- y[ok]
  n <- length(x)
  mx <- mean(x); my <- mean(y)
  sx2 <- mean((x - mx)^2); sy2 <- mean((y - my)^2)
  sxy <- mean((x - mx) * (y - my))
  r   <- sxy / sqrt(sx2 * sy2)
  ccc <- 2 * sxy / (sx2 + sy2 + (mx - my)^2)
  u   <- (mx - my) / (sx2 * sy2)^0.25
  v   <- ((1 - r^2) * ccc^2 * (1 - ccc^2) / r^2 +
            4 * ccc^3 * (1 - ccc) * u^2 / r -
            2 * ccc^4 * u^4 / r^2) / (n - 2)
  z    <- atanh(ccc)
  se_z <- sqrt(v) / (1 - ccc^2)
  tibble(n = n, ccc = ccc, r = r, Cb = ccc / r,
         ccc_lo = tanh(z - 1.96 * se_z), ccc_hi = tanh(z + 1.96 * se_z))
}

# Bland-Altman summary of a - b.
ba_summary <- function(a, b) {
  d <- a - b
  d <- d[!is.na(d)]
  tibble(bias = mean(d), sd_diff = sd(d),
         loa_lo = mean(d) - 1.96 * sd(d), loa_hi = mean(d) + 1.96 * sd(d))
}

# --- inputs ---------------------------------------------------------------

# Same sources and conventions as ChemistryAnalysis.R: predictions averaged
# over the replicate scans of each sample x treatment; one Brookside assay per
# tree, % dry mass -> mg/g.
predicted <- read.csv(file.path(data_root, "spectralpredictr",
                                "DimensionsDryTraitPredictions.csv")) %>%
  mutate(sample_name = substring(sampledata_head, 1, 19)) %>%
  group_by(sample_name) %>%
  summarise(Nitrogen = mean(t_mean_Nitrogen, na.rm = TRUE),
            Calcium  = mean(t_mean_Calcium,  na.rm = TRUE),
            .groups = "drop") %>%
  mutate(Sample_ID = substring(sample_name, 1, 11),
         Drying    = substring(sample_name, 13, 14),   # OD / FF
         Milling   = substring(sample_name, 16, 19),   # TWEN / BALL / SIXT
         cell      = paste(Drying, Milling, sep = "_"))

brookside <- read.csv(file.path(data_root, "ChemResults", "Brookside.csv"),
                      fileEncoding = "UTF-8-BOM") %>%
  transmute(Sample_ID,
            Nitrogen    = as.numeric(as.character(Nitrogen)) * 10,
            Calcium     = as.numeric(as.character(Calcium))  * 10,
            Phosphorous = as.numeric(as.character(Phosphorous)))

# The 60 trees ChemistryAnalysis.R scores (those with a complete assay row).
ref_trees <- brookside %>% filter(!is.na(Phosphorous)) %>% pull(Sample_ID)

chem_long <- predicted %>%
  pivot_longer(c(Nitrogen, Calcium), names_to = "Trait",
               values_to = "Predicted") %>%
  inner_join(brookside %>%
               filter(Sample_ID %in% ref_trees) %>%
               pivot_longer(c(Nitrogen, Calcium), names_to = "Trait",
                            values_to = "Observed"),
             join_by(Sample_ID, Trait))

isotope <- read.csv(file.path(data_root, "derived", "isotope",
                              "isotope_mill_test.csv"))

# --- 1. agreement with the OD 20-mesh reference, per cell -----------------

cell_agreement <- chem_long %>%
  group_by(Trait, Drying, Milling) %>%
  group_modify(~ {
    d <- .x$Predicted - .x$Observed
    bind_cols(
      lin_ccc(.x$Observed, .x$Predicted),
      ba_summary(.x$Predicted, .x$Observed),
      tibble(mean_obs  = mean(.x$Observed),
             mean_pred = mean(.x$Predicted),
             rmse      = sqrt(mean(d^2)),
             # RMSE^2 = bias^2 + scatter^2 (population SD of the error).
             # "scatter" is the bias-corrected error SD (SEP in chemometrics)
             # and still contains proportionality (slope) error.
             scatter   = sqrt(mean((d - mean(d))^2)),
             obs_range = diff(range(.x$Observed)),
             # Willmott (1981) / Robeson & Willmott (2023) frame: regress
             # predicted on observed. MSE = bias^2 + proportionality +
             # unsystematic, where scatter^2 = proportionality + unsystematic.
             slope_pred_on_obs = unname(coef(lm(Predicted ~ Observed,
                                                data = .x))[2]),
             mse_prop  = (slope_pred_on_obs - 1)^2 *
               mean((.x$Observed - mean(.x$Observed))^2),
             mse_unsys = mean(resid(lm(Predicted ~ Observed, data = .x))^2))
    )
  }) %>%
  ungroup() %>%
  mutate(nrmse = rmse / obs_range,
         bias_share_of_mse = bias^2 / rmse^2,
         prop_share_of_mse = mse_prop / rmse^2,
         unsys_share_of_mse = mse_unsys / rmse^2,
         rmse_unsys = sqrt(mse_unsys),
         nrmse_unsys = rmse_unsys / obs_range)

print(cell_agreement %>%
        select(Trait, Drying, Milling, n, ccc, ccc_lo, ccc_hi, r, Cb, bias,
               loa_lo, loa_hi, rmse, nrmse, bias_share_of_mse),
      n = Inf, width = Inf)
write.csv(cell_agreement, file.path(out_dir, "cell_agreement.csv"),
          row.names = FALSE)

# --- measured FF - OD offsets on the isotope pairs --------------------

pairs_wide <- isotope %>%
  select(Sample_ID, dry_treatment, nitrogen_IRMS_mg_g, carbon_mg_g) %>%
  pivot_wider(names_from = dry_treatment,
              values_from = c(nitrogen_IRMS_mg_g, carbon_mg_g)) %>%
  filter(complete.cases(.))

offset_row <- function(ff, od, what) {
  d  <- ff - od
  tt <- t.test(d)
  rel <- ff / od - 1
  tr  <- t.test(rel)
  tibble(measure = what, n = length(d),
         mean_ff = mean(ff), mean_od = mean(od),
         offset = mean(d), offset_lo = tt$conf.int[1], offset_hi = tt$conf.int[2],
         p_value = tt$p.value, n_negative = sum(d < 0),
         rel_offset = mean(rel), rel_lo = tr$conf.int[1], rel_hi = tr$conf.int[2])
}

isotope_offsets <- bind_rows(
  offset_row(pairs_wide$nitrogen_IRMS_mg_g_FF, pairs_wide$nitrogen_IRMS_mg_g_OD,
             "Nitrogen (IRMS, mg/g)"),
  offset_row(pairs_wide$carbon_mg_g_FF, pairs_wide$carbon_mg_g_OD,
             "Carbon (mg/g)")
)
print(isotope_offsets, width = Inf)
write.csv(isotope_offsets, file.path(out_dir, "isotope_pair_offsets.csv"),
          row.names = FALSE)

# --- 2. break-even reference offset ------------------------------------
# Let the true FF concentration be (OD reference + delta). The FF cell's error
# becomes (pred - obs - delta), so
#     RMSE_FF(delta)^2 = scatter_FF^2 + (bias_FF - delta)^2.
# FF still beats its OD counterpart (same milling treatment) while
#     |bias_FF - delta| < sqrt(RMSE_OD^2 - scatter_FF^2),
# i.e. for delta in (bias_FF - s, bias_FF + s). delta = 0 is the analysis as
# published.

ff_cells <- cell_agreement %>% filter(Drying == "FF")
od_cells <- cell_agreement %>% filter(Drying == "OD") %>%
  select(Trait, Milling, rmse_od = rmse, nrmse_od = nrmse)

break_even <- ff_cells %>%
  left_join(od_cells, join_by(Trait, Milling)) %>%
  mutate(s2 = rmse_od^2 - scatter^2,
         advantage_possible = s2 > 0,
         delta_lo = ifelse(advantage_possible, bias - sqrt(pmax(s2, 0)), NA_real_),
         delta_hi = ifelse(advantage_possible, bias + sqrt(pmax(s2, 0)), NA_real_),
         rmse_gain_at_zero = rmse_od - rmse,
         # same interval as % of the mean observed concentration
         delta_lo_pct = 100 * delta_lo / mean_obs,
         delta_hi_pct = 100 * delta_hi / mean_obs) %>%
  select(Trait, Milling, mean_obs, bias, scatter, rmse_ff = rmse, rmse_od,
         nrmse_ff = nrmse, nrmse_od, rmse_gain_at_zero, advantage_possible,
         delta_lo, delta_hi, delta_lo_pct, delta_hi_pct)

# Offsets to compare against. N has a direct estimate (absolute, and scaled by
# the relative offset to the 60-tree mean). Ca does not: proxy scenarios scale
# the measured relative C and N offsets to the mean observed Ca.
mean_obs_trait <- cell_agreement %>%
  group_by(Trait) %>% summarise(mean_obs = mean(mean_obs), .groups = "drop")
mean_n  <- mean_obs_trait$mean_obs[mean_obs_trait$Trait == "Nitrogen"]
mean_ca <- mean_obs_trait$mean_obs[mean_obs_trait$Trait == "Calcium"]
n_off <- isotope_offsets %>% filter(str_starts(measure, "Nitrogen"))
c_off <- isotope_offsets %>% filter(str_starts(measure, "Carbon"))

scenarios <- tribble(
  ~Trait,     ~scenario,                               ~delta,                   ~lo,                   ~hi,
  "Nitrogen", "Measured N offset (absolute, n=11)",    n_off$offset,             n_off$offset_lo,       n_off$offset_hi,
  "Nitrogen", "Measured N offset (relative x mean N)", n_off$rel_offset * mean_n, n_off$rel_lo * mean_n,  n_off$rel_hi * mean_n,
  "Calcium",  "Proxy: measured C relative offset",     c_off$rel_offset * mean_ca, c_off$rel_lo * mean_ca, c_off$rel_hi * mean_ca,
  "Calcium",  "Proxy: measured N relative offset",     n_off$rel_offset * mean_ca, n_off$rel_lo * mean_ca, n_off$rel_hi * mean_ca
)

break_even_vs_measured <- break_even %>%
  inner_join(scenarios, join_by(Trait), relationship = "many-to-many") %>%
  mutate(point_inside = delta > delta_lo & delta < delta_hi,
         ci_inside    = lo > delta_lo & hi < delta_hi,
         # RMSE the FF cell would have at the scenario's point offset
         nrmse_ff_at_delta = sqrt(scatter^2 + (bias - delta)^2) /
           (rmse_ff / nrmse_ff))

print(break_even_vs_measured %>%
        select(Trait, Milling, scenario, delta, lo, hi, delta_lo, delta_hi,
               point_inside, ci_inside, nrmse_ff, nrmse_ff_at_delta, nrmse_od),
      n = Inf, width = Inf)
write.csv(break_even, file.path(out_dir, "break_even_offsets.csv"),
          row.names = FALSE)
write.csv(break_even_vs_measured,
          file.path(out_dir, "break_even_vs_measured.csv"), row.names = FALSE)

# --- 3. reference-free treatment agreement -----------------------------

pred_wide <- predicted %>%
  select(Sample_ID, Nitrogen, Calcium, cell) %>%
  pivot_longer(c(Nitrogen, Calcium), names_to = "Trait", values_to = "value") %>%
  pivot_wider(names_from = cell, values_from = value)

contrasts <- bind_rows(
  # drying contrast, within milling treatment (FF vs OD)
  tibble(a = paste0("FF_", c("BALL", "SIXT", "TWEN")),
         b = paste0("OD_", c("BALL", "SIXT", "TWEN")),
         type = "drying"),
  # milling contrasts, within drying treatment
  expand_grid(dry = c("FF", "OD"),
              pair = list(c("BALL", "SIXT"), c("BALL", "TWEN"), c("SIXT", "TWEN"))) %>%
    transmute(a = paste0(dry, "_", map_chr(pair, 1)),
              b = paste0(dry, "_", map_chr(pair, 2)),
              type = "milling")
)

treatment_concordance <- expand_grid(Trait = c("Nitrogen", "Calcium"),
                                     contrasts) %>%
  mutate(res = pmap(list(Trait, a, b), function(tr, a, b) {
    d <- pred_wide %>% filter(Trait == tr)
    bind_cols(lin_ccc(d[[a]], d[[b]]), ba_summary(d[[a]], d[[b]]))
  })) %>%
  unnest(res) %>%
  rename(bias_a_minus_b = bias)

print(treatment_concordance, n = Inf, width = Inf)
write.csv(treatment_concordance,
          file.path(out_dir, "treatment_contrast_concordance.csv"),
          row.names = FALSE)

# --- 4. within-tree check on the isotope pairs ------------------------
# Predicted FF - OD shift in N vs the measured FF - OD shift, same trees.

meas_shift <- pairs_wide %>%
  transmute(Sample_ID, measured_shift = nitrogen_IRMS_mg_g_FF - nitrogen_IRMS_mg_g_OD)

within_tree <- map_dfr(c("BALL", "SIXT", "TWEN"), function(m) {
  d <- predicted %>%
    filter(Milling == m) %>%
    select(Sample_ID, Drying, Nitrogen) %>%
    pivot_wider(names_from = Drying, values_from = Nitrogen) %>%
    transmute(Sample_ID, predicted_shift = FF - OD) %>%
    inner_join(meas_shift, join_by(Sample_ID)) %>%
    filter(complete.cases(.))
  e  <- d$predicted_shift - d$measured_shift
  tt <- t.test(e)
  bind_cols(
    tibble(Milling = m,
           mean_predicted_shift = mean(d$predicted_shift),
           mean_measured_shift  = mean(d$measured_shift),
           mean_error = mean(e), error_lo = tt$conf.int[1],
           error_hi = tt$conf.int[2], sd_error = sd(e)),
    lin_ccc(d$measured_shift, d$predicted_shift)
  )
})
print(within_tree, width = Inf)
write.csv(within_tree, file.path(out_dir, "within_tree_ff_od_shift_N.csv"),
          row.names = FALSE)

# --- 5. IRMS (OD) vs Brookside N on the same trees ----------------------

irms_vs_brookside <- isotope %>%
  filter(dry_treatment == "OD") %>%
  select(Sample_ID, irms = nitrogen_IRMS_mg_g) %>%
  inner_join(brookside %>% select(Sample_ID, brookside = Nitrogen),
             join_by(Sample_ID)) %>%
  filter(complete.cases(.))

irms_check <- bind_cols(
  lin_ccc(irms_vs_brookside$brookside, irms_vs_brookside$irms),
  ba_summary(irms_vs_brookside$irms, irms_vs_brookside$brookside)
) %>% rename(bias_irms_minus_brookside = bias)
print(irms_check, width = Inf)
write.csv(irms_check, file.path(out_dir, "irms_vs_brookside_N.csv"),
          row.names = FALSE)

# --- figures --------------------------------------------------------------
# Okabe-Ito colors (colorblind-safe); no red/green coding.

col_ff <- "#0072B2"
col_od <- "#E69F00"
mill_names <- c(BALL = "Ball milled", SIXT = "Fine mesh", TWEN = "20 mesh")

for (trait in c("Nitrogen", "Calcium")) {
  unit <- "mg g⁻¹"

  # break-even curves
  grid <- ff_cells %>% filter(Trait == trait) %>%
    left_join(od_cells, join_by(Trait, Milling)) %>%
    group_by(Milling) %>%
    reframe(delta = seq(-0.35, 0.35, length.out = 281) * obs_range,
            nrmse = sqrt(scatter^2 + (bias - delta)^2) / obs_range,
            nrmse_od = nrmse_od)
  bands <- scenarios %>% filter(Trait == trait)

  p_be <- ggplot(grid, aes(delta, nrmse)) +
    geom_rect(data = bands, inherit.aes = FALSE,
              aes(xmin = lo, xmax = hi, ymin = -Inf, ymax = Inf, fill = scenario),
              alpha = 0.25) +
    geom_vline(xintercept = 0, linetype = "dotted") +
    geom_line(color = col_ff, linewidth = 0.9) +
    geom_hline(aes(yintercept = nrmse_od), color = col_od, linewidth = 0.9) +
    facet_wrap(~ Milling, labeller = as_labeller(mill_names)) +
    scale_fill_manual(values = c("grey40", "grey70")[seq_len(nrow(bands))],
                      name = "Offset estimate (95% CI)") +
    labs(x = paste0("Assumed true FF − OD reference offset (", unit, ")"),
         y = paste0("NRMSE of freeze-dried prediction (", trait, ")")) +
    theme_minimal(base_size = 11) +
    theme(legend.position = "bottom", legend.direction = "vertical")
  ggsave(file.path(out_dir, paste0("break_even_", tolower(trait), ".png")),
         p_be, width = 7.5, height = 4.8, dpi = 300, bg = "white")

  # Bland-Altman per cell
  ba <- chem_long %>% filter(Trait == trait) %>%
    mutate(mean_val = (Predicted + Observed) / 2, diff = Predicted - Observed)
  ba_stats <- cell_agreement %>% filter(Trait == trait)
  p_ba <- ggplot(ba, aes(mean_val, diff, color = Drying)) +
    geom_hline(data = ba_stats, aes(yintercept = bias), color = "black") +
    geom_hline(data = ba_stats, aes(yintercept = loa_lo),
               linetype = "dashed", color = "grey40") +
    geom_hline(data = ba_stats, aes(yintercept = loa_hi),
               linetype = "dashed", color = "grey40") +
    geom_point(alpha = 0.7, size = 1.5) +
    facet_grid(Drying ~ Milling, labeller = labeller(Milling = mill_names)) +
    scale_color_manual(values = c(FF = col_ff, OD = col_od), guide = "none") +
    labs(x = paste0("Mean of predicted and observed ", trait, " (", unit, ")"),
         y = paste0("Predicted − observed (", unit, ")")) +
    theme_minimal(base_size = 11)
  ggsave(file.path(out_dir, paste0("bland_altman_", tolower(trait), ".png")),
         p_ba, width = 7.5, height = 5, dpi = 300, bg = "white")
}

message("Done. Outputs in ", out_dir)
