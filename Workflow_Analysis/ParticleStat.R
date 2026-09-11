##################################################
#
# Title: Particle Size Stat Calculations
#
# Project: Mill Test 2024
#
# Date: 1/22/2026
#
# Author: Zach Breuer, Mill Test Team
#
##################################################

# NOTE (2026-09-11): blocked on Zach staging particle_size/ParticleDataFull/
# (requested; not yet on the server). Paths de-hard-coded and the pivot_wider
# misuse below fixed, but this script has NOT been run against real data --
# see the FLAGs below for what still needs checking once it lands.

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "particle_size")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

csvfolder <- file.path(data_root, "particle_size", "ParticleDataFull")
file_list <- list.files(path = csvfolder, pattern = "*.csv")
listofdfs <- map(file_list, ~ read.csv(file.path(csvfolder, .x)))
names(listofdfs) <- basename(file_list)

# Edit list to isolate target statistics
# FLAG: magic row indices (507/530/532/531/49), unchecked against column
# layout -- confirm these still point at the right rows once real
# ParticleDataFull/ exports are available.

EditList <- lapply(names(listofdfs), function(x) {
  df <- listofdfs[[x]] %>%
    dplyr::slice(c(507, 530, 532, 531, 49))
})
names(EditList) <- basename(file_list)
EditList <- EditList %>%
  map(
    # was `values_from = .data$X` -- .data$X evaluates to a vector, not a
    # valid tidyselect spec; pivot_wider wants the column itself.
    ~ pivot_wider(.x, names_from = X.common., values_from = X)) %>%
  map(
    ~ mutate(.x, Mean = as.double(Mean), Variance = as.double(Variance), Skew = as.double(Skew), Kurtosis = as.double(Kurtosis))) %>%
   map(
    ~ mutate(.x, Kurtosis = Kurtosis + 3))

# Divide dataframes by milling treatment
# FLAG: the manuscript methods describe moments "averaged by growth form x
# milling treatment (22 individuals)" -- this only splits by milling
# treatment (BALL/TWEN/SIXT via a GroupID grep), with no growth-form
# (broadleaf/conifer) split at all. GroupID's format/what it encodes is
# unknown without real ParticleDataFull/ exports; can't safely add the
# growth-form join until that lands. Confirm with Zach/Henry whether growth
# form needs to be crossed in here, and how GroupID maps to Sample_ID.

BallList <- keep(
  EditList,
  ~ any(grepl("BALL", .x[["GroupID"]]), na.rm = TRUE)
)
TwenList <- keep(
  EditList,
  ~ any(grepl("TWEN", .x[["GroupID"]]), na.rm = TRUE)
)
FineList <- keep(
  EditList,
  ~ any(grepl("SIXT", .x[["GroupID"]]), na.rm = TRUE)
)

# Clean data frames and calculate means of target statistics

BallList <- BallList %>%  map(
  ~ select(.x, Mean, Variance, Skew, Kurtosis))
BallMeans <- bind_rows(BallList) %>% 
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(Skew), Kurtosis = mean(Kurtosis))
TwenList <- TwenList %>%  map(
  ~ select(.x, Mean, Variance, Skew, Kurtosis))
TwenMeans <- bind_rows(TwenList) %>% 
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(Skew), Kurtosis = mean(Kurtosis))
FineList <- FineList %>%  map(
  ~ select(.x, Mean, Variance, Skew, Kurtosis))
FineMeans <- bind_rows(FineList) %>% 
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(Skew), Kurtosis = mean(Kurtosis))
BallAbsMeans <- bind_rows(BallList) %>% 
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(abs(Skew)), Kurtosis = mean(abs(Kurtosis)))
TwenAbsMeans <- bind_rows(TwenList) %>% 
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(abs(Skew)), Kurtosis = mean(abs(Kurtosis)))
FineAbsMeans <- bind_rows(FineList) %>%
  summarise(Mean = mean(Mean), Variance = mean(Variance), Skew = mean(abs(Skew)), Kurtosis = mean(abs(Kurtosis)))

# Collect and write results -- previously computed but never saved anywhere.
particle_summary <- bind_rows(
  BallMeans     %>% mutate(MillingTreatment = "BALL", Metric = "raw"),
  TwenMeans     %>% mutate(MillingTreatment = "TWEN", Metric = "raw"),
  FineMeans     %>% mutate(MillingTreatment = "SIXT", Metric = "raw"),
  BallAbsMeans  %>% mutate(MillingTreatment = "BALL", Metric = "abs_skew_kurtosis"),
  TwenAbsMeans  %>% mutate(MillingTreatment = "TWEN", Metric = "abs_skew_kurtosis"),
  FineAbsMeans  %>% mutate(MillingTreatment = "SIXT", Metric = "abs_skew_kurtosis")
) %>%
  relocate(MillingTreatment, Metric)

print(particle_summary)
write.csv(particle_summary, file.path(out_dir, "particle_size_summary.csv"),
          row.names = FALSE)

