#########################################

#Project: Mill24

#Authors: Annabelle Majerus

## Trait Comparisons

#########################################

library("FactoMineR")
library("factoextra")
library(tidyverse)
library(ggpubr)

# I changed the path links to be relative, instead of set to Annabelle's computer
spectral_data_NM <- read.csv("5nmResampleSpectra_NM.csv")
spectral_data_OD_NM <- read.csv("5nmResampleSpectra_OD_NM.csv")
spectral_data_OD_OM <- read.csv("5nmResampleSpectra_OD_OM.csv")
spectral_data_OM <- read.csv("5nmResampleSpectra_OM.csv")
sample_data <- read.csv("../General_Data/sample_info.csv")
drytrait_data_NM <- read.csv("DryTraits_NM.csv")
drytrait_data_OM <- read.csv("DryTraits_OM.csv")

drytrait_data_NM <- drytrait_data_NM %>% filter(Species_Code != "GLTR")

#Excluding low sample numbers (forbs and graminoids)
conifer_drytrait_data_NM <- drytrait_data_NM %>% filter(Type == "Conifer")
broadleaf_drytrait_data_NM <- drytrait_data_NM %>% filter(Type == "Broadleaf")

#conifer data subsets
conifer_drytrait_data_NM_OD <- conifer_drytrait_data_NM %>% filter(DryingMethod == "OD")
conifer_drytrait_data_NM_FF <- conifer_drytrait_data_NM %>% filter(DryingMethod == "FF")
conifer_no60_drytrait_data_NM_FF <- conifer_drytrait_data_NM %>% filter(MillMethod == "TWEN" | MillMethod == "BALL")

#broadleaf data subsets
broadleaf_drytrait_data_NM_OD <- broadleaf_drytrait_data_NM %>% filter(DryingMethod == "OD")
broadleaf_drytrait_data_NM_FF <- broadleaf_drytrait_data_NM %>% filter(DryingMethod == "FF")
broadleaf_no60_drytrait_data_NM_FF <- broadleaf_drytrait_data_NM %>% filter(MillMethod == "TWEN" | MillMethod == "BALL")

# subset across sample prep for milling mesh 20
broadleaf_twenty <- broadleaf_drytrait_data_NM %>% filter(MillMethod == "TWEN")
conifer_twenty <- conifer_drytrait_data_NM %>% filter(MillMethod == "TWEN")

###N15 broadleaf and conifer ####
library(rlang)  # for tidy evaluation

plot_trait_lines <- function(data, trait_vars, output_dir = ".", sample_handle = 'OD',
                             growth_form = 'Broadleaf', treatment_var = MillMethod) {
  for (trait in trait_vars) {
    
    # Dynamically create y-axis label and title
    trait_label <- gsub("t_mean_", "", trait)
    y_label <- paste0(trait_label, " (mg g^-1)")
    plot_title <- paste(trait_label, paste0(sample_handle, " Across Treatments - ", growth_form))
    
    # Summarize by Sample_ID
    sample_summary <- data %>%
      group_by(Sample_ID, {{treatment_var}}, Species_Code) %>%
      summarise(mean_value = mean(.data[[trait]], na.rm = TRUE), .groups = 'drop')
    
    # Summarize by Species_Code
    species_summary <- data %>%
      group_by(Species_Code, {{treatment_var}}) %>%
      summarise(mean_value = mean(.data[[trait]], na.rm = TRUE), .groups = 'drop')
    
    # Create plot
    p <- ggplot() +
      geom_line(data = sample_summary,
                aes(x = {{treatment_var}}, y = mean_value, group = Sample_ID, colour = Species_Code),
                alpha = 0.3, size = 0.5) +
      geom_line(data = species_summary,
                aes(x = {{treatment_var}}, y = mean_value, group = Species_Code, colour = Species_Code),
                size = 1.2) +
      geom_point(data = data,
                 aes(x = {{treatment_var}}, y = .data[[trait]], colour = Species_Code),
                 alpha = 0.6) +
      theme_bw() +
      ylab(y_label) +
      ggtitle(plot_title)
    
    # Save plot
    file_name <- paste0(output_dir, "/", trait_label, "_", sample_handle, "_", growth_form, "_plot.png")
    ggsave(file_name, plot = p, width = 8, height = 6)
  }
}



# run mill comparisons on oven dried, broads
henry_output <- '/Users/henryfrye/Dropbox/Intellectual_Endeavours/Wisconsin/DrySpec_Milling_Comparison/Mill_Figures/Trait_Comps'
selected_traits <- c('t_mean_Calcium', 't_mean_d15N', 't_mean_Lignin', 't_mean_Nitrogen', 't_mean_NSC', 't_mean_Phenolics' )
plot_trait_lines(data = broadleaf_drytrait_data_NM_OD, trait_vars = selected_traits ,output_dir = henry_output,
                 sample_handle = 'OD',
                 growth_form = 'Broadleaf')

# run mill comparisons on flash frozen, broads
broadleaf_drytrait_data_NM_FF
plot_trait_lines(data = broadleaf_drytrait_data_NM_FF, trait_vars = selected_traits ,output_dir = henry_output,
                 sample_handle = 'FF',
                 growth_form = 'Broadleaf')

# run mill comparisons on oven dried, conifer
plot_trait_lines(data = conifer_drytrait_data_NM_OD, trait_vars = selected_traits ,output_dir = henry_output,
                 sample_handle = 'OD',
                 growth_form = 'Conifer')

# run mill comparisons on flash frozen, conifer
plot_trait_lines(data = conifer_drytrait_data_NM_FF, trait_vars = selected_traits ,output_dir = henry_output,
                 sample_handle = 'FF',
                 growth_form = 'Conifer')

# run oven vs. flash comparison for 20 mesh, broad
plot_trait_lines(data = broadleaf_twenty, trait_vars = selected_traits ,output_dir = henry_output,
                 treatment_var = DryingMethod,
                 sample_handle = '',
                 growth_form = 'Conifer')

# run oven vs. flash comparison for 20 mesh, broads
plot_trait_lines(data = broadleaf_twenty, trait_vars = selected_traits ,output_dir = henry_output,
                 treatment_var = DryingMethod,
                 sample_handle = '',
                 growth_form = 'Broadleaf')

# run oven vs. flash comparison for 20 mesh, conifer
plot_trait_lines(data = conifer_twenty, trait_vars = selected_traits ,output_dir = henry_output,
                 treatment_var = DryingMethod,
                 sample_handle = '',
                 growth_form = 'Conifer')


# Example to make a single graph outside of function #####

# Sample-level summary
sample_summary <- broadleaf_drytrait_data_NM_OD %>%
  group_by(Sample_ID, MillMethod, Species_Code) %>%
  summarise(mean_d15N = mean(t_mean_d15N, na.rm = TRUE), .groups = 'drop')

# Species-level summary
species_summary <- broadleaf_drytrait_data_NM_OD %>%
  group_by(Species_Code, MillMethod) %>%
  summarise(mean_d15N = mean(t_mean_d15N, na.rm = TRUE), .groups = 'drop')

# Plot


ggplot() +
  # Faint sample-level lines
  geom_line(data = sample_summary,
            aes(x = MillMethod, y = mean_d15N, group = Sample_ID, colour = Species_Code),
            alpha = 0.3, size = 0.5) +
  # Bold species-level lines (with group!)
  geom_line(data = species_summary,
            aes(x = MillMethod, y = mean_d15N, group = Species_Code, colour = Species_Code),
            size = 1.2) +
  # Optional: raw data points
  geom_point(data = broadleaf_drytrait_data_NM_OD,
             aes(x = MillMethod, y = t_mean_d15N, colour = Species_Code),
             alpha = 0.6) +
  theme_bw() +
  ylab(expression(paste("d15N"))) +
  ggtitle("N15 OD Across Milling Treatments - Broadleaf")


# 
# # ggplot(broadleaf_drytrait_data_NM_OD, aes( x = t_mean_d15N,
# #                                            colour = MillMethod)) + geom_density()
# 
# #broadleaf oven dried comparison across all milling treatments N15
# broadleaf_OD_N15_access_line <- ggplot(broadleaf_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_d15N,
#                                                       group = Sample_ID, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("d15N (mg g"^-1,")"))) + ggtitle("N15 OD Across all Milling Treatments - Broadleaf")
# broadleaf_OD_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_OD_N15_access_line.png")
# 
# #broadleaf flash frozen comparison across all milling treatments N15
# broadleaf_FF_N15_access_line <- ggplot(broadleaf_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_d15N,
#                                                       group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("d15N (mg g"^-1,")"))) + ggtitle("N15 FF Across all Milling Treatments - Broadleaf")
# broadleaf_FF_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FF_N15_access_line.png")
# 
# #broadleaf FF ball mill vs 20 mesh
# broadleaf_FFno60_N15_access_line <- ggplot(broadleaf_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_d15N,
#                                                       group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - Broadleaf") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("d15N (mg g"^-1,")"))) +ggtitle("N15 FF Ball vs FF 20 Mesh - Broadleaf")
# broadleaf_FFno60_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FFno60_N15_access_line.png")
# 
# #conifer oven dried comparison across all milling treatments N15
# conifer_OD_N15_access_line <- ggplot(conifer_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_d15N,
#                                                                           group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("d15N (mg g"^-1,")"))) + ggtitle("N15 OD Across all Milling Treatments - Conifer")
# conifer_OD_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_OD_N15_access_line.png")
# 
# #conifer flash frozen comparison across all milling treatments N15
# conifer_FF_N15_access_line <- ggplot(conifer_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_d15N,
#                                                                           group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("d15N (mg g"^-1,")"))) + ggtitle("N15 FF Across all Milling Treatments - Conifer")
# conifer_FF_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FF_N15_access_line.png")
# 
# #conifer FF ball mill vs 20 mesh
# conifer_FFno60_N15_access_line <- ggplot(conifer_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_d15N,
#                                                                                    group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - conifer") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("d15N (mg g"^-1,")"))) +ggtitle("N15 FF Ball vs FF 20 Mesh - Conifer")
# conifer_FFno60_N15_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FFno60_N15_access_line.png")
# 
# ###Nitrogen broadleaf and conifer
# 
# #broadleaf oven dried comparison across all milling treatments Nitrogen
# broadleaf_OD_Nitrogen_access_line <- ggplot(broadleaf_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                           group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) + ggtitle("Nitrogen OD Across all Milling Treatments - Broadleaf")
# broadleaf_OD_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_OD_Nitrogen_access_line.png")
# 
# #broadleaf flash frozen comparison across all milling treatments Nitrogen
# broadleaf_FF_Nitrogen_access_line <- ggplot(broadleaf_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                           group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) + ggtitle("Nitrogen FF Across all Milling Treatments - Broadleaf")
# broadleaf_FF_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FF_Nitrogen_access_line.png")
# 
# #broadleaf FF ball mill vs 20 mesh
# broadleaf_FFno60_Nitrogen_access_line <- ggplot(broadleaf_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                                    group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - Broadleaf") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) +ggtitle("Nitrogen FF Ball vs FF 20 Mesh - Broadleaf")
# broadleaf_FFno60_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FFno60_Nitrogen_access_line.png")
# 
# #conifer oven dried comparison across all milling treatments Nitrogen
# conifer_OD_Nitrogen_access_line <- ggplot(conifer_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                       group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) + ggtitle("Nitrogen OD Across all Milling Treatments - Conifer")
# conifer_OD_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_OD_Nitrogen_access_line.png")
# 
# #conifer flash frozen comparison across all milling treatments Nitrogen
# conifer_FF_Nitrogen_access_line <- ggplot(conifer_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                       group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) + ggtitle("Nitrogen FF Across all Milling Treatments - Conifer")
# conifer_FF_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FF_Nitrogen_access_line.png")
# 
# #conifer FF ball mill vs 20 mesh
# conifer_FFno60_Nitrogen_access_line <- ggplot(conifer_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Nitrogen,
#                                                                                group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - conifer") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Nitrogen (mg g"^-1,")"))) +ggtitle("Nitrogen FF Ball vs FF 20 Mesh - Conifer")
# conifer_FFno60_Nitrogen_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FFno60_Nitrogen_access_line.png")
# 
# 
# ###Lignin broadleaf and conifer
# 
# #broadleaf oven dried comparison across all milling treatments Lignin
# broadleaf_OD_Lignin_access_line <- ggplot(broadleaf_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) + ggtitle("Lignin OD Across all Milling Treatments - Broadleaf")
# broadleaf_OD_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_OD_Lignin_access_line.png")
# 
# #broadleaf flash frozen comparison across all milling treatments Lignin
# broadleaf_FF_Lignin_access_line <- ggplot(broadleaf_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) + ggtitle("Lignin FF Across all Milling Treatments - Broadleaf")
# broadleaf_FF_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FF_Lignin_access_line.png")
# 
# #broadleaf FF ball mill vs 20 mesh
# broadleaf_FFno60_Lignin_access_line <- ggplot(broadleaf_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                                         group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - Broadleaf") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) +ggtitle("Lignin FF Ball vs FF 20 Mesh - Broadleaf")
# broadleaf_FFno60_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FFno60_Lignin_access_line.png")
# 
# #conifer oven dried comparison across all milling treatments Lignin
# conifer_OD_Lignin_access_line <- ggplot(conifer_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) + ggtitle("Lignin OD Across all Milling Treatments - Conifer")
# conifer_OD_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_OD_Lignin_access_line.png")
# 
# #conifer flash frozen comparison across all milling treatments Lignin
# conifer_FF_Lignin_access_line <- ggplot(conifer_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) + ggtitle("Lignin FF Across all Milling Treatments - Conifer")
# conifer_FF_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FF_Lignin_access_line.png")
# 
# #conifer FF ball mill vs 20 mesh
# conifer_FFno60_Lignin_access_line <- ggplot(conifer_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Lignin,
#                                                                                     group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - conifer") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Lignin (mg g"^-1,")"))) +ggtitle("Lignin FF Ball vs FF 20 Mesh - Conifer")
# conifer_FFno60_Lignin_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FFno60_Lignin_access_line.png")
# 
# 
# ###Phenolics broadleaf and conifer
# 
# #broadleaf oven dried comparison across all milling treatments Phenolics
# broadleaf_OD_Phenolics_access_line <- ggplot(broadleaf_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) + ggtitle("Phenolics OD Across all Milling Treatments - Broadleaf")
# broadleaf_OD_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_OD_Phenolics_access_line.png")
# 
# #broadleaf flash frozen comparison across all milling treatments Phenolics
# broadleaf_FF_Phenolics_access_line <- ggplot(broadleaf_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) + ggtitle("Phenolics FF Across all Milling Treatments - Broadleaf")
# broadleaf_FF_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FF_Phenolics_access_line.png")
# 
# #broadleaf FF ball mill vs 20 mesh
# broadleaf_FFno60_Phenolics_access_line <- ggplot(broadleaf_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                                         group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - Broadleaf") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) +ggtitle("Phenolics FF Ball vs FF 20 Mesh - Broadleaf")
# broadleaf_FFno60_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FFno60_Phenolics_access_line.png")
# 
# #conifer oven dried comparison across all milling treatments Phenolics
# conifer_OD_Phenolics_access_line <- ggplot(conifer_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) + ggtitle("Phenolics OD Across all Milling Treatments - Conifer")
# conifer_OD_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_OD_Phenolics_access_line.png")
# 
# #conifer flash frozen comparison across all milling treatments Phenolics
# conifer_FF_Phenolics_access_line <- ggplot(conifer_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) + ggtitle("Phenolics FF Across all Milling Treatments - Conifer")
# conifer_FF_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FF_Phenolics_access_line.png")
# 
# #conifer FF ball mill vs 20 mesh
# conifer_FFno60_Phenolics_access_line <- ggplot(conifer_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_Phenolics,
#                                                                                     group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - conifer") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("Phenolics (mg g"^-1,")"))) +ggtitle("Phenolics FF Ball vs FF 20 Mesh - Conifer")
# conifer_FFno60_Phenolics_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FFno60_Phenolics_access_line.png")
# 
# 
# ###NSC broadleaf and conifer
# 
# #broadleaf oven dried comparison across all milling treatments NSC
# broadleaf_OD_NSC_access_line <- ggplot(broadleaf_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_NSC,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("NSC (mg g"^-1,")"))) + ggtitle("NSC OD Across all Milling Treatments - Broadleaf")
# broadleaf_OD_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_OD_NSC_access_line.png")
# 
# #broadleaf flash frozen comparison across all milling treatments NSC
# broadleaf_FF_NSC_access_line <- ggplot(broadleaf_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_NSC,
#                                                                                group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("NSC (mg g"^-1,")"))) + ggtitle("NSC FF Across all Milling Treatments - Broadleaf")
# broadleaf_FF_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FF_NSC_access_line.png")
# 
# #broadleaf FF ball mill vs 20 mesh
# broadleaf_FFno60_NSC_access_line <- ggplot(broadleaf_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_NSC,
#                                                                                         group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - Broadleaf") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("NSC (mg g"^-1,")"))) +ggtitle("NSC FF Ball vs FF 20 Mesh - Broadleaf")
# broadleaf_FFno60_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/broadleaf_FFno60_NSC_access_line.png")
# 
# #conifer oven dried comparison across all milling treatments NSC
# conifer_OD_NSC_access_line <- ggplot(conifer_drytrait_data_NM_OD, aes(x = MillMethod, y = t_mean_NSC,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("NSC (mg g"^-1,")"))) + ggtitle("NSC OD Across all Milling Treatments - Conifer")
# conifer_OD_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_OD_NSC_access_line.png")
# 
# #conifer flash frozen comparison across all milling treatments NSC
# conifer_FF_NSC_access_line <- ggplot(conifer_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_NSC,
#                                                                            group = Species_Code, colour = Species_Code)) + geom_point() +
#   geom_line() + theme_bw() +
#   ylab(expression(paste("NSC (mg g"^-1,")"))) + ggtitle("NSC FF Across all Milling Treatments - Conifer")
# conifer_FF_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FF_NSC_access_line.png")
# 
# #conifer FF ball mill vs 20 mesh
# conifer_FFno60_NSC_access_line <- ggplot(conifer_no60_drytrait_data_NM_FF, aes(x = MillMethod, y = t_mean_NSC,
#                                                                                     group = Species_Code, colour = Species_Code), title = "FF Ball vs FF 20 Mesh - conifer") + geom_point() +
#   geom_line() + theme_bw() + 
#   ylab(expression(paste("NSC (mg g"^-1,")"))) +ggtitle("NSC FF Ball vs FF 20 Mesh - Conifer")
# conifer_FFno60_NSC_access_line
# ggsave(filename = "/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/Figures/conifer_FFno60_NSC_access_line.png")
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
