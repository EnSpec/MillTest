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

  extra <- tibble(
    trait = trait_label,
    component = c("SD of drying marginal means (OD, FF)",
                  "SD of milling marginal means (coarse, ball, fine)",
                  "Species SD / treatment-cell SD"),
    sd_med = c(median(sqrt(pop_var(dry_means))),
               median(sqrt(pop_var(mill_means))),
               median(sqrt(comp$Species) / sqrt(comp$Treatment_all_cells))),
    sd_lo = c(quantile(sqrt(pop_var(dry_means)), 0.025),
              quantile(sqrt(pop_var(mill_means)), 0.025),
              quantile(sqrt(comp$Species) / sqrt(comp$Treatment_all_cells), 0.025)),
    sd_hi = c(quantile(sqrt(pop_var(dry_means)), 0.975),
              quantile(sqrt(pop_var(mill_means)), 0.975),
              quantile(sqrt(comp$Species) / sqrt(comp$Treatment_all_cells), 0.975)))
  bind_rows(summ, extra)
}

vd <- imap_dfr(models, ~ decompose(.x, traits[[.y]]))
print(vd %>% mutate(across(where(is.numeric), ~ round(.x, 3))), n = Inf, width = Inf)
write.csv(vd, file.path(out_dir, "variance_decomposition.csv"), row.names = FALSE)

# figure: variance shares with 95% intervals
share_plot <- vd %>%
  filter(!is.na(share_med)) %>%
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

set.seed(112)
for (nm in names(models)) {
  m <- models[[nm]]
  lab <- bquote(.(tolower(traits[[nm]])) ~ "(mg g"^-1*")")
  pa <- pp_check(m, type = "dens_overlay", ndraws = 100) +
    labs(x = lab, y = "Density")
  pb <- pp_check(m, type = "dens_overlay_grouped", group = "DryTreat",
                 ndraws = 50) + labs(x = lab, y = "Density")
  pc <- pp_check(m, type = "dens_overlay_grouped", group = "MillTreat",
                 ndraws = 50) + labs(x = lab, y = "Density")
  g <- plot_grid(pa, pb, pc, ncol = 1, labels = "AUTO")
  ggsave(file.path(out_dir, paste0("ppc_", nm, ".png")), g,
         width = 7, height = 10, dpi = 300, bg = "white")
}

# --- 3. coefficient figure with corrected labels ----------------------------

coef_labels <- c(
  b_Intercept                  = "Intercept",
  b_MillTreatBALL              = "Ball Mill",
  b_MillTreatFINE              = "Fine Rotary",
  b_DryTreatFF                 = "Flash freezing",
  `b_MillTreatBALL:DryTreatFF` = "Ball Mill / Flash-freeze interaction",
  `b_MillTreatFINE:DryTreatFF` = "Fine Rotary / Flash-freeze interaction",
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
message("Done. Outputs in ", out_dir)
