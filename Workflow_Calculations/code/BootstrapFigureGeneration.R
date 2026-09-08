#############################################
#
# Bootstrapped Code Visualizations and Stats
#
# Authors: Mill Test Team
#
# Project: Mill Test
#
# Date: 5/5/2026
#
##############################################

library(tidyverse)
setwd("C:/Mill24/Bootstrapped")

file_list <- list.files(path = "C:/Mill24/data/BootstrappedData", pattern = ".csv", full.names = TRUE)

BootDataFull <- lapply(file_list, read.csv) %>% 
  bind_rows()


sampleinfo <- read.csv("C:/Mill24/data/DiffCalcRawSpectra/ConiferVsBroadleaf/sample_info.csv") %>% 
  rename(sample_name = Sample_ID) %>% 
  select(sample_name, Type)

BootDataSampleMean <- BootDataFull %>% 
  group_by(sample_name, treatment1, treatment2) %>% 
  summarize(across(everything(), mean)) %>% 
  mutate(stat = "Sample")

BootDataSampleMean <- full_join(BootDataSampleMean, sampleinfo, join_by(sample_name)) %>% 
  select(sample_name, treatment1, treatment2, Type, everything()) %>% 
  filter(Type != "Forb") %>% 
  filter(Type != "Graminoid") %>% 
  mutate(Type = recode(Type, "Conifer" = "Needle-Leaf")) %>% 
  drop_na()


columnnames <- c("sample_name", "Type", "treatment1", "treatment2", "stat")

BootDataSamplePivot <- pivot_longer(BootDataSampleMean, cols = !columnnames) %>% 
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
            aes(x = Wavelength, y = Reflectance, group = sample_name, color = Stat), 
            alpha = 0.3, linewidth = 1, color = "gray") +
  geom_abline(slope = 0, intercept = 0, color = "#737370", linewidth = 1) +
  geom_line(data = subset(BootData, stat == "Mean"),
            aes(x = Wavelength, y = Reflectance, group = sample_name, color = Comparison), 
            linewidth = 1) +
  theme_bw(base_size = 15) +
  facet_grid(sublabel + Comparison ~ Type, scale = "free_y") +
  scale_color_manual(values = c("#0000a2", "#50ad9f", "#e9c716", "#bc272d")) +
  ylab("Reflectance (%) Difference") +
  xlab("Wavelength (nm)") +
  theme(legend.position = "none", strip.text = element_text(size = 15), axis.title = element_text(size = 20)) 
workingplot

ggsave("BootstrapBiasChart.png", workingplot, dpi = 300, scale = 4, width = 4, height = 3)

# Calculations for difference summaries

bias <- BootDataSampleMean

# Filter necessary data
bias <- bias %>%
  select(sample_name, Type, everything()) %>% 
  filter(Type == "Conifer" | Type == "Broadleaf") %>% 
  select(-stat)

# Pivot data frame to calculate stats
columnnames <- c("sample_name", "Type", "treatment1", "treatment2")
biaspivot = pivot_longer(bias, cols = !columnnames)
biaspivot = biaspivot %>% 
  rename(Wavelength = name) %>% 
  rename(PercentBias = value) %>% 
  mutate(Wavelength = strtoi(substring(Wavelength, 2)))

# All Data Averages

averagealldata = biaspivot %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisibledata = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700) %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageNIRdata = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500) %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1data = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000) %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2data = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500) %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

# Broadleaf averages

averageallBroadleaf = subset(biaspivot, Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisiblebroadleaf = subset(biaspivot, Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisiblebroadleaf = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700 & Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageNIRbroadleaf = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500 & Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1broadleaf = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000 & Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2broadleaf = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500 & Type == "Broadleaf") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

# Conifer averages

averageallConifer = subset(biaspivot, Type == "Conifer") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisibleConifer = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700 & Type == "Conifer") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageNIRConifer = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500 & Type == "Conifer") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1Conifer = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000 & Type == "Conifer") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2Conifer = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500 & Type == "Conifer") %>% 
  group_by(treatment1, treatment2) %>% 
  summarize(Reflectance = mean(PercentBias))







