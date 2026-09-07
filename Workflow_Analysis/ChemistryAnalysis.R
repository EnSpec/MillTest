########################################
#
# Title: Chemical Analysis
#
# Project: Mill Test 2024
#
# Date: 8/24/2025 (paths de-hard-coded, RMSE denominator and stale plot
#        annotations fixed, deprecated facet labeller replaced -- 2026)
#
# Authors: Zach Breuer, Mill Test Team
#
# Observed (Brookside wet chemistry, oven-dried + 20-mesh material only) vs.
# spectrally predicted nitrogen and calcium, by drying x milling treatment:
# per-treatment linear fits, RMSE / NRMSE, and a variance-partitioning analysis.
#
########################################

library(tidyverse)
library(cowplot)
library(vegan)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "chemistry")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- inputs ---------------------------------------------------------------

# FIXME: the original script read "ChemResults/DryTraits_NEONModel.csv" here,
# but the file of that name on the server has no `sampledata_head` column and
# no calcium prediction. DimensionsDryTraitPredictions.csv is the file whose
# columns match what this script uses. Revisit once the SpectralPredictR
# trait-prediction code is in the repo -- see CLAUDE.md.
predicted_file <- file.path(data_root, "spectralpredictr",
                            "DimensionsDryTraitPredictions.csv")

PredictedChem <- read.csv(predicted_file)

# Brookside.csv carries a UTF-8 BOM on the first header cell; without
# fileEncoding the first column name is mangled and the select() below fails.
ObservedChem <- read.csv(file.path(data_root, "ChemResults", "Brookside.csv"),
                         fileEncoding = "UTF-8-BOM")

# --- predicted: mean per sample x treatment ------------------------------

PredictedChem <- PredictedChem %>%
  mutate(treatment = substring(sampledata_head, 1, 19)) %>%
  group_by(treatment) %>%
  summarise(across(c(t_mean_Nitrogen, t_mean_Potassium,
                     t_mean_Phosphorus, t_mean_Calcium),
                   \(x) mean(x, na.rm = TRUE)),
            .groups = "drop") %>%
  rename(PredictedNitrogen   = t_mean_Nitrogen,
         PredictedPotassium  = t_mean_Potassium,
         PredictedPhosphorus = t_mean_Phosphorus,
         PredictedCalcium    = t_mean_Calcium) %>%
  mutate(Sample_ID = substring(treatment, 1, 11)) %>%
  rename(sample_name = treatment)

# --- observed: one Brookside assay per sample ---------------------------

ObservedChem <- ObservedChem %>%
  select(Sample_ID,
         ObservedNitrogen   = Nitrogen,
         ObservedPotassium  = Potassium,
         ObservedPhosphorus = Phosphorous,
         ObservedCalcium    = Calcium) %>%
  mutate(across(starts_with("Observed"), \(x) as.numeric(as.character(x))))

# --- join: every treatment's prediction against the single assayed value --

Chemistry <- PredictedChem %>%
  left_join(ObservedChem, join_by(Sample_ID)) %>%
  filter(!is.na(ObservedPhosphorus)) %>%
  mutate(DryingTreatment  = substring(sample_name, 13, 14),   # OD / FF
         MillingTreatment = substring(sample_name, 16, 19),   # TWEN / BALL / SIXT
         # Brookside reports % dry mass; x10 -> mg/g to match the predictions
         ObservedCalcium  = ObservedCalcium  * 10,
         ObservedNitrogen = ObservedNitrogen * 10)

# --- per-treatment linear fits: observed ~ predicted --------------------

fit_by_treatment <- function(trait) {
  obs  <- paste0("Observed",  trait)
  pred <- paste0("Predicted", trait)
  Chemistry %>%
    group_by(DryingTreatment, MillingTreatment) %>%
    group_map(~ {
      m <- lm(reformulate(pred, obs), data = .x)
      cat("\n== ", trait, " ", .y$DryingTreatment, .y$MillingTreatment, " ==\n", sep = "")
      print(summary(m))
      m
    })
}

calcium_fits  <- fit_by_treatment("Calcium")
nitrogen_fits <- fit_by_treatment("Nitrogen")

# --- RMSE and normalized RMSE by trait x drying x milling --------------
# RMSE  = sqrt(mean squared error) over the samples in that treatment cell
# NRMSE = RMSE / (range of observed values within that milling treatment)

sq_err <- Chemistry %>%
  transmute(DryingTreatment, MillingTreatment,
            Nitrogen = (PredictedNitrogen - ObservedNitrogen)^2,
            Calcium  = (PredictedCalcium  - ObservedCalcium)^2) %>%
  pivot_longer(c(Nitrogen, Calcium), names_to = "Trait", values_to = "sq_err")

obs_range <- Chemistry %>%
  transmute(MillingTreatment,
            Nitrogen = ObservedNitrogen, Calcium = ObservedCalcium) %>%
  pivot_longer(c(Nitrogen, Calcium), names_to = "Trait", values_to = "obs") %>%
  group_by(Trait, MillingTreatment) %>%
  summarise(obs_range = max(obs, na.rm = TRUE) - min(obs, na.rm = TRUE),
            .groups = "drop")

rmse_tbl <- sq_err %>%
  group_by(Trait, DryingTreatment, MillingTreatment) %>%
  summarise(n    = sum(!is.na(sq_err)),
            RMSE = sqrt(mean(sq_err, na.rm = TRUE)),
            .groups = "drop") %>%
  left_join(obs_range, join_by(Trait, MillingTreatment)) %>%
  mutate(NRMSE = RMSE / obs_range)

print(rmse_tbl)
write.csv(rmse_tbl, file.path(out_dir, "rmse_nrmse_by_treatment.csv"),
          row.names = FALSE)

# --- observed vs predicted plots --------------------------------------

mill_list <- c(BALL = "Ball Milled",
               SIXT = "Fine Mesh Milled",
               TWEN = "Twenty Mesh Milled")

# One annotation block per milling facet, built from the values computed above.
RMSEText <- rmse_tbl %>%
  select(Trait, DryingTreatment, MillingTreatment, RMSE, NRMSE) %>%
  pivot_wider(names_from = DryingTreatment, values_from = c(RMSE, NRMSE)) %>%
  mutate(Text = sprintf("RMSE\nOD: %.4g\nFF: %.4g\nNRMSE\nOD: %.4g\nFF: %.4g",
                        RMSE_OD, RMSE_FF, NRMSE_OD, NRMSE_FF)) %>%
  select(Trait, MillingTreatment, Text)

obs_pred_plot <- function(trait, text_x, text_y) {
  pred <- paste0("Predicted", trait)
  obs  <- paste0("Observed",  trait)
  ggplot(Chemistry, aes(x = .data[[pred]], y = .data[[obs]],
                        color = DryingTreatment)) +
    geom_point() +
    geom_smooth(method = "lm", se = FALSE, formula = y ~ x) +
    geom_abline(slope = 1, intercept = 0, lwd = 1, linetype = "dashed") +
    scale_color_manual(values = c(FF = "#7AC5CD", OD = "#d73027")) +
    geom_text(data = filter(RMSEText, Trait == trait),
              aes(label = Text), x = text_x, y = text_y,
              size = 2.5, hjust = 0, inherit.aes = FALSE) +
    facet_wrap(~MillingTreatment, labeller = as_labeller(mill_list)) +
    labs(x = paste("Predicted", trait), y = paste("Observed", trait),
         color = "Drying Treatment") +
    theme_bw()
}

# text_x / text_y are hand-placed in data units for each panel
NEONNitrogenPlot <- obs_pred_plot("Nitrogen", text_x = 8,    text_y = 32)
NEONCalciumPlot  <- obs_pred_plot("Calcium",  text_x = -5.5, text_y = 61.5)

ggsave(file.path(out_dir, "NEONNitrogen.png"), NEONNitrogenPlot,
       dpi = 320, scale = 2, width = 5, height = 1.875)
ggsave(file.path(out_dir, "NEONCalcium.png"), NEONCalciumPlot,
       dpi = 320, scale = 2, width = 5, height = 1.875)

ObsvsPredPlotGrid <- plot_grid(NEONNitrogenPlot, NEONCalciumPlot,
                               ncol = 1, labels = c("A", "B"))
ggsave(file.path(out_dir, "ChemPlotGrid.png"), ObsvsPredPlotGrid,
       dpi = 320, scale = 2, width = 5, height = 2.75)

# --- variance partitioning -------------------------------------------------
# NOTE: late manuscript addition, little reviewed. Species_Code and Type are
# collinear (Type is fixed by species), so varpart() reports "results are
# probably incorrect". Planned fix (Henry): run the partition separately within
# each Type (Broadleaf, Conifer) and drop Type as a table. Left as-is for now
# so the current numbers are reproducible; revisit with Zach.

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  select(Sample_ID, Species_Code, Type)

PredictedChemVPA <- PredictedChem %>%
  left_join(sample_info, join_by(Sample_ID)) %>%
  mutate(DryingTreatment  = substring(sample_name, 13, 14),
         MillingTreatment = substring(sample_name, 16, 19))

# NOTE: Species_Code and Type are collinear (Type is fixed by species), so
# varpart() reports "results are probably incorrect" for the fractions that
# involve both. Pre-existing; resolve (drop one, or nest) if the VPA stays.

vpa_plot <- function(model, file) {
  png(file.path(out_dir, file), width = 1200, height = 1200, res = 200)
  plot(model, bg = 2:5)
  dev.off()
}

VPAModelCa <- varpart(PredictedChemVPA$PredictedCalcium,
                      ~ Species_Code, ~ Type,
                      ~ MillingTreatment, ~ DryingTreatment,
                      data = PredictedChemVPA, chisquare = FALSE)
print(VPAModelCa)
vpa_plot(VPAModelCa, "varpart_calcium.png")

VPAModelN <- varpart(PredictedChemVPA$PredictedNitrogen,
                     ~ Species_Code, ~ Type,
                     ~ MillingTreatment, ~ DryingTreatment,
                     data = PredictedChemVPA, chisquare = FALSE)
print(VPAModelN)
vpa_plot(VPAModelN, "varpart_nitrogen.png")
