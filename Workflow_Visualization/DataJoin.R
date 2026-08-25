# Zach Breuer
# Spectra Information Join
# Dec 03 2024

#Set Up
setwd("C:/Mill24/data/")
library(tidyverse)

# Reads necessary files and removes unneeded data for raw data
rawspectra <- read.csv("SpectralPredictR_raw_spectra.csv")
sampleinfo <- read.csv("sample_info.csv")
sampleinfo <- sampleinfo %>% select(Sample_ID, Species_Code, Species, Type)

# Joins Sample Info with raw spectral data and writes csv for raw data
rawspectraedit <- rawspectra %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type) 

write.csv(rawspectraedit, "C:/Mill24/data/RawSpectraEdit.csv")

# Reads necessary files for jump corrected data
vectornormalizedspectra <- read.csv("SpectralPredictR_VN_jumpcorrected_spectra.csv")

# Joins Sample Info with jump corrected spectral data and writes csv for jump corrected data
vectornormalizedspectraedit <- vectornormalizedspectra %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type) 

write.csv(vectornormalizedspectraedit, "C:/Mill24/data/VectorNormalizedSpectraEdit.csv")

# Reads necessary files for 5nm resampling data
resamplespectra <- read.csv("SpectralPredictR_5nmresampled_spectra.csv")

# Joins Sample Info with 5nm resampled data and writes csv for 5nm resampled data
resamplespectraedit <- resamplespectra %>% rename(sample_name = sampledata_head) %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type) 

write.csv(resamplespectraedit, "C:/Mill24/data/5nmResampleSpectraEdit.csv")

# Reads necessary files for dry traits data
drytraits = read.csv("DimensionsDryTraitPredictions.csv")

# Joins Sample Info with dry traits data and writes csv for dry traits data
drytraitsedit <- drytraits %>% rename(sample_name = sampledata_head) %>% mutate(Sample_ID = substr(sample_name, start = 1, stop = 11), MillMethod = substr(sample_name, start = 16, stop = 19)) %>% left_join(sampleinfo, join_by(Sample_ID)) %>% relocate(sample_name, Sample_ID, MillMethod, Species_Code, Species, Type) 

write.csv(resamplespectraedit, "C:/Mill24/data/DryTraitsEdit.csv")