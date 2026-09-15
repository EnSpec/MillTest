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


# RESOLVED (2026-09-15, Henry+Zach): the mean-of-6 procedure below (now
# removed -- see the foreach block) was Zach's own addition, motivated by
# wanting to smooth over the 6 spectral replicates per sample x treatment.
# Confirmed the actual intended procedure is a single random-replicate-pair
# draw per iteration, matching the manuscript methods text exactly ("a
# random replicate was chosen from each treatment... iterated N times") --
# no intermediate averaging. The old "1200"/"999" iteration counts were
# each doing 6x that many underlying draws internally (1200 iterations x
# 6 draws = 7200), so they don't directly carry over to this simpler,
# ~6x-faster-per-iteration procedure. Henry: bumped to 5000 (up from the
# manuscript's stated 1200) now that each iteration is much cheaper, to
# preempt reviewer pushback on a low replicate count -- manuscript
# methods text needs updating to 5000.
iteration = 5000

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
    
    # Single random-replicate-pair draw per iteration -- one replicate
    # sampled from treatment1, one from treatment2, subtracted. No
    # intermediate averaging (see the iteration= comment above).
    distributiondf <- foreach(j = 1:iteration, .combine = rbind, .packages = "tidyverse") %dopar% {
      (treatment1[sample(1:nrow(treatment1), size = 1), 4:ncol(treatment1)] -
         treatment2[sample(1:nrow(treatment2), size = 1), 4:ncol(treatment2)]) %>%
        mutate(sample_name = sample,
               treatment1 = treatmentcombination[e, 1],
               treatment2 = treatmentcombination[e, 2])
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









