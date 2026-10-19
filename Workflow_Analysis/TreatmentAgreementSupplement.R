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
#     T1  Agreement with the OD 20-mesh reference, per treatment cell,
#         with the break-even range for FF rows
#     T2  Paired isotope trees: A measured FF - OD offsets, B predicted vs
#         measured FF - OD N shift, C IRMS vs Brookside N
#   (break_even_vs_measured.csv and treatment_contrast_concordance.csv
#    remain available as CSVs but are not tabulated)
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

# Break-even range (FF rows only): offsets over which FF error stays below OD
be_rng <- bem %>% distinct(Trait, Milling, delta_lo, delta_hi) %>%
  mutate(Drying = "FF",
         `Break-even range (mg/g)` = sprintf("%.1f to %.1f", delta_lo, delta_hi))

t1 <- cell %>%
  left_join(be_rng %>% select(Trait, Milling, Drying, `Break-even range (mg/g)`),
            join_by(Trait, Milling, Drying)) %>%
  mutate(`Break-even range (mg/g)` =
           ifelse(is.na(`Break-even range (mg/g)`), "—",
                  `Break-even range (mg/g)`)) %>%
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
              sprintf("%.1f to %.1f", loa_lo, loa_hi),
            `Break-even range (mg/g)`)

# Table 2: three panels, all from the 11 paired isotope trees
tq <- function(n) qt(0.975, n - 1)
t2a <- off %>%
  transmute(Panel = "A. Measured FF − OD (ball milled, IRMS)",
            Comparison = measure, n,
            `Mean, group 1` = f1(mean_od), `Mean, group 2` = f1(mean_ff),
            `Difference (95% CI)` = ci(offset, offset_lo, offset_hi, 2),
            Note = sprintf("%d of %d trees lower in FF; relative %.1f%% (%.1f, %.1f); p %s",
                           n_negative, n, 100 * rel_offset, 100 * rel_lo,
                           100 * rel_hi,
                           ifelse(p_value < 0.001, "<0.001",
                                  formatC(p_value, digits = 3, format = "f"))))
t2b <- within %>%
  transmute(Panel = "B. Predicted vs measured FF − OD nitrogen",
            Comparison = paste("N,", mill_lab[Milling]), n,
            `Mean, group 1` = f2(mean_predicted_shift),
            `Mean, group 2` = f2(mean_measured_shift),
            `Difference (95% CI)` = ci(mean_error, error_lo, error_hi, 2),
            Note = sprintf("CCC across trees %s", ci(ccc, ccc_lo, ccc_hi, 2)))
t2c <- irms %>%
  transmute(Panel = "C. IRMS vs Brookside nitrogen (oven-dried)",
            Comparison = "N, IRMS (ball) vs Brookside (20 mesh)", n,
            `Mean, group 1` = "", `Mean, group 2` = "",
            `Difference (95% CI)` =
              ci(bias_irms_minus_brookside,
                 bias_irms_minus_brookside - tq(n) * sd_diff / sqrt(n),
                 bias_irms_minus_brookside + tq(n) * sd_diff / sqrt(n), 2),
            Note = sprintf("95%% limits of agreement %.1f to %.1f; CCC %s",
                           loa_lo, loa_hi, ci(ccc, ccc_lo, ccc_hi, 2)))
t2 <- bind_rows(t2a, t2b, t2c) %>%
  rename(`Group 1` = `Mean, group 1`, `Group 2` = `Mean, group 2`)

# Fixed-layout tables with explicit widths so they fit the landscape page
# (letter 11 x 8.5 in, 0.5 in margins -> 10 in of usable width).
style_ft <- function(d, widths, size = 8) {
  stopifnot(length(widths) == ncol(d), sum(widths) <= 10)
  flextable(d) %>%
    set_table_properties(layout = "fixed") %>%
    width(j = seq_along(widths), width = widths) %>%
    align(align = "center", part = "all") %>%
    align(j = 1, align = "left", part = "all") %>%
    valign(valign = "center", part = "all") %>%
    border_remove() %>%
    hline(part = "all", border = fp_border(width = 0.75)) %>%
    fontsize(size = size, part = "all") %>%
    padding(padding.left = 2, padding.right = 2, part = "all")
}

# Table 1: 15 columns
w1 <- c(0.65, 0.7, 0.7,          # trait, drying, milling
        0.5, 0.5, 0.5, 0.55,     # RMSE, NRMSE, bias, slope
        0.55, 0.7, 0.7,          # MSE shares
        0.5, 0.5, 0.95,          # rho, Cb, CCC (CI)
        0.95, 0.95)              # limits of agreement, break-even range
# Table 2: 7 columns
w2 <- c(1.9, 1.9, 0.4, 0.7, 0.7, 1.5, 2.9)

landscape <- prop_section(
  page_size = page_size(orient = "landscape", width = 11, height = 8.5),
  page_margins = page_mar(left = 0.5, right = 0.5, top = 0.7, bottom = 0.7),
  type = "continuous")
save_as_docx(
  "Table 1. Agreement of predicted values with the oven-dried 20-mesh reference chemistry, per treatment cell (n = 60 trees per cell). Break-even range: reference offsets over which freeze-dried error stays below oven-dried error." = style_ft(t1, w1),
  "Table 2. Paired freeze-dried (FF) and oven-dried (OD) measurements on 11 trees. Panel A: group 1 = OD, group 2 = FF (mg/g). Panel B: group 1 = predicted FF − OD, group 2 = measured FF − OD (mg/g). Panel C: IRMS minus Brookside." = style_ft(t2, w2),
  # SUPP_DOCX overrides the file name (e.g. when the default is open in Word)
  path = file.path(dir_in, Sys.getenv("SUPP_DOCX",
                                      unset = "treatment_agreement_supplement_tables.docx")),
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
