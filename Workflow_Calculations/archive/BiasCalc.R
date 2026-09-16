##############################################
#
# Title: Bias Calculation for Spectral Data
#
# Project: Mill Test 2024
#
# Date: 3/18/2025
#
# Authors: Zach Breuer, Mill Test Team
#
##############################################

# Set working directory and load in necessary libraries
setwd("C:/Mill24/data/VectorNormalized/Bias/VN")
library(tidyverse)
set.seed(1030)
# Select data to carry out bias calculation on
spectraldata <- read.csv("C:/Mill24/SpectraUpdated/Mill24_RawSpec.csv")

# Define function as biascalc
biascalc <- function(spectraldata, SampleID, biasfilename, RMSEfilename, rRMSEfilename) {
  # Filter spectraldata based on SampleID and average the different measurements
  spectraldataavg <- spectraldata %>% mutate(sample_name = substring(sample_name, 1, 19)) 
  %>% group_by(sample_name) 
  %>% summarize(across(everything(), mean, na.rm = TRUE))
  
  spectraldatasubset <- spectraldataavg %>% filter(str_detect(sample_name, SampleID))
  
  #Make new data frame for bias statistics
  biasdf <- data.frame(matrix(ncol = ncol(spectraldatasubset), nrow = 0))
  colnames(biasdf) <- colnames(spectraldatasubset)
  
  # Create for loop that names rows according to what samples are being compared
  row_counter <- 1
  for(x in 1:(nrow(spectraldatasubset) - 1)) {
    for(y in (x + 1):nrow(spectraldatasubset)) {
      biasdf[row_counter, 1] <-  paste(spectraldatasubset[x, 1], spectraldatasubset[y, 1], sep = " - ")
      
      # Advance through wavelengths subtracting one sample reflectance from the other
      for(q in 2:ncol(spectraldatasubset)) {
        biasdf[row_counter, q] <- spectraldatasubset[x, q] - spectraldatasubset[y, q]
      }
      row_counter = row_counter + 1
    }
  }
  write.csv(biasdf, biasfilename, row.names = FALSE)
  
  # Create data frame of squared bias statistics
  squareddf <- biasdf
  for(y in 1:nrow(biasdf)){
    for(x in 2:ncol(biasdf)) {
      squareddf[y, x] <- biasdf[y,x] ^ 2
    }
  }
  
  # Create data frame for and calculate RMSE
  RMSEdf = matrix(data =, nrow = 1, ncol = ncol(squareddf))
  colnames(RMSEdf) <- colnames(squareddf) 
  RMSEdf[,1] = substring(squareddf[1,1], 1, 11)
  
  for(y in 2:ncol(squareddf)) {
    RMSEdf[1, y] <- sqrt(sum(squareddf[1:nrow(squareddf), y]) / nrow(squareddf))
  }
  
  write.csv(RMSEdf, RMSEfilename, row.names = FALSE)
  
  # Calculate and create rRMSE data frame
  avgdf <- spectraldatasubset %>% summarize(across(2:ncol(spectraldatasubset), mean)) %>% mutate(sample_name = SampleID) %>% select(sample_name, everything())
  rRMSEdf <- matrix(data =, nrow = 1, ncol = ncol(RMSEdf))
  colnames(rRMSEdf) <- colnames(RMSEdf)
  rRMSEdf[1,1] <- RMSEdf[1,1]
  
  for (y in 2:ncol(rRMSEdf)) {
    rRMSEdf[1, y] <- as.numeric(RMSEdf[1, y]) / as.numeric(avgdf[[y]])
  }
  
  write.csv(rRMSEdf, rRMSEfilename, row.names = FALSE)
  
}




