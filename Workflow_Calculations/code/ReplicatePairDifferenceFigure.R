#############################################
#
# Replicate-Pair Difference Figure and Stats
#
# Authors: Mill Test Team
#
# Project: Mill Test
#
# Date: 5/5/2026
#
##############################################

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "replicate_pair_differences")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

file_list <- list.files(path = file.path(data_root, "ReplicatePairDifferences"), pattern = ".csv", full.names = TRUE)

BootDataFull <- lapply(file_list, read.csv) %>%
  bind_rows()


sampleinfo <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  rename(sample_name = Sample_ID) %>%
  select(sample_name, Species_Code, Type)

# Restrict to the 61-tree / 11-species study design described in the methods:
# drops the forbs and graminoid and the single honey locust (GLTR), matching
# Table1_SpectralDifferenceRegions.R and Predicted_Trait_Analysis.R.
BootDataSampleMean <- BootDataFull %>% 
  group_by(sample_name, treatment1, treatment2) %>% 
  summarize(across(everything(), mean)) %>% 
  mutate(stat = "Sample")

BootDataSampleMean <- full_join(BootDataSampleMean, sampleinfo, join_by(sample_name)) %>% 
  select(sample_name, treatment1, treatment2, Type, everything()) %>%
  filter(Type %in% c("Broadleaf", "Conifer"), Species_Code != "GLTR") %>%
  select(-Species_Code) %>%
  mutate(Type = recode(Type, "Conifer" = "Needle-Leaf")) %>% 
  drop_na()


columnnames <- c("sample_name", "Type", "treatment1", "treatment2", "stat")

BootDataSamplePivot <- pivot_longer(BootDataSampleMean, cols = !all_of(columnnames)) %>% 
  rename(Wavelength = name, Reflectance = value) %>% 
  mutate(Wavelength = strtoi(substring(Wavelength, 2)))

BootDataTreatmentMean <- BootDataSamplePivot %>% 
  group_by(treatment1, treatment2, Wavelength, Type) %>% 
  summarize(Reflectance = mean(Reflectance)) %>% 
  mutate(sample_name = paste0(Type, treatment1, treatment2)) %>% 
  mutate(stat = "Mean")

BootData <- full_join(BootDataSamplePivot, BootDataTreatmentMean) %>% 
  mutate(Comparison = case_when(
    treatment1 == "FF_TWEN" & treatment2 == "OD_TWEN" ~ "Freeze Dried - Oven Dried",
    treatment1 == "OD_SIXT" & treatment2 == "OD_TWEN" ~ "Fine - Coarse",
    treatment1 == "OD_BALL" & treatment2 == "OD_TWEN" ~ "Ball - Coarse",
    treatment1 == "OD_BALL" & treatment2 == "OD_SIXT" ~ "Ball - Fine"
  )) %>% 
  mutate(sublabel = case_when(
    treatment1 == "FF_TWEN" & treatment2 == "OD_TWEN" ~ "D",
    treatment1 == "OD_SIXT" & treatment2 == "OD_TWEN" ~ "C",
    treatment1 == "OD_BALL" & treatment2 == "OD_TWEN" ~ "A",
    treatment1 == "OD_BALL" & treatment2 == "OD_SIXT" ~ "B")) %>% 
  mutate(Reflectance = Reflectance * 100)

workingplot = ggplot() +
  geom_line(data = subset(BootData, stat == "Sample"),
            aes(x = Wavelength, y = Reflectance, group = sample_name),
            alpha = 0.3, linewidth = 1, color = "gray") +
  geom_abline(slope = 0, intercept = 0, color = "#737370", linewidth = 1) +
  geom_line(data = subset(BootData, stat == "Mean"),
            aes(x = Wavelength, y = Reflectance, group = sample_name, color = Comparison), 
            linewidth = 1) +
  theme_bw(base_size = 15) +
  facet_grid(sublabel + Comparison ~ Type, scale = "free_y") +
  scale_color_manual(values = c("#0000a2", "#50ad9f", "#e9c716", "#bc272d")) +
  ylab("Reflectance difference (percentage points)") +
  xlab("Wavelength (nm)") +
  theme(legend.position = "none", strip.text = element_text(size = 15), axis.title = element_text(size = 20)) 
workingplot

ggsave(file.path(out_dir, "ReplicatePairDifferenceChart.png"), workingplot, dpi = 300, scale = 4, width = 4, height = 3)

# Region-by-growth-form summaries of these differences (Table 1) are computed in
# Table1_SpectralDifferenceRegions.R, and per-wavelength peaks in
# SpectralDifferenceCurves.R.
