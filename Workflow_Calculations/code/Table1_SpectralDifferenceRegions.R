##################################################
#
# Title: Table 1 - Mean Spectral Difference by Region
#
# Project: Mill Test 2024
#
# Purpose: Regenerate the manuscript's Table 1 (mean reflectance-percentage-
# point difference by spectral region, treatment comparison, and growth
# form) directly from BootstrappedData/ in R, replacing the hand-typed LaTeX
# table (Zach Breuer, Nov 2025) to remove any risk of transcription error.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
boot_dir <- file.path(data_root, "BootstrappedData")
out_dir  <- file.path(data_root, "derived", "spectral_difference")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  select(Sample_ID, Type) %>%
  distinct()

# --- spectral regions (per manuscript Table 1) ------------------------------

regions <- list(
  "Entire Spectral Range"                  = c(350, 2500),
  "Visible (400 nm-700 nm)"                = c(400, 700),
  "Near Infrared (701 nm-1500 nm)"         = c(701, 1500),
  "Short Wave Infrared 1 (1501 nm-2000 nm)" = c(1501, 2000),
  "Short Wave Infrared 2 (2001 nm-2500 nm)" = c(2001, 2500)
)

# --- the 4 comparisons BootstrapCode.R produces -----------------------------
# file name = <SampleID>_<treatment1>_<treatment2>.csv; each row is already
# treatment1[i,] - treatment2[j,] (raw fractional reflectance), one row per
# of the 36 exhaustive replicate-pair combinations. Percentage-point values
# in the manuscript text/table are this fractional difference x 100.

comparison_labels <- c(
  "OD_BALL_OD_TWEN" = "Ball - Coarse",
  "OD_BALL_OD_SIXT" = "Ball - Fine",
  "OD_SIXT_OD_TWEN" = "Fine - Coarse",
  "FF_TWEN_OD_TWEN" = "Freeze Dried - Oven Dried"
)

# --- read every file, compute one per-sample-per-region value at a time ----
# (equivalent to the two-stage "mean per sample, then mean across samples"
# described in the methods -- every sample contributes exactly 36 rows, so a
# flat grand mean over (rows x region wavelength columns) is mathematically
# identical to averaging within sample first, then across samples.)

files <- list.files(boot_dir, pattern = "\\.csv$", full.names = TRUE)

read_one <- function(path) {
  fname <- tools::file_path_sans_ext(basename(path))
  # <SampleID>_<treatment1 (2 tokens)>_<treatment2 (2 tokens)>
  m <- str_match(fname, "^(MILL24_[0-9]+)_([A-Z]+_[A-Z]+)_([A-Z]+_[A-Z]+)$")
  sample_id  <- m[, 2]
  comparison <- comparison_labels[paste(m[, 3], m[, 4], sep = "_")]

  d <- read.csv(path)
  wl_cols <- grep("^X[0-9]+$", names(d), value = TRUE)
  wls <- as.numeric(sub("^X", "", wl_cols))

  region_means <- map_dbl(regions, function(rng) {
    cols <- wl_cols[wls >= rng[1] & wls <= rng[2]]
    mean(as.matrix(d[, cols]), na.rm = TRUE) * 100
  })

  tibble(
    Sample_ID  = sample_id,
    Comparison = comparison,
    Region     = names(regions),
    Value      = region_means
  )
}

per_sample_region <- map(files, read_one) %>%
  bind_rows() %>%
  left_join(sample_info, by = "Sample_ID")

if (any(is.na(per_sample_region$Type))) {
  warning(sprintf("%d rows have no Type match against sample_info.csv",
                  sum(is.na(per_sample_region$Type))))
}

# --- aggregate: All Data / Broadleaf / Conifer, for each comparison x region

summarise_group <- function(df, group_label) {
  df %>%
    group_by(Comparison, Region) %>%
    summarise(Value = mean(Value), .groups = "drop") %>%
    mutate(Group = group_label)
}

broadleaf_summary <- summarise_group(filter(per_sample_region, Type == "Broadleaf"), "Broadleaved")
conifer_summary   <- summarise_group(filter(per_sample_region, Type == "Conifer"), "Needle-Leaved")

# "All Data" is the unweighted average of the two growth-form means, not a
# flat pool of every sample -- confirmed against Zach's original hand-typed
# table (Nov 2025): pooling all samples directly (unequal Broadleaf/Conifer
# n) gives values consistently ~5-10% higher than his "All Data" column,
# while (Broadleaved + Needle-Leaved)/2 reproduces it almost exactly. This
# matches the growth-form-balanced averaging already used for particle size
# (ParticleStat.R).
all_data_summary <- broadleaf_summary %>%
  rename(BL = Value) %>%
  left_join(conifer_summary %>% rename(NL = Value) %>% select(-Group),
            by = c("Comparison", "Region")) %>%
  mutate(Value = (BL + NL) / 2, Group = "All Data") %>%
  select(Comparison, Region, Value, Group)

table1_long <- bind_rows(all_data_summary, broadleaf_summary, conifer_summary) %>%
  mutate(
    Region     = factor(Region, levels = names(regions)),
    Comparison = factor(Comparison, levels = unname(comparison_labels)),
    Group      = factor(Group, levels = c("All Data", "Broadleaved", "Needle-Leaved"))
  ) %>%
  arrange(Comparison, Region, Group)

write.csv(table1_long, file.path(out_dir, "table1_spectral_regions_long.csv"), row.names = FALSE)

# --- wide layout matching the manuscript's Table 1 (regions x (comparison x group)) ---

table1_wide <- table1_long %>%
  mutate(col = paste(Comparison, Group, sep = " | ")) %>%
  select(Region, col, Value) %>%
  pivot_wider(names_from = col, values_from = Value) %>%
  arrange(Region)

write.csv(table1_wide, file.path(out_dir, "table1_spectral_regions_wide.csv"), row.names = FALSE)

# --- LaTeX table, same layout as Zach's original hand-typed version --------

fmt <- function(x) sprintf("%.2f", x)
v <- function(comparison, group, region) {
  table1_long %>%
    filter(Comparison == comparison, Group == group, Region == region) %>%
    pull(Value) %>%
    fmt()
}

tex_lines <- c(
"\\documentclass{article}",
"\\usepackage{graphicx} % Required for inserting images",
"\\usepackage{adjustbox}",
"\\title{Mill Charts}",
"\\author{Mill Test Team (generated by Table1\\_SpectralDifferenceRegions.R)}",
"\\date{}",
"",
"\\begin{document}",
"",
"\\begin{table}[]",
"\\begin{adjustbox}{width=1\\textwidth}",
"\\begin{tabular}{c||c|c|c||c|c|c|}",
"",
"& \\multicolumn{3}{|c||}{Ball - Coarse} & \\multicolumn{3}{|c|}{Ball - Fine} \\\\",
"",
"Spectral Region & All Data & Broadleaved & Needle-Leaved & All Data & Broadleaved & Needle-Leaved\\\\ \\hline",
"")

for (region in names(regions)) {
  tex_lines <- c(tex_lines, sprintf(
    "%s & %s & %s & %s & %s & %s & %s\\\\ \\hline",
    region,
    v("Ball - Coarse", "All Data", region), v("Ball - Coarse", "Broadleaved", region), v("Ball - Coarse", "Needle-Leaved", region),
    v("Ball - Fine", "All Data", region),   v("Ball - Fine", "Broadleaved", region),   v("Ball - Fine", "Needle-Leaved", region)
  ))
}

tex_lines <- c(tex_lines, "\\hline",
"",
"& \\multicolumn{3}{|c||}{Fine - Coarse} & \\multicolumn{3}{|c|}{Freeze Dried - Oven Dried} \\\\",
"",
"Spectral Region & All Data & Broadleaved & Needle-Leaved & All Data & Broadleaved & Needle-Leaved\\\\ \\hline",
"")

for (region in names(regions)) {
  tex_lines <- c(tex_lines, sprintf(
    "%s & %s & %s & %s & %s & %s & %s\\\\ \\hline",
    region,
    v("Fine - Coarse", "All Data", region), v("Fine - Coarse", "Broadleaved", region), v("Fine - Coarse", "Needle-Leaved", region),
    v("Freeze Dried - Oven Dried", "All Data", region), v("Freeze Dried - Oven Dried", "Broadleaved", region), v("Freeze Dried - Oven Dried", "Needle-Leaved", region)
  ))
}

tex_lines <- c(tex_lines,
"",
"\\end{tabular}",
"\\end{adjustbox}",
"\\end{table}",
"\\end{document}")

writeLines(tex_lines, file.path(out_dir, "table1.tex"))

print(as.data.frame(table1_wide))
cat(sprintf("\nWrote %s, %s, %s\n",
           file.path(out_dir, "table1_spectral_regions_long.csv"),
           file.path(out_dir, "table1_spectral_regions_wide.csv"),
           file.path(out_dir, "table1.tex")))
