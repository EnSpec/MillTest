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

# Set working directory, load in necessary libraries, and load in data with proper names
library(tidyverse)
setwd("Z:/projects/Mill24/particle_size/data/full")
csvfolder <- "Z:/projects/Mill24/particle_size/data/full"
file_list <- list.files(path = csvfolder, pattern = "*.csv")
listofdfs <- map(file_list, read.csv)
names(listofdfs) <- basename(file_list)

# Edit list to isolate target statistics

EditList <- lapply(names(listofdfs), function(x) {
  df <- listofdfs[[x]] %>% 
    dplyr::slice(c(507, 530, 532, 531, 49))
})
names(EditList) <- basename(file_list)
EditList <- EditList %>% 
  map(
    ~ pivot_wider(.x, names_from = X.common., values_from = .data$X)) %>% 
  map(
    ~ mutate(.x, Mean = as.double(Mean), Variance = as.double(Variance), Skew = as.double(Skew), Kurtosis = as.double(Kurtosis))) %>% 
   map(
    ~ mutate(.x, Kurtosis = Kurtosis + 3))

# Divide dataframes by milling treatment

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


