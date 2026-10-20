##################################################
#
# Title: Spectral variance among grinds under different normalizations
#
# Project: Mill Test 2024
#
# Purpose: Supplement. Does a per-spectrum normalization remove the spectral
# difference between grinds of the same sample (the particle-size effect)?
# Compared: no transform, vector normalization (VN) over 350-2500 nm (lab
# practice), VN over the modeled range only, and standard normal variate (SNV).
#
# Ported from EnSpec/dryspec-preprocessing (scripts/04_mill24_mechanism.R,
# R/transforms.R) so this repository is self-contained. Same design and
# numbers as that analysis, restricted to reflectance and the four transforms
# above.
#
# Method: for each transform, the total sum of squares of the preprocessed
# spectra over 1400-2450 nm (the PLSR predictor range) is split into nested
# parts, by one-way means at each level:
#   individual -- differences between plants
#   drying     -- FF vs OD within an individual
#   mill       -- among grinds within individual x drying (particle size)
#   replicate  -- among the 6 scans of one ground sample
# Shares are unitless, so they compare across transforms. A transform that
# targets particle size should shrink the mill share without shrinking the
# individual share.
#
# VN: Feilhauer et al. (2010) J. Quant. Spectrosc. Radiat. Transfer 111:1947.
# SNV: Barnes, Dhanoa & Lister (1989) Appl. Spectrosc. 43:772, eq. 1
# (standard deviation with n - 1).
#
# Out: derived/grind_variance/{variance_shares.csv,
#      variance_shares_by_wavelength.csv, GrindVarianceShare.png,
#      variance_shares_table.docx}
#
# Author: Mill Test Team, 2026
#
##################################################

library(tidyverse)
library(flextable)
library(officer)

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
out_dir <- file.path(data_root, "derived", "grind_variance")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

wl_full  <- 350:2500
wl_model <- 1400:2450

vector_normalize <- function(X) X / sqrt(rowSums(X^2))
snv <- function(X) {
  mu <- rowMeans(X)
  (X - mu) / sqrt(rowSums((X - mu)^2) / (ncol(X) - 1))
}

# each transform returns spectra over wl_model
transforms <- list(
  none     = function(X) X[, as.character(wl_model)],
  vn_full  = function(X) vector_normalize(X)[, as.character(wl_model)],  # norm over 350-2500
  vn_model = function(X) vector_normalize(X[, as.character(wl_model)]),  # norm over 1400-2450
  snv      = function(X) snv(X[, as.character(wl_model)]))

spec <- read.csv(file.path(data_root, "spectralpredictr",
                           "SpectralPredictR_raw_spectra.csv"), check.names = FALSE)
names(spec) <- sub("^X", "", names(spec))
stopifnot(!anyDuplicated(spec$sample_name), all(as.character(wl_full) %in% names(spec)))

# Restrict to the 61-tree / 11-species study design described in the methods,
# as in Table1_SpectralDifferenceRegions.R: drops the forbs, graminoid and the
# single honey locust (GLTR) that were scanned but are not part of the design.
design_ids <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  filter(Type %in% c("Broadleaf", "Conifer"), Species_Code != "GLTR") %>%
  pull(Sample_ID)
spec <- spec[substring(spec$sample_name, 1, 11) %in% design_ids, ]
stopifnot(n_distinct(substring(spec$sample_name, 1, 11)) == 61)
message("design spectra: ", nrow(spec), " scans from 61 trees")

# MILL24_<id>_<drying>_<milling>_<replicate>
parts <- str_split_fixed(spec$sample_name, "_", 5)
f_ind  <- paste(parts[, 1], parts[, 2], sep = "_")
f_dry  <- paste(f_ind, parts[, 3])
f_cell <- paste(f_dry, parts[, 4])
stopifnot(setequal(parts[, 3], c("FF", "OD")), setequal(parts[, 4], c("BALL", "SIXT", "TWEN")))

X_full <- as.matrix(spec[, as.character(wl_full)])

row_means <- function(X, g) rowsum(X, g)[g, , drop = FALSE] / as.vector(table(g)[g])

partition <- function(X) {
  grand <- matrix(colMeans(X), nrow(X), ncol(X), byrow = TRUE)
  m_ind <- row_means(X, f_ind); m_dry <- row_means(X, f_dry); m_cell <- row_means(X, f_cell)
  rbind(individual = colSums((m_ind - grand)^2),
        drying     = colSums((m_dry - m_ind)^2),
        mill       = colSums((m_cell - m_dry)^2),
        replicate  = colSums((X - m_cell)^2))
}

labels <- c(none = "No transform", vn_full = "VN (350-2500 nm)",
            vn_model = "VN (1400-2450 nm)", snv = "SNV")

per_wl <- imap(transforms, function(f, nm) partition(f(X_full)))

shares <- imap_dfr(per_wl, function(m, nm) {
  tot <- rowSums(m)
  tibble(transform = nm, component = names(tot), share = tot / sum(tot))
}) %>%
  pivot_wider(names_from = component, values_from = share) %>%
  mutate(mill_to_individual = mill / individual,
         label = labels[transform]) %>%
  select(transform, label, everything()) %>%
  arrange(mill)
write.csv(shares, file.path(out_dir, "variance_shares.csv"), row.names = FALSE)

by_wl <- imap_dfr(per_wl, function(m, nm) {
  as_tibble(t(m)) %>%
    mutate(wavelength = wl_model, transform = nm) %>%
    pivot_longer(individual:replicate, names_to = "component", values_to = "ss") %>%
    group_by(wavelength) %>% mutate(share = ss / sum(ss)) %>% ungroup()
})
write.csv(by_wl, file.path(out_dir, "variance_shares_by_wavelength.csv"), row.names = FALSE)

# ---- figure: grind share by wavelength -------------------------------------
fig <- by_wl %>%
  filter(component == "mill") %>%
  mutate(label = factor(labels[transform], levels = labels))
p <- ggplot(fig, aes(wavelength, 100 * share)) +
  geom_line(linewidth = 0.7, color = "#0000a2") +
  facet_wrap(~ label, nrow = 1) +
  labs(x = "Wavelength (nm)", y = "Share of variance among grinds (%)") +
  theme_bw(base_size = 12) +
  theme(strip.text = element_text(face = "bold"))
ggsave(file.path(out_dir, "GrindVarianceShare.png"), p,
       width = 30, height = 9, units = "cm", dpi = 300)

print(shares %>% mutate(across(where(is.numeric), ~ round(.x, 3))))

# ---- Word table (native, editable; same flextable style as Table 1) ---------
tab <- shares %>%
  mutate(transform = factor(transform, levels = names(labels))) %>%
  arrange(transform) %>%
  transmute(Normalization = label,
            `Individual trees` = 100 * individual,
            Drying = 100 * drying,
            Milling = 100 * mill,
            `Replicate scans` = 100 * replicate) %>%
  mutate(across(-Normalization, ~ sprintf("%.1f", .x)))

ft <- flextable(tab) %>%
  add_header_row(values = c("", "Share of spectral variance (%)"), colwidths = c(1, 4), top = TRUE) %>%
  align(align = "center", part = "all") %>%
  align(j = 1, align = "left", part = "all") %>%
  bold(part = "header") %>%
  border_remove() %>%
  hline(part = "all", border = fp_border(width = 0.75)) %>%
  vline(j = 1, border = fp_border(width = 0.75)) %>%
  fontsize(size = 10, part = "all") %>%
  width(j = 1, width = 1.8) %>%
  width(j = 2:5, width = 1.1)
save_as_docx(ft, path = file.path(out_dir, "variance_shares_table.docx"))

print(as.data.frame(tab))
