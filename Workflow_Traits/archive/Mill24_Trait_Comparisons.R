#########################################
#
# Project: Mill24
# Author:  Annabelle Majerus
#
# Trait Comparisons -- per-species line plots of predicted traits across
# milling treatments, by growth form and drying method.
#
# ARCHIVED: early exploratory work, not part of the manuscript pipeline
# (the manuscript reports calcium and nitrogen only). Kept for provenance.
# Bugs and the isotope axis label were fixed before archiving; the figures
# it makes are not manuscript figures.
#
#########################################

library(tidyverse)
library(rlang)   # for {{ }} embracing in plot_trait_lines()

data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

drytrait_data_NM <- read.csv(file.path(data_root, "spectralpredictr",
                                       "DryTraits_NM.csv"))

drytrait_data_NM <- drytrait_data_NM %>% filter(Species_Code != "GLTR")

#Excluding low sample numbers (forbs and graminoids)
conifer_drytrait_data_NM <- drytrait_data_NM %>% filter(Type == "Conifer")
broadleaf_drytrait_data_NM <- drytrait_data_NM %>% filter(Type == "Broadleaf")

#conifer data subsets
conifer_drytrait_data_NM_OD <- conifer_drytrait_data_NM %>% filter(DryingMethod == "OD")
conifer_drytrait_data_NM_FF <- conifer_drytrait_data_NM %>% filter(DryingMethod == "FF")

#broadleaf data subsets
broadleaf_drytrait_data_NM_OD <- broadleaf_drytrait_data_NM %>% filter(DryingMethod == "OD")
broadleaf_drytrait_data_NM_FF <- broadleaf_drytrait_data_NM %>% filter(DryingMethod == "FF")

# subset across sample prep for milling mesh 20
broadleaf_twenty <- broadleaf_drytrait_data_NM %>% filter(MillMethod == "TWEN")
conifer_twenty <- conifer_drytrait_data_NM %>% filter(MillMethod == "TWEN")

###N15 broadleaf and conifer ####

plot_trait_lines <- function(data, trait_vars, output_dir = ".", sample_handle = 'OD',
                             growth_form = 'Broadleaf', treatment_var = MillMethod) {
  for (trait in trait_vars) {
    
    # Dynamically create y-axis label and title
    trait_label <- gsub("t_mean_", "", trait)
    y_label <- switch(trait_label,
      d15N = expression(delta^15 * N ~ "(‰)"),
      d13C = expression(delta^13 * C ~ "(‰)"),
      bquote(.(trait_label) ~ "(mg g"^-1 * ")"))
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
                alpha = 0.3, linewidth = 0.5) +
      geom_line(data = species_summary,
                aes(x = {{treatment_var}}, y = mean_value, group = Species_Code, colour = Species_Code),
                linewidth = 1.2) +
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
out_dir <- file.path(data_root, "derived", "trait_comparisons")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# manuscript reports Calcium and Nitrogen; the rest are exploratory
selected_traits <- c('t_mean_Calcium', 't_mean_d15N', 't_mean_Lignin',
                     't_mean_Nitrogen', 't_mean_NSC', 't_mean_Phenolics')
plot_trait_lines(data = broadleaf_drytrait_data_NM_OD, trait_vars = selected_traits, output_dir = out_dir,
                 sample_handle = 'OD',
                 growth_form = 'Broadleaf')

# run mill comparisons on flash frozen, broads
plot_trait_lines(data = broadleaf_drytrait_data_NM_FF, trait_vars = selected_traits, output_dir = out_dir,
                 sample_handle = 'FF',
                 growth_form = 'Broadleaf')

# run mill comparisons on oven dried, conifer
plot_trait_lines(data = conifer_drytrait_data_NM_OD, trait_vars = selected_traits, output_dir = out_dir,
                 sample_handle = 'OD',
                 growth_form = 'Conifer')

# run mill comparisons on flash frozen, conifer
plot_trait_lines(data = conifer_drytrait_data_NM_FF, trait_vars = selected_traits, output_dir = out_dir,
                 sample_handle = 'FF',
                 growth_form = 'Conifer')

# run oven vs. flash comparison for 20 mesh, broads
plot_trait_lines(data = broadleaf_twenty, trait_vars = selected_traits, output_dir = out_dir,
                 treatment_var = DryingMethod,
                 sample_handle = '',
                 growth_form = 'Broadleaf')

# run oven vs. flash comparison for 20 mesh, conifer
plot_trait_lines(data = conifer_twenty, trait_vars = selected_traits, output_dir = out_dir,
                 treatment_var = DryingMethod,
                 sample_handle = '',
                 growth_form = 'Conifer')

