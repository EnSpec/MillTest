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
setwd("C:/Mill24/Bootstrapped")

set.seed(0220)
cores <-  detectCores() - 1
cluster <- makeCluster(cores)
registerDoParallel(cluster)


spectraldata <- read.csv("C:/Mill24/SpectraUpdated/Mill24_RawSpec.csv") %>% 
  mutate(SampleID = substring(sample_name, 1, 11))


iteration = 999

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
      for(q in 1:6){
        bootstorage <- rbind(bootstorage, treatment1[sample(1:nrow(treatment1), size = 1),4:ncol(treatment1)] - treatment2[sample(1:nrow(treatment2), size = 1),4:ncol(treatment2)])
      }
    
      bootstorage %>% 
        mutate(sample_name = sample) %>% 
        mutate(treatment1 = treatmentcombination[e, 1]) %>% 
        mutate(treatment2 = treatmentcombination[e, 2]) %>% 
        group_by(sample_name, treatment1, treatment2) %>% 
        summarize(across(everything(), mean, na.rm = TRUE))
    }
  output[[e]] <- distributiondf
                    }
  for (i in seq_along(output)){
    write.csv(output[[i]], file = paste(output[[i]][["sample_name"]][1],"_", output[[i]][["treatment1"]][1], "_", output[[i]][["treatment2"]][1], ".csv"), row.names = F)
  }
}

stopCluster(cluster)









