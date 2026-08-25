#########################################################
#
# Mill Test Bootstrap Resampling
#
# Authors: Mill Test Team
#
# Project: Mill Test
#
# Date: 4/29/2026
#
##########################################################

library(tidyverse)
library(boot)
library(doParallel)
library(foreach)
library(gtools)
setwd("C:/Users/zbreuer/Mill24/BootstrappedData")

set.seed(0220)
cores <-  detectCores() - 1
cluster <- makeCluster(cores)
registerDoParallel(cluster)


spectraldata <- read.csv("C:/Users/zbreuer/MillTestGit/MillTest/General_Data/Mill24_RawSpec.csv") %>% 
  mutate(SampleID = substring(sample_name, 1, 11))


iteration = 1500

for(sample in unique(spectraldata$SampleID)) {
spectraldatasubset <- spectraldata %>% 
  filter(SampleID == sample) %>%
  mutate(treatment = substring(sample_name, 13, 19)) %>% 
  select(sample_name, treatment, SampleID, everything())

treatmentcombination = as.data.frame(combinations(6, 2, spectraldatasubset[[2]], repeats = FALSE)) %>% 
  slice(12:15)
output = list()
  for(e in 1:nrow(treatmentcombination)) {
 
    treatment1 = spectraldatasubset %>%  
      filter(treatment == treatmentcombination[e, 1])
    
    treatment2 = spectraldatasubset %>% 
      filter(treatment == treatmentcombination[e, 2])
    
    distributiondf <- foreach(j = 1:iteration, .combine = rbind, .packages = "tidyverse") %dopar% {
      bootstorage <-  intersect(treatment1[,3:ncol(treatment1)], treatment2[,3:ncol(treatment2)])
      bootstorage <- rbind(bootstorage, treatment1[sample(1:nrow(treatment1), size = 1),4:ncol(treatment1)] - treatment2[sample(1:nrow(treatment2), size = 1),4:ncol(treatment2)])
      bootstorage %>% 
        mutate(sample_name = sample) %>% 
        mutate(treatment1 = treatmentcombination[e, 1]) %>% 
        mutate(treatment2 = treatmentcombination[e, 2]) %>% 
        select(sample_name, treatment1, treatment2, everything())
    }
  output[[e]] <- distributiondf
   }
  for (i in seq_along(output)){
    write.csv(output[[i]], file = paste0(output[[i]][["sample_name"]][1],"_", output[[i]][["treatment1"]][1], "_", output[[i]][["treatment2"]][1], ".csv"), row.names = F)
  }
}

stopCluster(cluster)










