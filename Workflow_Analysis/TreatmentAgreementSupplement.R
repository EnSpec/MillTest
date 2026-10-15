########################################
#
# Title: Supplement tables and figures for the treatment-agreement analysis
#
# Project: Mill Test 2024
#
# Date: 2026-10-15
#
# Formats the outputs of TreatmentAgreement.R (run that first) as editable
# Word tables and PNG figures. Working names only; renumber to the
# manuscript's supplement order:
#
#   Tables  (treatment_agreement_supplement_tables.docx)
#     T1  Agreement with the OD 20-mesh reference, per treatment cell
#     T2  Measured FF - OD offsets (isotope pairs)
#     T3  Break-even reference offsets vs measured / proxy offsets
#     T4  Within-tree FF - OD shift in N: predicted vs measured
#     T5  IRMS vs Brookside nitrogen on the same oven-dried trees
#     T6  Reference-free treatment contrasts (predicted values)
#   Figures (PNG, 300 dpi)
#     F1  Break-even curves (nitrogen, calcium)
#     F2  Bland-Altman plots per treatment cell
#     F3  Paired FF vs OD isotope measurements
#
########################################

library(tidyverse)
library(flextable)
library(officer)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
dir_in <- file.path(data_root, "derived", "treatment_agreement")

read_in <- function(f) read.csv(file.path(dir_in, f))
cell   <- read_in("cell_agreement.csv")
bem    <- read_in("break_even_vs_measured.csv")
off    <- read_in("isotope_pair_offsets.csv")
within <- read_in("within_tree_ff_od_shift_N.csv")
irms   <- read_in("irms_vs_brookside_N.csv")
contr  <- read_in("treatment_contrast_concordance.csv")
pt     <- read_in("per_tree_predicted_vs_observed.csv")
iso    <- read.csv(file.path(data_root, "derived", "isotope",
                             "isotope_mill_test.csv"))

dry_lab  <- c(FF = "Freeze-dried", OD = "Oven-dried")
mill_lab <- c(BALL = "Ball milled", SIXT = "Fine mesh", TWEN = "20 mesh")

f2  <- function(x) formatC(x, digits = 2, format = "f")
f1  <- function(x) formatC(x, digits = 1, format = "f")
pct <- function(x) paste0(f1(100 * x))
ci  <- function(m, lo, hi, d = 2)
  sprintf(paste0("%.", d, "f (%.", d, "f, %.", d, "f)"), m, lo, hi)
yn  <- function(x) ifelse(x, "Yes", "No")

# --- tables ---------------------------------------------------------------

t1 <- cell %>%
  arrange(Trait, Drying, Milling) %>%
  transmute(Trait,
            Drying  = dry_lab[Drying],
            Milling = mill_lab[Milling],
            `RMSE (mg/g)`   = f2(rmse),
            `NRMSE (%)`     = pct(nrmse),
            `Bias (mg/g)`   = f2(bias),
            `Slope (pred. on obs.)` = f2(slope_pred_on_obs),
            `Bias (% of MSE)`           = pct(bias_share_of_mse),
            `Proportionality (% of MSE)` = pct(prop_share_of_mse),
            `Unsystematic (% of MSE)`    = pct(unsys_share_of_mse),
            `Precision (ρ)` = f2(r),
            `Accuracy (Cb)`    = f2(Cb),
            `CCC (95% CI)`     = ci(ccc, ccc_lo, ccc_hi),
            `95% limits of agreement (mg/g)` =
              sprintf("%.1f to %.1f", loa_lo, loa_hi))

t2 <- off %>%
  transmute(Measure = measure, n,
            `Oven-dried mean` = f1(mean_od),
            `Freeze-dried mean` = f1(mean_ff),
            `FF − OD (95% CI)` = ci(offset, offset_lo, offset_hi, 2),
            `Relative FF − OD, % (95% CI)` =
              sprintf("%.1f (%.1f, %.1f)", 100 * rel_offset, 100 * rel_lo,
                      100 * rel_hi),
            `Paired t-test p` = ifelse(p_value < 0.001, "<0.001", f2(p_value)),
            `Trees lower in FF` = paste0(n_negative, " of ", n))

t3 <- bem %>%
  arrange(Trait, scenario, Milling) %>%
  transmute(Trait,
            Milling = mill_lab[Milling],
            `FF beats OD for offsets (mg/g)` =
              sprintf("%.1f to %.1f", delta_lo, delta_hi),
            `Offset estimate` = scenario,
            `Offset (95% CI, mg/g)` = ci(delta, lo, hi, 2),
            `Point estimate inside` = yn(point_inside),
            `Whole CI inside` = yn(ci_inside),
            `FF NRMSE as analysed (%)` = pct(nrmse_ff),
            `FF NRMSE at offset (%)` = pct(nrmse_ff_at_delta),
            `OD NRMSE (%)` = pct(nrmse_od))

t4 <- within %>%
  transmute(Milling = mill_lab[Milling], n,
            `Predicted FF − OD (mg/g)` = f2(mean_predicted_shift),
            `Measured FF − OD (mg/g)`  = f2(mean_measured_shift),
            `Predicted − measured (95% CI)` =
              ci(mean_error, error_lo, error_hi, 2),
            `CCC across trees (95% CI)` = ci(ccc, ccc_lo, ccc_hi, 2))

t5 <- irms %>%
  transmute(n,
            `IRMS − Brookside bias (mg/g)` = f2(bias_irms_minus_brookside),
            `95% limits of agreement (mg/g)` =
              sprintf("%.1f to %.1f", loa_lo, loa_hi),
            `CCC (95% CI)` = ci(ccc, ccc_lo, ccc_hi, 2),
            `Precision (ρ)` = f2(r), `Accuracy (Cb)` = f2(Cb))

t6 <- contr %>%
  transmute(Trait,
            Contrast = paste0(sub("_", " ", a), " vs ", sub("_", " ", b)),
            Type = type, n,
            `CCC (95% CI)` = ci(ccc, ccc_lo, ccc_hi, 2),
            `Accuracy (Cb)` = f2(Cb),
            `Mean difference a − b (mg/g)` = f2(bias_a_minus_b),
            `95% limits of agreement (mg/g)` =
              sprintf("%.1f to %.1f", loa_lo, loa_hi))

style_ft <- function(d) {
  flextable(d) %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "all") %>%
    valign(valign = "center", part = "header") %>%
    border_remove() %>%
    hline(part = "all", border = fp_border(width = 0.75)) %>%
    fontsize(size = 9, part = "all") %>%
    autofit()
}

landscape <- prop_section(page_size = page_size(orient = "landscape"),
                          type = "continuous")
save_as_docx(
  "T1. Agreement of predicted values with the oven-dried 20-mesh reference chemistry, per treatment cell (n = 60 trees per cell)" = style_ft(t1),
  "T2. Measured freeze-dried minus oven-dried offsets in ball-milled material (IRMS, n = 11 paired trees)" = style_ft(t2),
  "T3. Range of reference offset over which freeze-dried error stays below oven-dried error, compared with measured and proxy offsets" = style_ft(t3),
  "T4. Predicted vs measured freeze-dried minus oven-dried nitrogen on the same 11 trees" = style_ft(t4),
  "T5. IRMS (oven-dried, ball milled) vs Brookside (oven-dried, 20 mesh) nitrogen on the same trees" = style_ft(t5),
  "T6. Agreement between treatments in predicted values (reference-free)" = style_ft(t6),
  path = file.path(dir_in, "treatment_agreement_supplement_tables.docx"),
  pr_section = landscape)

# --- figures --------------------------------------------------------------
# Okabe-Ito colors (colorblind-safe); no red/green coding.
col_ff <- "#0072B2"
col_od <- "#E69F00"
theme_supp <- theme_bw(base_size = 11) +
  theme(panel.grid.minor = element_blank(), legend.position = "bottom")

# F1: break-even curves
od_n <- cell %>% filter(Drying == "OD") %>%
  select(Trait, Milling, nrmse_od = nrmse)
curves <- cell %>%
  filter(Drying == "FF") %>%
  left_join(od_n, join_by(Trait, Milling)) %>%
  group_by(Trait, Milling) %>%
  reframe(delta = seq(-0.35, 0.35, length.out = 281) * obs_range,
          nrmse = 100 * sqrt(scatter^2 + (bias - delta)^2) / obs_range,
          nrmse_od = 100 * nrmse_od) %>%
  mutate(Milling = factor(mill_lab[Milling], levels = mill_lab))
bands <- bem %>% distinct(Trait, scenario, delta, lo, hi)

f1_plot <- ggplot(curves, aes(delta, nrmse)) +
  geom_rect(data = bands, inherit.aes = FALSE,
            aes(xmin = lo, xmax = hi, ymin = -Inf, ymax = Inf, fill = scenario),
            alpha = 0.3) +
  geom_vline(xintercept = 0, linetype = "dotted") +
  geom_line(color = col_ff, linewidth = 0.9) +
  geom_hline(aes(yintercept = nrmse_od), color = col_od, linewidth = 0.9) +
  facet_wrap(vars(Trait, Milling), scales = "free_x", ncol = 3) +
  scale_fill_manual(values = c("grey35", "grey65", "grey50", "grey80"),
                    name = "Offset estimate (95% CI)") +
  labs(x = expression("Assumed true FF − OD reference offset (mg g"^-1*")"),
       y = "NRMSE of freeze-dried prediction (%)",
       caption = paste0("Blue: freeze-dried NRMSE as the reference offset varies.\n",
                        "Orange: oven-dried NRMSE, same milling treatment. ",
                        "Dotted: no offset (analysis as reported).")) +
  guides(fill = guide_legend(nrow = 2)) +
  theme_supp
ggsave(file.path(dir_in, "F1_break_even.png"), f1_plot,
       width = 8, height = 6.5, dpi = 300, bg = "white")

# F2: Bland-Altman
ba <- pt %>%
  mutate(Drying = factor(dry_lab[Drying], levels = dry_lab),
         Milling = factor(mill_lab[Milling], levels = mill_lab),
         mean_val = (Predicted + Observed) / 2,
         diff = Predicted - Observed)
ba_stats <- cell %>%
  mutate(Drying = factor(dry_lab[Drying], levels = dry_lab),
         Milling = factor(mill_lab[Milling], levels = mill_lab))

f2_plot <- ggplot(ba, aes(mean_val, diff, color = Drying)) +
  geom_hline(yintercept = 0, color = "grey70") +
  geom_hline(data = ba_stats, aes(yintercept = bias), color = "black") +
  geom_hline(data = ba_stats, aes(yintercept = loa_lo),
             linetype = "dashed", color = "grey35") +
  geom_hline(data = ba_stats, aes(yintercept = loa_hi),
             linetype = "dashed", color = "grey35") +
  geom_point(alpha = 0.7, size = 1.3) +
  facet_grid(rows = vars(Trait, Drying), cols = vars(Milling),
             scales = "free_y") +
  scale_color_manual(values = c("Freeze-dried" = col_ff,
                                "Oven-dried" = col_od), guide = "none") +
  labs(x = expression("Mean of predicted and observed (mg g"^-1*")"),
       y = expression("Predicted − observed (mg g"^-1*")"),
       caption = "Solid line: mean difference (bias). Dashed: 95% limits of agreement. Grey: zero.") +
  theme_supp
ggsave(file.path(dir_in, "F2_bland_altman.png"), f2_plot,
       width = 8, height = 9, dpi = 300, bg = "white")

# F3: paired isotope measurements
iso_long <- iso %>%
  pivot_longer(c(carbon_mg_g, nitrogen_IRMS_mg_g, d13C, d15N),
               names_to = "variable", values_to = "value") %>%
  mutate(dry = factor(dry_lab[dry_treatment],
                      levels = c("Oven-dried", "Freeze-dried")),
         variable = factor(variable,
           levels = c("carbon_mg_g", "nitrogen_IRMS_mg_g", "d13C", "d15N"),
           labels = c("Carbon (mg/g)", "Nitrogen (mg/g)",
                      "δ13C (‰)", "δ15N (‰)")))
iso_mean <- iso_long %>% group_by(variable, dry) %>%
  summarise(value = mean(value), .groups = "drop")

f3_plot <- ggplot(iso_long, aes(dry, value)) +
  geom_line(aes(group = Sample_ID), color = "grey60", linewidth = 0.5) +
  geom_point(aes(color = dry), size = 2, alpha = 0.85) +
  geom_line(data = iso_mean, aes(group = 1), linewidth = 1.2) +
  geom_point(data = iso_mean, shape = 18, size = 4) +
  facet_wrap(~ variable, scales = "free_y", nrow = 2) +
  scale_color_manual(values = c("Oven-dried" = col_od,
                                "Freeze-dried" = col_ff), guide = "none") +
  labs(x = NULL, y = NULL,
       caption = "Thin lines connect the same tree (n = 11, ball-milled aliquots). Bold line and diamonds: treatment means.") +
  theme_supp
ggsave(file.path(dir_in, "F3_isotope_pairs.png"), f3_plot,
       width = 7, height = 6, dpi = 300, bg = "white")

message("Done. Tables and figures in ", dir_in)
