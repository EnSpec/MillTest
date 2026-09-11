# Zach Breuer
# Spectra Information Join
# Dec 03 2024
# (paths de-hard-coded, drytraitsedit write fixed -- 2026-09-11)

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "data_join")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# Reads necessary files and removes unneeded data for raw data
rawspectra <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_raw_spectra.csv"))
sampleinfo <- read.csv(file.path(data_root, "field_data", "sample_info.csv"))
sampleinfo <- sampleinfo %>% select(Sample_ID, Species_Code, Species, Type)

# Joins Sample Info with raw spectral data and writes csv for raw data
rawspectraedit <- rawspectra %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type)

write.csv(rawspectraedit, file.path(out_dir, "RawSpectraEdit.csv"), row.names = FALSE)

# Reads necessary files for jump corrected data
vectornormalizedspectra <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_VN_jumpcorrected_spectra.csv"))

# Joins Sample Info with jump corrected spectral data and writes csv for jump corrected data
vectornormalizedspectraedit <- vectornormalizedspectra %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type)

write.csv(vectornormalizedspectraedit, file.path(out_dir, "VectorNormalizedSpectraEdit.csv"), row.names = FALSE)

# Reads necessary files for 5nm resampling data
resamplespectra <- read.csv(file.path(data_root, "spectralpredictr", "SpectralPredictR_5nmresampled_spectra.csv"))

# Joins Sample Info with 5nm resampled data and writes csv for 5nm resampled data
resamplespectraedit <- resamplespectra %>% rename(sample_name = sampledata_head) %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type)

write.csv(resamplespectraedit, file.path(out_dir, "5nmResampleSpectraEdit.csv"), row.names = FALSE)

# Reads necessary files for dry traits data
drytraits = read.csv(file.path(data_root, "spectralpredictr", "DimensionsDryTraitPredictions.csv"))

# Joins Sample Info with dry traits data and writes csv for dry traits data
drytraitsedit <- drytraits %>% rename(sample_name = sampledata_head) %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type)

# BUG FIX: this used to write `resamplespectraedit` here again instead of the
# `drytraitsedit` just computed above -- drytraitsedit was silently dropped.
write.csv(drytraitsedit, file.path(out_dir, "DryTraitsEdit.csv"), row.names = FALSE)