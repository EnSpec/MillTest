########################################################
# Spectra_Visualization.R
#
# Purpose: Visualize spectra between treatments for milling
# comparisons
#
# Date:
# Author(s): Mill Test Team
########################################################

library(tidyverse)
library(reshape2)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

# FLAG (2026-09-11): 5nmResampleSpectra_OM.csv is one of the per-treatment
# SpectralPredictR splits still missing from spectralpredictr/ (see its
# README) -- it was never staged, and it's not the same file as
# SpectralPredictR_5nmresampled_spectra.csv (the un-split file
# SpectralPredictR.R now produces for real). This script is blocked until
# that lands or DataJoin.R's *Edit.csv split-by-treatment output is confirmed
# as the regenerable equivalent (see data_manifest.md). Path de-hard-coded below,
# but not run against real data.
spectral_data = read.csv(file.path(data_root, "spectralpredictr", "5nmResampleSpectra_OM.csv"))

# lab_comb_row is a dataframe three columns of identifying info (sample_name, lab, and sample_id and then all spectral columns)

lab_comb_row_melt <- spectral_data %>% dplyr::select(sample_name, Sample_ID, MillMethod, Species_Code, DryingMethod, X350:X2500)

# Now get spectral data prepared for visualization
GgTreat <- melt(lab_comb_row_melt, variable.name = "Wavelength", value.name = "Reflectance", id.vars = c('sample_name', 'Sample_ID', 'MillMethod', 'Species_Code', 'DryingMethod'))
GgTreat$Wavelength <- as.numeric(str_split(GgTreat$Wavelength, 'X', simplify = TRUE)[,2])

# Was a per-user Sys.info()['user'] branch (henryfrye / amajerus / a
# 'default/path/if/needed' fallback that would have silently written figures
# into a literal relative folder named that). Now under derived/, like every
# other script's output.
out_dir <- file.path(data_root, "derived", "spectral_visualization")
FigFolderOD   <- file.path(out_dir, "Oven_dried")
FigFolderFF   <- file.path(out_dir, "Flash_frozen")
FigFolderODFF <- file.path(out_dir, "Dry_method")
for (d in c(FigFolderOD, FigFolderFF, FigFolderODFF)) {
  dir.create(d, recursive = TRUE, showWarnings = FALSE)
}

# Figures comparing flash frozen vs. oven-dried for 20 mesh Wiley #####

# Create vector by unique species 
spp_code <- unique(GgTreat$Species_Code)

# For clarity, add a column by latin name for each code. Best practice is to separate data columns
# by just the latin binomial and then common name in a different column
GgTreat <- GgTreat %>% mutate(Species = case_when(
Species_Code == 'QURU' ~ 'Quercus rubra',
Species_Code == 'RHCA' ~ 'Rhamnus cathartica',
Species_Code == 'PHDE' ~ 'Phytolacca americana',# P. decandra is a lesser used synonym
Species_Code == 'ACSA' ~ 'Acer saccharum',
Species_Code == 'CEOC' ~ 'Celtis occidentalis',
Species_Code == 'COAL' ~ 'Cornus alternifolia',
Species_Code == 'ROPS' ~ 'Robinia pseudoacacia',
Species_Code == 'PIRE' ~ 'Pinus resinosa',
Species_Code == 'GLTR' ~ 'Gleditsia triacanthos',
Species_Code == 'PIST' ~ 'Pinus strobus',
Species_Code == 'PIAB' ~ 'Picea abies',
Species_Code == 'SEPU' ~ 'Setaria pumila',
Species_Code == 'JUVI' ~ 'Juniperus virginiana',
Species_Code == 'THOC' ~ 'Thuja occidentalis'
))

conifercodes = c('THOC', 'PIST', 'JUVI', 'PIAB', 'PIRE')
# fix the mill label for conifers
GgTreat  <- GgTreat %>% mutate(MillMethod = case_when(
  MillMethod == 'SIXT' & Species_Code %in% conifercodes ~ 'FORT',
  TRUE ~ MillMethod
))

# check for any issues (was a bare top-level expression -- Rscript doesn't
# auto-print those outside an interactive session, so this silently did
# nothing when run as a script)
message(sprintf("Species mapping: %d unmatched Species_Code rows",
                sum(is.na(GgTreat$Species))))

# run for loop
for(i in 1:length(spp_code)){
SAAF_spec2 <- GgTreat %>% dplyr::filter( Species_Code == spp_code[i]) %>% filter( MillMethod == "TWEN")
spp_plotted <- SAAF_spec2$Species[1] #just grab species name from filtered data
sample_num <- length(unique(SAAF_spec2$Sample_ID)) # grab n samples
SAAF_plot <- ggplot(SAAF_spec2, aes(x = Wavelength, y = Reflectance, 
                                   group = interaction(sample_name, DryingMethod), color = DryingMethod)) + 
  geom_line(linewidth = 1.75, alpha = .75) + 
  ylab('Normalized Reflectance') +
  xlab('Wavelength (nm)') +
  labs(color = "") +
  theme_bw() +
  ggtitle(paste0('Wiley 20 mesh for: ',spp_plotted, ', n = ', sample_num)) +
  theme(axis.text.x = element_text(angle = 45, vjust= .75, hjust = .7),
        text = element_text(size=22, family = "Arial"),
        axis.text.y = element_text(size = 18),
        legend.position = c(.85, .9),
        legend.text = element_text(size =22),
        legend.title = element_text(size = 11),
        legend.text.align = 0,
        legend.margin=margin(t = 0, unit='cm')) 
SAAF_plot

ggsave(SAAF_plot, filename = paste0(FigFolderODFF,"/MILL24_Oven_v_Flash_",spp_code[i],".png"),
       units='in', width = 11,  dpi =  500)
}


# Figures comparing oven-dried across milling types #####
# run for loop
for(i in 1:length(spp_code)){
  SAAF_spec2 <- GgTreat %>% dplyr::filter( Species_Code == spp_code[i]) %>% filter(DryingMethod == "OD")
  spp_plotted <- SAAF_spec2$Species[1] #just grab species name from filtered data
  sample_num <- length(unique(SAAF_spec2$Sample_ID)) # grab n samples
  SAAF_plot <- ggplot(SAAF_spec2, aes(x = Wavelength, y = Reflectance, 
                                      group = interaction(sample_name, MillMethod ), color = MillMethod)) + 
    geom_line(linewidth = 1.75, alpha = .75) + 
    ylab('Normalized Reflectance') +
    xlab('Wavelength (nm)') +
    labs(color = "") +
    theme_bw() +
    ggtitle(paste0('Oven-dried ',spp_plotted, ', n = ', sample_num)) +
    theme(axis.text.x = element_text(angle = 45, vjust= .75, hjust = .7),
          text = element_text(size=22, family = "Arial"),
          axis.text.y = element_text(size = 18),
          legend.position = c(.85, .9),
          legend.text = element_text(size =22),
          legend.title = element_text(size = 11),
          legend.text.align = 0,
          legend.margin=margin(t = 0, unit='cm')) 
  SAAF_plot
  
  ggsave(SAAF_plot, filename = paste0(FigFolderOD,"/MILL24_OvenDried_MillingMethod_",spp_code[i],".png"),
         units='in', width = 11,  dpi =  500)
}

# Figures comparing flash-frozen across milling types #####
for(i in 1:length(spp_code)){
  SAAF_spec2 <- GgTreat %>% dplyr::filter( Species_Code == spp_code[i]) %>% filter(DryingMethod == "FF")
  spp_plotted <- SAAF_spec2$Species[1] #just grab species name from filtered data
  sample_num <- length(unique(SAAF_spec2$Sample_ID)) # grab n samples
  SAAF_plot <- ggplot(SAAF_spec2, aes(x = Wavelength, y = Reflectance, 
                                      group = interaction(sample_name, MillMethod ), color = MillMethod)) + 
    geom_line(linewidth = 1.75, alpha = .55) + 
    ylab('Normalized Reflectance') +
    xlab('Wavelength (nm)') +
    labs(color = "") +
    theme_bw() +
    ggtitle(paste0('Flash-frozens ',spp_plotted, ', n = ', sample_num)) +
    theme(axis.text.x = element_text(angle = 45, vjust= .75, hjust = .7),
          text = element_text(size=22, family = "Arial"),
          axis.text.y = element_text(size = 18),
          legend.position = c(.85, .9),
          legend.text = element_text(size =22),
          legend.title = element_text(size = 11),
          legend.text.align = 0,
          legend.margin=margin(t = 0, unit='cm')) 
  SAAF_plot
  
  ggsave(SAAF_plot, filename = paste0(FigFolderFF,"/MILL24_FlashFrozen_MillingMethod_",spp_code[i],".png"),
         units='in', width = 11,  dpi =  500)
}





# SAAF_spec <- GgTreat %>% dplyr::filter(substring(sample_name, first = 1, last = 14) == "MILL24_0066_FF")
# 
# SAAF_spec2 <- GgTreat %>% dplyr::filter( Sample_ID == "MILL24_0066") %>% filter( MillMethod == "TWEN")