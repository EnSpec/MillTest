##################################################
#
# Title: Mean Spectral Difference Curves (per wavelength)
#
# Project: Mill Test 2024
#
# Purpose: Full-resolution (per-nm) mean difference curves for each of the
# 4 treatment comparisons x growth form, to check specific peak claims in
# the manuscript text (e.g. "maximum difference values found between drying
# treatments was 33.99% at 750 nm in broadleafs and 17.62% at 733 nm in
# conifers") that Table1_SpectralDifferenceRegions.R's 5-region summary
# can't verify. Same design-population restriction as that script (excludes
# GLTR, Forb, Graminoid -- see that script's comments for why).
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
boot_dir <- file.path(data_root, "BootstrappedData")
out_dir  <- file.path(data_root, "derived", "spectral_difference")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  select(Sample_ID, Species_Code, Type) %>%
  distinct()

design_ids <- sample_info %>%
  filter(Type %in% c("Broadleaf", "Conifer"), Species_Code != "GLTR") %>%
  pull(Sample_ID)

comparison_labels <- c(
  "OD_BALL_OD_TWEN" = "Ball - Coarse",
  "OD_BALL_OD_SIXT" = "Ball - Fine",
  "OD_SIXT_OD_TWEN" = "Fine - Coarse",
  "FF_TWEN_OD_TWEN" = "Freeze Dried - Oven Dried"
)

files <- list.files(boot_dir, pattern = "\\.csv$", full.names = TRUE)

# per-sample mean curve (mean across the 36 replicate-pair rows), full
# wavelength resolution, in percentage-reflectance-point units
read_one <- function(path) {
  fname <- tools::file_path_sans_ext(basename(path))
  m <- str_match(fname, "^(MILL24_[0-9]+)_([A-Z]+_[A-Z]+)_([A-Z]+_[A-Z]+)$")
  sample_id  <- m[, 2]
  if (!(sample_id %in% design_ids)) return(NULL)
  comparison <- comparison_labels[paste(m[, 3], m[, 4], sep = "_")]

  d <- read.csv(path)
  wl_cols <- grep("^X[0-9]+$", names(d), value = TRUE)
  wls <- as.numeric(sub("^X", "", wl_cols))
  means <- colMeans(d[, wl_cols]) * 100

  tibble(Sample_ID = sample_id, Comparison = comparison, wl = wls, Value = means)
}

per_sample_curve <- map(files, read_one) %>% bind_rows() %>%
  left_join(sample_info, by = "Sample_ID")

curves <- bind_rows(
  per_sample_curve %>% group_by(Comparison, wl) %>%
    summarise(Value = mean(Value), .groups = "drop") %>% mutate(Group = "All Data"),
  per_sample_curve %>% filter(Type == "Broadleaf") %>% group_by(Comparison, wl) %>%
    summarise(Value = mean(Value), .groups = "drop") %>% mutate(Group = "Broadleaved"),
  per_sample_curve %>% filter(Type == "Conifer") %>% group_by(Comparison, wl) %>%
    summarise(Value = mean(Value), .groups = "drop") %>% mutate(Group = "Needle-Leaved")
) %>% arrange(Comparison, Group, wl)

write.csv(curves, file.path(out_dir, "mean_difference_curves.csv"), row.names = FALSE)

# --- check the manuscript's specific peak claims ----------------------------

peak_check <- curves %>%
  filter(Comparison == "Freeze Dried - Oven Dried", Group %in% c("Broadleaved", "Needle-Leaved")) %>%
  group_by(Group) %>%
  slice_max(Value, n = 1) %>%
  ungroup()

cat("Manuscript claims: 33.99% at 750 nm (broadleaf), 17.62% at 733 nm (conifer)\n")
cat("Recomputed (design population, GLTR/Forb/Graminoid excluded):\n")
print(as.data.frame(peak_check))

cat(sprintf("\nWrote %s\n", file.path(out_dir, "mean_difference_curves.csv")))
