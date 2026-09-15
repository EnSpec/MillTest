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
library(boot)
library(doParallel)
library(foreach)
library(gtools)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "BootstrappedData")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

set.seed(0220)
cores <-  detectCores() - 1
cluster <- makeCluster(cores)
registerDoParallel(cluster)


spectraldata <- read.csv(file.path(data_root, "Mill24_RawSpec.csv")) %>%
  mutate(SampleID = substring(sample_name, 1, 11))


# FLAG (2026-09-15): Henry's recollection is that 999 is correct -- 1500
# was from the earlier averaging-based Bias* chain (superseded, archived),
# not this script, and the manuscript's stated 1200 was Zach's original
# intended value but that run was never completed with the mean-of-6
# procedure below before he cut it to 999 for runtime. Henry is
# double-checking this directly with Zach before treating it as final --
# do not re-run BootstrappedData/ or update the manuscript's iteration
# count until confirmed.
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
    
    # FLAG (2026-09-15): Henry's recollection is that the `for(q in 1:6)`
    # loop below -- mean of 6 random replicate-pair draws per iteration,
    # rather than one single random-replicate-pair draw -- is the intended,
    # final procedure, but he's confirming with Zach before treating this
    # as settled (see the iteration= comment above for the fuller context).
    # Manuscript methods text currently describes the single-draw version.
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
    # `paste0` here, not `paste` -- Zach's 2026-09-08 push changed this to
    # `paste`, whose default sep=" " puts literal spaces into the filename
    # (e.g. "MILL24_0001 _ FF_TWEN _ OD_TWEN .csv"). Reverted; the naming
    # convention (MILL24_0030_FF_TWEN_OD_TWEN.csv) is relied on elsewhere.
    write.csv(output[[i]], file = file.path(out_dir, paste0(output[[i]][["sample_name"]][1], "_", output[[i]][["treatment1"]][1], "_", output[[i]][["treatment2"]][1], ".csv")), row.names = F)
  }
}

stopCluster(cluster)









