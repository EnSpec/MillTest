####################################
#
# Spectral Statistics Calculations
#
# Author: Zach Breuer
#
# Project: Mill Test
#
# Date: 4/24/2026
#
####################################
library(tidyverse)

#Load in dataset for Mill Test spectral difference curve
bias <- read.csv("C:/Mill24/GitHub/General_Data/AllSamplesBIAS.csv") %>% 
  mutate(Sample_ID = substring(sample_name, 1, 11)) %>% 
  mutate
sampleinfo <- read.csv("C:/Mill24/GitHub/General_Data/sample_info.csv") %>% 
  select(Sample_ID, Type)

# Mutate sample identifying columns
bias <- bias %>%
  mutate(Sample_ID = substring(sample_name, 1, 11)) %>% 
  select(sample_name, Sample_ID, everything())

# Join sample information with data
bias <- full_join(bias, sampleinfo, join_by(Sample_ID))

# Filter necessary data
bias <- bias %>%
  select(sample_name, Sample_ID, Type, everything()) %>% 
   filter(Type == "Conifer" | Type == "Broadleaf")

# Pivot data frame to calculate stats
columnnames <- c("sample_name", "Sample_ID", "Type")
biaspivot = pivot_longer(bias, cols = !columnnames)
biaspivot = biaspivot %>% 
  rename(Wavelength = name) %>% 
  rename(PercentBias = value) %>% 
  mutate(millmethod1 = substring(sample_name, 13, 19)) %>% 
  mutate(millmethod2 = substring(sample_name, 35, 41)) %>% 
  mutate(Wavelength = strtoi(substring(Wavelength, 2)))

# All Data Averages

averagealldata = biaspivot %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisibledata = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700) %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))
  
averageNIRdata = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500) %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1data = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000) %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2data = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500) %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

# Broadleaf averages

averageallbroadleaf = averagevisiblebroadleaf = subset(biaspivot, Type == "Broadleaf") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisiblebroadleaf = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700 & Type == "Broadleaf") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageNIRbroadleaf = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500 & Type == "Broadleaf") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1broadleaf = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000 & Type == "Broadleaf") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2broadleaf = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500 & Type == "Broadleaf") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

# Conifer averages

averageallConifer = averagevisibleConifer = subset(biaspivot, Type == "Conifer") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averagevisibleConifer = subset(biaspivot, Wavelength >= 400 & Wavelength <= 700 & Type == "Conifer") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageNIRConifer = subset(biaspivot, Wavelength >= 701 & Wavelength <= 1500 & Type == "Conifer") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR1Conifer = subset(biaspivot, Wavelength >= 1501 & Wavelength <= 2000 & Type == "Conifer") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

averageSWIR2Conifer = subset(biaspivot, Wavelength >= 2001 & Wavelength <= 2500 & Type == "Conifer") %>% 
  group_by(millmethod1, millmethod2) %>% 
  summarize(Reflectance = mean(PercentBias))

