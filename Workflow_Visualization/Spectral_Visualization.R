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

#spectral_data = read.csv('C:\\Users\\amajerus\\Desktop\\MillTest\\MillTest_Local\\PCAFiles\\5nmResampleSpectra_OM.csv')

# better to show the 1-nm data... working with 5 nm for now,
# I set the path assuming code is in the Gitfolder
spectral_data = read.csv('PCA_Figures/CSV_Data/5nmResampleSpectra_OM.csv')



# lab_comb_row is a dataframe three columns of identifying info (sample_name, lab, and sample_id and then all spectral columns)

lab_comb_row_melt <- spectral_data %>% dplyr::select(sample_name, Sample_ID, MillMethod, Species_Code, DryingMethod, X350:X2500)

# Now get spectral data prepared for visualization
GgTreat <- melt(lab_comb_row_melt, variable.name = "Wavelength", value.name = "Reflectance", id.vars = c('sample_name', 'Sample_ID', 'MillMethod', 'Species_Code', 'DryingMethod'))
GgTreat$Wavelength <- as.numeric(str_split(GgTreat$Wavelength, 'X', simplify = TRUE)[,2])

# this should conditionally assign the figure file path based on user. Check the Sys.info output to make sure the user condition is right
FigFolderOD <- if (Sys.info()['user'] == 'henryfrye') {
  '/Users/henryfrye/Dropbox/Intellectual_Endeavours/Wisconsin/DrySpec_Milling_Comparison/Mill_Figures/Spectral_Vis/Oven_dried'
} else if (Sys.info()['user'] == 'amajerus') {
  'C:\\Users\\amajerus\\Desktop\\MillTest\\MillTest_Local\\Figures\\Spectra\\OD'
} else {
  'default/path/if/needed'
}

FigFolderFF <- if (Sys.info()['user'] == 'henryfrye') {
  '/Users/henryfrye/Dropbox/Intellectual_Endeavours/Wisconsin/DrySpec_Milling_Comparison/Mill_Figures/Spectral_Vis/Flash_frozen'
} else if (Sys.info()['user'] == 'amajerus') {
  "C:\\Users\\amajerus\\Desktop\\MillTest\\MillTest_Local\\Figures\\Spectra\\FF"
} else {
  'default/path/if/needed'
}

FigFolderODFF <- if (Sys.info()['user'] == 'henryfrye') {
  '/Users/henryfrye/Dropbox/Intellectual_Endeavours/Wisconsin/DrySpec_Milling_Comparison/Mill_Figures/Spectral_Vis/Dry_method'
} else if (Sys.info()['user'] == 'amajerus') {
  "C:\\Users\\amajerus\\Desktop\\MillTest\\MillTest_Local\\Figures\\Spectra\\ODFF"
} else {
  'default/path/if/needed'
}

# Figures comparing flash frozen vs. oven-dried for 20 mesh Wiley #####

# Create vector by unique species 
spp_code <- unique(GgTreat$Species_Code)

# For clarity to Phil I'm going to code an additional column by latin name for each code. Best practice is to separate data columns
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

# check for any issues
length(which(is.na(GgTreat$Species) == TRUE))

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