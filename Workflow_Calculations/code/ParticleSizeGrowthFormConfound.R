##################################################
#
# Title: Particle size and the broadleaf / needle-leaf milling contrast
#
# Project: Mill Test 2024
#
# Date: 2026-10-16
#
# Purpose: Broadleaved samples were milled to 60 mesh and needle-leaved
# samples to 40 mesh (resin content), so the growth-form contrast in the
# fine-mesh spectral effect is confounded with treatment intensity. This
# script (1) summarises particle size by growth form and (2) regresses each
# tree's fine - coarse spectral difference (oven-dried; percentage points of
# reflectance, as in Table 1) on its reduction in mean particle size
# (20-mesh minus fine, um) plus a growth-form term, over the trees that have
# both measurements.
#
# Inputs (run ParticleStat.R first):
#   derived/particle_size/particle_size_per_sample.csv
#   ReplicatePairDifferences/<Sample>_OD_SIXT_OD_TWEN.csv
#
# Outputs (derived/spectral_difference/):
#   particle_size_by_growth_form.csv
#   particle_size_confound_regression.csv
#
# The spectral-difference convention matches Table1_SpectralDifferenceRegions.R:
# fractional reflectance difference x 100, averaged over the 36 replicate
# pairs and over the wavelengths in each region. Small n (21 trees) and strong
# collinearity between growth form and size reduction: treat as descriptive.
#
##################################################

library(tidyverse)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
boot_dir <- file.path(data_root, "ReplicatePairDifferences")
out_dir  <- file.path(data_root, "derived", "spectral_difference")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

regions <- list(
  "Entire Spectral Range" = c(350, 2500),
  "SWIR1 (1501-2000 nm)"  = c(1501, 2000),
  "SWIR2 (2001-2500 nm)"  = c(2001, 2500)
)

# --- particle size, one row per tree x milling treatment -------------------
ps <- read.csv(file.path(data_root, "derived", "particle_size",
                         "particle_size_per_sample.csv")) %>%
  select(Sample_ID = Sample, Treatment, Mean, Type)

by_growth_form <- ps %>%
  group_by(Type, Treatment) %>%
  summarise(n = n(), mean_um = mean(Mean), sd_um = sd(Mean), .groups = "drop")
print(by_growth_form)
write.csv(by_growth_form, file.path(out_dir, "particle_size_by_growth_form.csv"),
          row.names = FALSE)

trees <- ps %>%
  pivot_wider(names_from = Treatment, values_from = Mean) %>%
  filter(!is.na(Fine), !is.na(Twenty)) %>%
  mutate(size_reduction_um = Twenty - Fine)

# --- per-tree fine - coarse spectral difference ----------------------------
spectral_diff <- function(id) {
  f <- file.path(boot_dir, paste0(id, "_OD_SIXT_OD_TWEN.csv"))
  if (!file.exists(f)) return(NULL)
  d <- read.csv(f)
  wl_cols <- grep("^X[0-9]+$", names(d), value = TRUE)
  wls <- as.numeric(sub("^X", "", wl_cols))
  m <- as.matrix(d[, wl_cols])
  tibble(Region = names(regions),
         diff_pp = map_dbl(regions, ~ mean(m[, wls >= .x[1] & wls <= .x[2]]) * 100))
}

dat <- trees %>%
  mutate(sd = map(Sample_ID, spectral_diff)) %>%
  unnest(sd)
cat(sprintf("\nTrees with particle size and spectra: %d (%s)\n",
            n_distinct(dat$Sample_ID),
            paste(names(table(distinct(dat, Sample_ID, Type)$Type)),
                  table(distinct(dat, Sample_ID, Type)$Type), collapse = ", ")))

# --- regression: spectral difference ~ size reduction + growth form --------
fit_region <- function(df) {
  m  <- lm(diff_pp ~ I(size_reduction_um / 100) + Type, data = df)
  cf <- summary(m)$coefficients
  ci <- confint(m)
  tibble(term = c("Intercept", "Size reduction (per 100 um)",
                  "Needle-leaved minus broadleaved"),
         estimate = cf[, 1], lo = ci[, 1], hi = ci[, 2], p = cf[, 4],
         n_trees = nobs(m))
}

reg <- dat %>%
  group_by(Region) %>%
  group_modify(~ fit_region(.x)) %>%
  ungroup()

raw_gap <- dat %>%
  group_by(Region, Type) %>%
  summarise(mean_diff = mean(diff_pp), .groups = "drop") %>%
  pivot_wider(names_from = Type, values_from = mean_diff) %>%
  mutate(raw_gap_conifer_minus_broadleaf = Conifer - Broadleaf)

print(reg, n = Inf)
print(raw_gap)
write.csv(reg, file.path(out_dir, "particle_size_confound_regression.csv"),
          row.names = FALSE)
write.csv(raw_gap, file.path(out_dir, "particle_size_confound_raw_gap.csv"),
          row.names = FALSE)
