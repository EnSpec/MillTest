#########################################################
#
# Mill Test Replicate-Pair Differences
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

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

# MILL24_REPLICATE_DIFF_OUT overrides the output folder (used to re-run into a
# scratch folder and compare against the stored output).
out_dir <- Sys.getenv("MILL24_REPLICATE_DIFF_OUT", unset = file.path(data_root, "ReplicatePairDifferences"))
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)


# Deduplicated, jump-corrected spectra (2376 scans; where a replicate set was
# scanned twice only the later scan is kept). Until 2026-10-19 this read
# Mill24_RawSpec.csv, which also carries the earlier scans of three re-scanned
# sets (none of which are in the four compared pairs); the kept scans are
# identical in both files to 1.5e-7. Mill24_RawSpec.csv is not deposited.
spectraldata <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_raw_spectra.csv")) %>%
  mutate(SampleID = substring(sample_name, 1, 11))


# RESOLVED (2026-09-15): with only 6 spectral replicates per sample
# x treatment, the population of possible replicate-pair differences for
# a given treatment comparison is small and finite -- 6 x 6 = 36 (every
# treatment1-replicate vs. every treatment2-replicate, including "1 vs.
# 1", not just distinct pairs). Randomly resampling from a pool that
# small (even thousands of times, as the mean-of-6 and single-draw
# versions both did) just redraws the same combinations repeatedly with
# gaps and duplicates -- exhaustively computing all of them directly is
# both more complete and far cheaper than any amount of random sampling.
# This is not a resampling bootstrap. The script, its figure script and the
# output folder were renamed 2026-10-20 (from BootstrapCode.R,
# BootstrapFigureGeneration.R and BootstrappedData/) to say what they do:
# ReplicatePairDifferences.R, ReplicatePairDifferenceFigure.R and
# ReplicatePairDifferences/.
# No parallel cluster needed either -- 66 samples x 4 comparisons x 36
# combinations = 9,504 total rows, trivially fast to compute directly.
# Manuscript methods text (currently "a random replicate was chosen...
# iterated N times") needs rewriting to describe full enumeration, not a
# random-draw count.

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









