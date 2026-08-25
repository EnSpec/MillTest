###########################################################
#
# Title: Bias Calculation and Visualization, Raw
#
# Project: Mill Test 2024
#
# Date: 12/11/2026
#
# Author: Zach Breuer, Mill Test Team
#
###########################################################

# Set working directory and load in necessary libraries
setwd("C:/Mill24/data/VectorNormalized")
library(tidyverse)
library(cowplot)

# Set folder path and read in files from folder
folder_path <- "C:/Mill24/data/VectorNormalized/Bias/Raw"
file_list <- list.files(path = folder_path, pattern = "*.csv", full.names = TRUE)
combined_df <- file_list %>%
  lapply(read_csv) %>%
  bind_rows()

write.csv(combined_df, "AllSamplesBIAS.csv", row.names = FALSE)


# Create Graphs for  Data

# Read in sample information
sampleinfo <- read.csv("C:/Mill24/data/DiffCalcRawSpectra/ConiferVsBroadleaf/sample_info.csv")

# Mutate sample identifying columns
samplebias <- combined_df %>%
  mutate(Sample_ID = substring(sample_name, 1, 11)) %>% 
  select(sample_name, Sample_ID, everything())

# Join sample information with data
samplebias <- full_join(samplebias, sampleinfo, join_by(Sample_ID))

# Filter necessary data
samplebias <- samplebias %>%
  select(sample_name, Sample_ID, Type, everything()) %>% 
  select(-Species_Code, -Sampling_Date, -X_Coord, -Y_Coord, -Fresh_mass, -Dry_mass, -Species, -Water_Content, -Chl1, -Chl2, -Chl3, -Chl4, -Chl5, -ScientificName) %>% 
  filter(Type == "Conifer" | Type == "Broadleaf")

# Pivot data frame to graph data
columnnames <- c("sample_name", "Sample_ID", "Type")
samplebiaspivot = pivot_longer(samplebias, cols = !columnnames)
samplebiaspivotdouble = samplebiaspivot %>% 
  rename(Wavelength = name) %>% 
  rename(PercentBias = value) %>% 
  mutate(millmethod1 = substring(sample_name, 13, 19)) %>% 
  mutate(millmethod2 = substring(sample_name, 35, 41))

# Isolate sample by comparison type, add in description variables, calculate mean bias by wavelength, and join together again
samplebiasODBALLTWENBroadleafSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_BALL" & millmethod2 == "OD_TWEN" & Type == "Broadleaf") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>%
  mutate(Type = "Broadleaf") %>% 
  mutate(MillMethods = "Ball - Coarse") %>% 
  mutate(Stat = "Sample") %>% 
  mutate(PercentBias = PercentBias) %>% 
  select(-millmethod1, -millmethod2, -Sample_ID) %>% 
  mutate(sublabel = "a")


samplebiasODBALLTWENBroadleafMean <- samplebiasODBALLTWENBroadleafSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Ball - Coarse") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(Type = "Broadleaf") %>% 
  mutate(sample_name = "Comparison1MeanBroadleaf") %>% 
  mutate(sublabel = "a")

samplebiasODSIXTTWENBroadleafSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_SIXT" & millmethod2 == "OD_TWEN" & Type == "Broadleaf") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  group_by(Wavelength) %>%
  mutate(Type = "Broadleaf") %>% 
  mutate(MillMethods = "Fine - Coarse") %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2,-Sample_ID) %>% 
  mutate(sublabel = "c")

samplebiasODSIXTTWENBroadleafMean <- samplebiasODSIXTTWENBroadleafSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Fine - Coarse") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(Type = "Broadleaf") %>% 
  mutate(sample_name = "Comparison2MeanBroadleaf") %>% 
  mutate(sublabel = "c")


samplebiasODBALLSIXTBroadleafSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_BALL" & millmethod2 == "OD_SIXT" & Type == "Broadleaf") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  group_by(Wavelength) %>%
  mutate(Type = "Broadleaf") %>% 
  mutate(MillMethods = "Ball - Fine") %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2, -Sample_ID) %>% 
  mutate(sublabel = "b")

samplebiasODBALLSIXTBroadleafMean <- samplebiasODBALLSIXTBroadleafSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Ball - Fine") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(Type = "Broadleaf") %>% 
  mutate(sample_name = "Comparison3MeanBroadleaf") %>% 
  mutate(sublabel = "b")

samplebiasODBALLTWENConiferSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_BALL" & millmethod2 == "OD_TWEN" & Type == "Conifer") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  group_by(Wavelength) %>%
  mutate(Type = "Conifer") %>% 
  mutate(MillMethods = "Ball - Coarse") %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2, -Sample_ID) %>% 
  mutate(sublabel = "a")

samplebiasODBALLTWENConiferMean <- samplebiasODBALLTWENConiferSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Ball - Coarse") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(sample_name = "Comparison1MeanConifer") %>% 
  mutate(Type = "Conifer") %>% 
  mutate(sublabel = "a")

samplebiasODSIXTTWENConiferSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_SIXT" & millmethod2 == "OD_TWEN" & Type == "Conifer") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  group_by(Wavelength) %>%
  mutate(Type = "Conifer") %>% 
  mutate(MillMethods = "Fine - Coarse") %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2, -Sample_ID) %>% 
  mutate(sublabel = "c")

samplebiasODSIXTTWENConiferMean = samplebiasODSIXTTWENConiferSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Fine - Coarse") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(Type = "Conifer") %>% 
  mutate(sample_name = "Comparison2MeanConifer") %>% 
  mutate(sublabel = "c")

samplebiasODBALLSIXTConiferSample <- samplebiaspivotdouble %>% 
  filter(millmethod1 == "OD_BALL" & millmethod2 == "OD_SIXT" & Type == "Conifer") %>% 
  mutate(Wavelength = substring(Wavelength, 2)) %>%
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  group_by(Wavelength) %>%
  mutate(Type = "Conifer") %>% 
  mutate(MillMethods = "Ball - Fine") %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2, -Sample_ID) %>% 
  mutate(sublabel = "b")

samplebiasODBALLSIXTConiferMean <- samplebiasODBALLSIXTConiferSample %>% 
  group_by(Wavelength) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(MillMethods = "Ball - Fine") %>% 
  mutate(Stat = "Mean") %>% 
  mutate(Type = "Conifer") %>% 
  mutate(sample_name = "Comparison3MeanConifer") %>% 
  mutate(sublabel = "b")

samplebiasODFF = samplebiaspivotdouble %>% 
  filter(millmethod1 == "FF_TWEN" & millmethod2 == "OD_TWEN") %>%
  mutate(Wavelength = substring(Wavelength, 2)) %>% 
  mutate(Wavelength = strtoi(Wavelength)) %>% 
  mutate(PercentBias = PercentBias) %>% 
  mutate(Stat = "Sample") %>% 
  select(-millmethod1, -millmethod2) %>% 
  mutate(MillMethods = "Freeze Dried - Oven Dried") %>% 
  mutate(sublabel = "d")

samplebiasODFFMean = samplebiasODFF %>% 
  group_by(Wavelength, Type) %>% 
  summarize(PercentBias = mean(PercentBias)) %>% 
  mutate(Stat = "Mean") %>% 
  mutate(sample_name = paste0(Type, "ODFFMean")) %>%
  mutate(MillMethods = "Freeze Dried - Oven Dried") %>% 
  mutate(sublabel = "d")


samplebiaspivotOD <- full_join(samplebiasODBALLSIXTBroadleafSample, samplebiasODBALLSIXTBroadleafMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODSIXTTWENBroadleafMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODSIXTTWENBroadleafSample)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLTWENBroadleafMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLTWENBroadleafSample)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLSIXTConiferMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLSIXTConiferSample)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODSIXTTWENConiferMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODSIXTTWENConiferSample)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLTWENConiferMean)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODBALLTWENConiferSample)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODFF)
samplebiaspivotOD <- full_join(samplebiaspivotOD, samplebiasODFFMean)

mean(subset(samplebiaspivotOD, MillMethods == "Fine - Coarse" & Stat == "Mean")$PercentBias)
mean(subset(samplebiaspivotOD, MillMethods == "Freeze Dried - Oven Dried" & Stat == "Mean")$PercentBias)

samplebiaspivotOD = samplebiaspivotOD %>% 
  mutate(PercentBias = PercentBias * 100)

workingplot = ggplot() +
  geom_line(data = subset(samplebiaspivotOD, Stat == "Sample"), 
            aes(x = Wavelength, y = PercentBias, group = sample_name, color = Stat), 
            alpha = 0.3, linewidth = 1, color = "gray") +
  geom_abline(slope = 0, intercept = 0, color = "#737370", linewidth = 1) +
  geom_line(data = subset(samplebiaspivotOD, Stat == "Mean"),
            aes(x = Wavelength, y = PercentBias, group = sample_name, color = MillMethods), 
            linewidth = 1) +
  theme_bw(base_size = 15) +
  facet_grid(sublabel + MillMethods ~ Type, scale = "free_y") +
  scale_color_manual(values = c("#0000a2", "#50ad9f", "#e9c716", "#bc272d")) +
  ylab("Reflectance (%) Difference") +
  xlab("Wavelength (nm)") +
  theme(legend.position = "none", strip.text = element_text(size = 15), axis.title = element_text(size = 20)) 

ggsave("BiasChart.png", workingplot, path = "C:/Mill24/Figures/CompletedFigures", dpi = 300, scale = 4, width = 4, height = 3)

