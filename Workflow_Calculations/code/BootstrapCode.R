#########################################################
#
# Mill Test Bootstrap Resampling
#
# Authors: Zach Breuer, Mill Test Team
#
# Project: Mill Test
#
# Date: 4/29/2026 (paths de-hard-coded -- 2026-09-11)
#
##########################################################

library(tidyverse)
library(gtools)
setwd("Z:projects/Mill24/BootstrappedData")

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "BootstrappedData")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

spectraldata <- read.csv("Z:/projects/Mill24/Mill24_RawSpec.csv") %>% 
  mutate(SampleID = substring(sample_name, 1, 11))


iteration = 1200

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

    # Every treatment1-replicate x treatment2-replicate combination,
    # exhaustively -- not a random sample of them.
    pairs <- expand.grid(i = seq_len(nrow(treatment1)), j = seq_len(nrow(treatment2)))
    distributiondf <- pmap_dfr(pairs, function(i, j) {
      (treatment1[i, 4:ncol(treatment1)] - treatment2[j, 4:ncol(treatment2)]) %>%
        mutate(sample_name = sample,
               treatment1 = treatmentcombination[e, 1],
               treatment2 = treatmentcombination[e, 2])
    })
  output[[e]] <- distributiondf
                    }
  for (i in seq_along(output)){
    write.csv(output[[i]], file = file.path(out_dir, paste0(output[[i]][["sample_name"]][1], "_", output[[i]][["treatment1"]][1], "_", output[[i]][["treatment2"]][1], ".csv")), row.names = F)
  }
}









