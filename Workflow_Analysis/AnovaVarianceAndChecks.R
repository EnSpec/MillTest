########################################################
# AnovaVarianceAndChecks.R
#
# Post-processing of the saved Bayesian ANOVA fits from
# Predicted_Trait_Analysis.R (no refitting). Run that script first; this one
# reads derived/anova/{nitrogen,calcium}_model.rds.
#
#   1. Variance decomposition. Per posterior draw, the variance of the trait
#      is split into: treatment (variance of the six drying x milling cell
#      means, i.e. a finite-population SD in the sense of Gelman 2005,
#      Ann. Stat. 33:1-53), species, individual tree within species, tree x
#      treatment combination, and residual scan-to-scan variation. Species,
#      tree and combination terms are the model's group-level SDs (squared).
#      Shares are each component over the sum; the species-SD to
#      treatment-SD ratio puts the "interspecific vs processing" comparison
#      on one scale.
#   2. Posterior predictive checks: overall, by drying and by milling
#      treatment (bayesplot via brms::pp_check).
#   3. Coefficient plot with corrected random-effect labels and an x-axis
#      label (same figure as Predicted_Trait_Analysis.R's report_model(), but
#      regenerated from the saved fit).
#
# Outputs: derived/anova/variance_decomposition.csv, variance_shares.png,
#   percent_change_vs_observed_reference.csv, effects_and_variance.png,
#   ppc_<trait>.png, <trait>_coefficients_MCMCvis.jpeg (overwritten)
########################################################

library(tidyverse)
library(brms)
library(MCMCvis)
library(cowplot)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
out_dir <- file.path(data_root, "derived", "anova")

traits <- c(nitrogen = "Nitrogen", calcium = "Calcium")
models <- map(names(traits), ~ readRDS(file.path(out_dir, paste0(.x, "_model.rds"))))
names(models) <- names(traits)

# --- 1. variance decomposition -------------------------------------------

decompose <- function(model, trait_label) {
  d <- as.data.frame(model)
  # six treatment-cell means (reference = oven-dried, coarse)
  cell_mean <- function(mill, dry) {
    mu <- d$b_Intercept
    if (mill != "COARSE") mu <- mu + d[[paste0("b_MillTreat", mill)]]
    if (dry == "FF")      mu <- mu + d$b_DryTreatFF
    if (mill != "COARSE" && dry == "FF")
      mu <- mu + d[[paste0("b_MillTreat", mill, ":DryTreatFF")]]
    mu
  }
  cells <- expand_grid(mill = c("COARSE", "BALL", "FINE"), dry = c("OD", "FF"))
  mu <- do.call(cbind, map2(cells$mill, cells$dry, cell_mean))
  pop_var <- function(m) apply(m, 1, function(v) mean((v - mean(v))^2))

  # marginal (main-effect) means, equal weights, for reference
  dry_means  <- sapply(c("OD", "FF"), function(dr)
    rowMeans(mu[, cells$dry == dr, drop = FALSE]))
  mill_means <- sapply(c("COARSE", "BALL", "FINE"), function(ml)
    rowMeans(mu[, cells$mill == ml, drop = FALSE]))

  comp <- tibble(
    draw = seq_len(nrow(d)),
    Treatment_all_cells = pop_var(mu),
    Species      = d$sd_Species_Code__Intercept^2,
    Tree         = d$`sd_Species_Code:SampleID__Intercept`^2,
    Combination  = d$`sd_Species_Code:SampleID:measure_id__Intercept`^2,
    Residual     = d$sigma^2)
  comp <- comp %>%
    mutate(total = Treatment_all_cells + Species + Tree + Combination + Residual)

  long <- comp %>%
    pivot_longer(c(Treatment_all_cells, Species, Tree, Combination, Residual),
                 names_to = "component", values_to = "variance") %>%
    mutate(share = variance / total, sd = sqrt(variance))

  q <- function(x) c(median = median(x), lo = quantile(x, 0.025, names = FALSE),
                     hi = quantile(x, 0.975, names = FALSE))
  summ <- long %>%
    group_by(component) %>%
    summarise(sd_med = q(sd)[1], sd_lo = q(sd)[2], sd_hi = q(sd)[3],
              share_med = q(share)[1], share_lo = q(share)[2],
              share_hi = q(share)[3], .groups = "drop") %>%
    mutate(trait = trait_label, .before = 1)

  qs <- function(x) c(med = median(x), lo = quantile(x, 0.025, names = FALSE),
                      hi = quantile(x, 0.975, names = FALSE))
  mk <- function(label, sd = NULL, share = NULL, ratio = NULL) {
    tibble(trait = trait_label, component = label,
           sd_med = if (!is.null(sd)) qs(sd)[1] else NA_real_,
           sd_lo = if (!is.null(sd)) qs(sd)[2] else NA_real_,
           sd_hi = if (!is.null(sd)) qs(sd)[3] else NA_real_,
           share_med = if (!is.null(share)) qs(share)[1] else NA_real_,
           share_lo = if (!is.null(share)) qs(share)[2] else NA_real_,
           share_hi = if (!is.null(share)) qs(share)[3] else NA_real_,
           ratio_med = if (!is.null(ratio)) qs(ratio)[1] else NA_real_,
           ratio_lo = if (!is.null(ratio)) qs(ratio)[2] else NA_real_,
           ratio_hi = if (!is.null(ratio)) qs(ratio)[3] else NA_real_)
  }
  proc_var <- comp$Treatment_all_cells + comp$Combination
  extra <- bind_rows(
    mk("SD of drying marginal means (OD, FF)", sd = sqrt(pop_var(dry_means))),
    mk("SD of milling marginal means (coarse, ball, fine)",
       sd = sqrt(pop_var(mill_means))),
    # processing-related = treatment + tree x treatment combination
    mk("Treatment + tree x combination (processing-related)",
       sd = sqrt(proc_var), share = proc_var / comp$total),
    mk("Species SD / treatment-cell SD",
       ratio = sqrt(comp$Species) / sqrt(comp$Treatment_all_cells)),
    mk("(Treatment + combination) variance / tree variance",
       ratio = proc_var / comp$Tree))
  bind_rows(summ, extra)
}

vd <- imap_dfr(models, ~ decompose(.x, traits[[.y]]))
print(vd %>% mutate(across(where(is.numeric), ~ round(.x, 3))), n = Inf, width = Inf)
write.csv(vd, file.path(out_dir, "variance_decomposition.csv"), row.names = FALSE)

# figure: variance shares with 95% intervals
share_plot <- vd %>%
  filter(!is.na(share_med)) %>%
  mutate(trait = factor(trait, levels = c("Nitrogen", "Calcium"))) %>%
  mutate(component = factor(component,
           levels = rev(c("Species", "Tree", "Combination",
                          "Treatment_all_cells", "Residual")),
           labels = rev(c("Species", "Tree within species",
                          "Tree × treatment combination",
                          "Treatment (6 cells)", "Residual (scan-to-scan)"))))
p_share <- ggplot(share_plot, aes(share_med * 100, component)) +
  geom_pointrange(aes(xmin = share_lo * 100, xmax = share_hi * 100),
                  color = "#0072B2") +
  facet_wrap(~ trait) +
  labs(x = "Share of total modelled variance (%; median and 95% interval)",
       y = NULL) +
  theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank())
ggsave(file.path(out_dir, "variance_shares.png"), p_share,
       width = 8, height = 3.6, dpi = 300, bg = "white")

# --- 2. posterior predictive checks ------------------------------------------
# One supplement figure: columns = traits, rows = overall / by drying / by
# milling. Dark line = observed, light lines = posterior-predictive draws.

set.seed(112)
ppc_panels <- imap(models, function(m, nm) {
  lab <- bquote(.(tolower(traits[[nm]])) ~ "(mg g"^-1*")")
  mk <- function(type, group = NULL, n = 100) {
    pp_check(m, type = type, group = group, ndraws = n) +
      labs(x = lab, y = "Density") + theme(legend.position = "none")
  }
  list(mk("dens_overlay"),
       mk("dens_overlay_grouped", "DryTreat", 50),
       mk("dens_overlay_grouped", "MillTreat", 50))
})
col_title <- function(txt) ggdraw() + draw_label(txt, fontface = "bold", size = 12)
ppc_grid <- plot_grid(
  col_title("Nitrogen"), col_title("Calcium"),
  plot_grid(plotlist = ppc_panels$nitrogen, ncol = 1, labels = c("A", "C", "E")),
  plot_grid(plotlist = ppc_panels$calcium,  ncol = 1, labels = c("B", "D", "F")),
  ncol = 2, rel_heights = c(0.05, 1))
ggsave(file.path(out_dir, "ppc_combined.png"), ppc_grid,
       width = 11, height = 10, dpi = 300, bg = "white")

# --- 3. coefficient figure with corrected labels ----------------------------

coef_labels <- c(
  b_Intercept                  = "Intercept",
  b_MillTreatBALL              = "Ball mill",
  b_MillTreatFINE              = "Fine mesh (40/60)",
  b_DryTreatFF                 = "Freeze-dried",
  `b_MillTreatBALL:DryTreatFF` = "Ball mill / Freeze-dried interaction",
  `b_MillTreatFINE:DryTreatFF` = "Fine mesh / Freeze-dried interaction",
  sd_Species_Code__Intercept                       = "Species random effect s.d.",
  `sd_Species_Code:SampleID__Intercept`            = "Individual (within species) random effect s.d.",
  `sd_Species_Code:SampleID:measure_id__Intercept` = "Tree x treatment combination random effect s.d.",
  sigma                                            = "Residual (scan-to-scan) s.d."
)
for (nm in names(models)) {
  post <- as.matrix(models[[nm]])
  keep <- intersect(names(coef_labels), colnames(post))
  jpeg(file.path(out_dir, paste0(nm, "_coefficients_MCMCvis.jpeg")),
       width = 1600, height = 1200, res = 200)
  MCMCplot(post[, keep], labels = unname(coef_labels[keep]),
           xlab = expression("Coefficient or s.d. (mg g"^-1*")"))
  dev.off()
}
# --- 4. manuscript figure: treatment contrasts + variance shares -------------
# A: posterior median and 95% interval of the five treatment coefficients
#    (reference = oven-dried, 20-mesh); B: variance shares from section 1.

coef_lab <- c(b_DryTreatFF                 = "Freeze-dried",
              b_MillTreatBALL              = "Ball mill",
              b_MillTreatFINE              = "Fine mesh (40/60)",
              `b_MillTreatBALL:DryTreatFF` = "Ball mill \u00d7 freeze-dried",
              `b_MillTreatFINE:DryTreatFF` = "Fine mesh \u00d7 freeze-dried")
coef_draws <- imap_dfr(models, function(m, nm) {
  d <- as.data.frame(m)[, names(coef_lab)]
  pivot_longer(d, everything(), names_to = "term", values_to = "value") %>%
    mutate(trait = traits[[nm]])
})
coef_sum <- coef_draws %>%
  group_by(trait, term) %>%
  summarise(med = median(value), lo = quantile(value, 0.025),
            hi = quantile(value, 0.975), .groups = "drop") %>%
  mutate(term = factor(coef_lab[term], levels = rev(unname(coef_lab))),
         trait = factor(trait, levels = c("Nitrogen", "Calcium")))

p_coef <- ggplot(coef_sum, aes(med, term)) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
  geom_pointrange(aes(xmin = lo, xmax = hi), color = "#0072B2") +
  facet_wrap(~ trait) +
  labs(x = expression("Effect relative to oven-dried, 20-mesh (mg g"^-1*")"),
       y = NULL) +
  theme_bw(base_size = 11) + theme(panel.grid.minor = element_blank())

fig_effects <- plot_grid(p_coef, p_share, ncol = 1, labels = c("A", "B"),
                         rel_heights = c(1, 0.85), align = "v", axis = "lr")
ggsave(file.path(out_dir, "effects_and_variance.png"), fig_effects,
       width = 8, height = 7, dpi = 300, bg = "white")

# --- 5. percent change relative to the observed reference mean ----------------
# Percent change = combined treatment effect / observed mean of the reference
# cell (oven-dried, 20-mesh), the latter treated as fixed (so the interval
# reflects uncertainty in the effects only).

pct_change <- imap_dfr(models, function(m, nm) {
  d <- as.data.frame(m)
  y <- m$data[[1]]
  ref <- mean(y[m$data$MillTreat == "COARSE" & m$data$DryTreat == "OD"])
  combos <- list(
    "Freeze-dried alone"                   = d$b_DryTreatFF,
    "Freeze-dried + ball mill + interaction" =
      d$b_DryTreatFF + d$b_MillTreatBALL + d[["b_MillTreatBALL:DryTreatFF"]],
    "Freeze-dried + fine mesh + interaction" =
      d$b_DryTreatFF + d$b_MillTreatFINE + d[["b_MillTreatFINE:DryTreatFF"]])
  imap_dfr(combos, function(eff, lab)
    tibble(trait = traits[[nm]], combination = lab, reference_mean_mg_g = ref,
           effect_mean = mean(eff),
           effect_lo = quantile(eff, 0.025, names = FALSE),
           effect_hi = quantile(eff, 0.975, names = FALSE),
           pct_mean = 100 * mean(eff) / ref,
           pct_lo = 100 * quantile(eff, 0.025, names = FALSE) / ref,
           pct_hi = 100 * quantile(eff, 0.975, names = FALSE) / ref))
})
print(pct_change %>% mutate(across(where(is.numeric), ~ round(.x, 2))), width = Inf)
write.csv(pct_change, file.path(out_dir, "percent_change_vs_observed_reference.csv"),
          row.names = FALSE)

message("Done. Outputs in ", out_dir)
