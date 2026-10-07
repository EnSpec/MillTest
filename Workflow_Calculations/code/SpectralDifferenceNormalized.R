##################################################
#
# Title: Treatment difference spectra on vector-normalized (VN) spectra
#
# Project: Mill Test 2024
#
# Purpose: Appendix/supplement figure. The same four treatment-difference
# panels as the main-text figure (BootstrapFigureGeneration.R), computed on
# vector-normalized spectra instead of reflectance.
#
# Vector normalization (Feilhauer et al. 2010, J. Quant. Spectrosc. Radiat.
# Transfer 111:1947): each spectrum is divided by its Euclidean norm over
# 350-2500 nm, the same normalization the lab applies before PLSR trait
# prediction. VN values are unitless, so the y axis is the VN difference x 100
# (not percentage reflectance).
#
# Method: BootstrapCode.R enumerates all 6 x 6 = 36 replicate-pair
# differences per sample and comparison, and BootstrapFigureGeneration.R then
# averages them per sample. The mean of those 36 differences is exactly
# mean(treatment 1 replicates) - mean(treatment 2 replicates), so this script
# computes that directly. The reflectance version is recomputed the same way
# and checked against the existing BootstrappedData/ files, which verifies the
# shortcut and the input file before the VN result is trusted.
#
# Input: spectralpredictr/SpectralPredictR_raw_spectra.csv (jump-corrected,
# one row per scan, no duplicate scans). Mill24_RawSpec.csv holds the same
# spectra but repeats three sample x treatment groups (0034 FF_SIXT, 0037
# FF_BALL, 0059 FF_BALL); none of them enter these four comparisons.
#
# Out: derived/spectral_difference_vn/{vn_difference_by_sample.csv,
#      VNDifferenceChart.png}
#
# Author: Mill Test Team, 2026
#
##################################################

library(tidyverse)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
out_dir <- file.path(data_root, "derived", "spectral_difference_vn")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

spec <- read.csv(file.path(data_root, "spectralpredictr",
                           "SpectralPredictR_raw_spectra.csv"))
stopifnot(!anyDuplicated(spec$sample_name))
wl_cols <- grep("^X[0-9]+$", names(spec), value = TRUE)
wls <- as.integer(sub("^X", "", wl_cols))
stopifnot(identical(wls, 350:2500))

group <- substring(spec$sample_name, 1, 19)           # MILL24_0001_FF_TWEN
X <- as.matrix(spec[, wl_cols])

sampleinfo <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  rename(sample_name = Sample_ID) %>%
  select(sample_name, Type) %>%
  filter(Type %in% c("Broadleaf", "Conifer")) %>%
  mutate(Type = recode(Type, "Conifer" = "Needle-Leaf"))

# treatment1 - treatment2, as in BootstrapCode.R's output file names
comparisons <- tribble(
  ~treatment1, ~treatment2, ~Comparison,                  ~sublabel,
  "OD_BALL",   "OD_TWEN",   "Ball - Coarse",              "A",
  "OD_BALL",   "OD_SIXT",   "Ball - Fine",                "B",
  "OD_SIXT",   "OD_TWEN",   "Fine - Coarse",              "C",
  "FF_TWEN",   "OD_TWEN",   "Freeze Dried - Oven Dried",  "D")

# per-sample mean difference curve for every comparison; one row per
# sample x comparison, one column per wavelength
sample_differences <- function(X) {
  gmean <- rowsum(X, group) / as.vector(table(group)[rownames(rowsum(X, group))])
  map_dfr(seq_len(nrow(comparisons)), function(k) {
    t1 <- comparisons$treatment1[k]; t2 <- comparisons$treatment2[k]
    ids <- sampleinfo$sample_name
    g1 <- paste0(ids, "_", t1); g2 <- paste0(ids, "_", t2)
    ok <- g1 %in% rownames(gmean) & g2 %in% rownames(gmean)
    d <- gmean[g1[ok], , drop = FALSE] - gmean[g2[ok], , drop = FALSE]
    colnames(d) <- wl_cols
    bind_cols(tibble(sample_name = ids[ok], treatment1 = t1, treatment2 = t2), as_tibble(d))
  })
}

refl_diff <- sample_differences(X)
vn_diff   <- sample_differences(X / sqrt(rowSums(X^2)))

# ---- check against the stored enumerated differences -----------------------
check_files <- list.files(file.path(data_root, "BootstrappedData"),
                          pattern = "\\.csv$", full.names = TRUE)
set.seed(1)
max_dev <- 0
for (f in sample(check_files, 12)) {
  m <- str_match(basename(f), "^(MILL24_[0-9]+)_([A-Z]+_[A-Z]+)_([A-Z]+_[A-Z]+)\\.csv$")
  stored <- colMeans(read.csv(f)[, wl_cols])
  mine <- refl_diff %>% filter(sample_name == m[2], treatment1 == m[3], treatment2 == m[4])
  if (nrow(mine) == 1) max_dev <- max(max_dev, abs(stored - unlist(mine[, wl_cols])))
}
message("max |stored mean of 36 differences - recomputed| over 12 files: ", signif(max_dev, 3))
stopifnot(max_dev < 1e-6)  # ~1e-7 is rounding between the two source CSVs

write.csv(vn_diff, file.path(out_dir, "vn_difference_by_sample.csv"), row.names = FALSE)

# ---- figure (same layout as BootstrapBiasChart.png) ------------------------
to_long <- function(d) {
  d %>%
    left_join(sampleinfo, by = "sample_name") %>%
    pivot_longer(all_of(wl_cols), names_to = "Wavelength", values_to = "Value") %>%
    mutate(Wavelength = as.integer(sub("^X", "", Wavelength)),
           Value = Value * 100) %>%
    left_join(comparisons, by = c("treatment1", "treatment2"))
}
long <- to_long(vn_diff)
treatment_mean <- long %>%
  group_by(Comparison, sublabel, Type, Wavelength) %>%
  summarize(Value = mean(Value), .groups = "drop")

p <- ggplot() +
  geom_line(data = long, aes(Wavelength, Value, group = sample_name),
            alpha = 0.3, linewidth = 1, color = "gray") +
  geom_abline(slope = 0, intercept = 0, color = "#737370", linewidth = 1) +
  geom_line(data = treatment_mean, aes(Wavelength, Value, color = Comparison),
            linewidth = 1) +
  theme_bw(base_size = 15) +
  facet_grid(sublabel + Comparison ~ Type, scale = "free_y") +
  scale_color_manual(values = c("#0000a2", "#50ad9f", "#e9c716", "#bc272d")) +
  ylab("Vector-normalized reflectance difference (x 100)") +
  xlab("Wavelength (nm)") +
  theme(legend.position = "none", strip.text = element_text(size = 15),
        axis.title = element_text(size = 20))

ggsave(file.path(out_dir, "VNDifferenceChart.png"), p, dpi = 300,
       scale = 4, width = 4, height = 3)

message("samples per panel: ",
        paste(capture.output(print(count(distinct(long, sample_name, Comparison, Type), Comparison, Type))),
              collapse = "\n"))
