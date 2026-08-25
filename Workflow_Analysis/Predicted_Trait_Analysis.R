########################################################
# Predicted_Trait_Analysis.R
#
# Purpose: Run bayesian ANOVA of treatments to assess
# affects for Nitrogen and Calcium
#
# Date:
# Author(s): Mill Test Team, Copilots
########################################################

# Read libraries
library(tidyverse)
library(brms)
library(bayesplot)
library(MCMCvis)

# Read spectrally predicted traits based on NEON 2020 models
traits <- read.csv('MillTest/Workflow_Traits/DimensionsDryTraitPredictions.csv')

# Read in data with associated metadata
meta <- read.csv('MillTest/Workflow_Traits/DryTraits_NM.csv')
meta_join <- meta %>% select(Sample_ID, Type, Species, Species_Code) %>% distinct()

traits <-  traits %>% distinct()
# Split into columns
traits_clean <- traits %>%
  separate(sampledata_head,
           into = c("Mill", "SampleID", "DryTreat", "MillTreat", "Other"),
           sep = "_",
           remove = FALSE) %>%
  mutate(measure_id = paste(Mill, SampleID, DryTreat, MillTreat, sep = "_")) %>%
  select(sampledata_head, measure_id, SampleID, DryTreat, MillTreat,t_mean_Nitrogen, t_mean_Calcium ) 
traits_clean$SampleID <- paste0('MILL24_',traits_clean$SampleID)

traits_clean2 <- left_join(traits_clean, meta_join, by =c('SampleID' = 'Sample_ID'))

# Relabel forty/sixty and twenty mesh as fine and coarse to accurately describe conifers being done only to forty mesh
traits_clean3 <- traits_clean2 %>% mutate(MillTreat = case_when(
  MillTreat == 'SIXT' ~ 'FINE',
  MillTreat == 'TWEN' ~ 'COARSE',
  TRUE ~ MillTreat
))

# Remove smaller extra collections
traits_clean4 <- traits_clean3 %>% dplyr::filter(Type == 'Conifer' |Type == 'Broadleaf' ) %>%
  dplyr::filter(Species != 'Honey Locust (Gleditsia triacanthos)')

# re-level treatment variables so that oven dried and 20 mesh are the default variables
traits_clean4$MillTreat <- as.factor(traits_clean4$MillTreat)
traits_clean4$MillTreat <- relevel(traits_clean4$MillTreat,ref = 'COARSE')

traits_clean4$DryTreat <- as.factor(traits_clean4$DryTreat)
traits_clean4$DryTreat <- relevel(traits_clean4$DryTreat,ref = 'OD')


#### Model Creation -- Phenolics #####
figpath = '/Users/henryfrye/Dropbox/Intellectual_Endeavours/Wisconsin/DrySpec_Milling_Comparison/ANOVA_Figs/'

# create model for Calcium (full model)
#to try: (1|Species_Code) + (1|measure_id),
#  (1|Species_Code) + (1|Species_Code:measure_id),
calc_mod <- brms::brm(formula = t_mean_Calcium ~ MillTreat*DryTreat + (1|Species_Code) + (1|Species_Code:measure_id),
                      family=gaussian(), data= traits_clean4, seed=112, iter = 20000, cores = 4)
summary(calc_mod)
plot(calc_mod)

MCMCdiag(calc_mod, 
         file_name = 'calcium_mod_summary.txt',
         dir = figpath,
         round =2)

posterior_calc <- as.matrix(calc_mod)

jpeg(paste0(figpath,'Full_Interact_Calc_Plot_MCMCvis.jpeg'))
MCMCplot(posterior_calc[,1:8],labels = c('Intercept','Ball Mill','Fine Rotary','Flash freezing',
                                         'Ball Mill/Flash freeze interaction',
                                         'Fine Rotary/Flash free interaction',
                                         'Species random effect s.d.',
                                         'Nested Species:Measurement random effect s.d.'))

dev.off()

#### Model Creation -- Nitrogen #####
#https://stats.stackexchange.com/questions/228800/crossed-vs-nested-random-effects-how-do-they-differ-and-how-are-they-specified
n_mod <- brms::brm(formula = t_mean_Nitrogen ~ MillTreat*DryTreat + (1|Species_Code) + (1|Species_Code:measure_id), # this design correlates between codes, which I don't know if that's right
                      family=gaussian(), data= traits_clean4, seed=112, iter = 5000, cores = 4)
summary(n_mod)
plot(n_mod)

MCMCdiag(n_mod, 
         file_name = 'nitrogen_mod_summary.txt',
         dir = figpath,
         round =2)

posterior_n <- as.matrix(n_mod)

# plot_title <- ggtitle("Nitrogen Posterior distributions",
#                       "with medians and 80% intervals")
# mcmc_areas(posterior_n[,1:9],
#            #pars = c("cyl", "drat", "am", "wt"),
#            prob = 0.8) + plot_title + theme(text = element_text(size = 22))
# 
# ggsave(paste0(figpath,'Full_Interact_N_Plot.png'), width = 20, height = 10 , bg = 'white')

jpeg(paste0(figpath,'Full_Interact_Nitro_Plot_MCMCvis.jpg'))
MCMCplot(posterior_n[,1:8],labels = c('Intercept','Ball Mill','Fine Rotary','Flash freezing',
                                         'Ball Mill/Flash freeze interaction',
                                         'Fine Rotary/Flash free interaction',
                                         'Species random effect s.d.',
                                         'Nested Species:Measurement random effect s.d.'))

dev.off()


# create model for chl (weight)
chl_mod <- brms::brm(formula = t_mean_Mass.based.chlorophyll.a...b ~ AccessoryType + (1|SppCode/LeafID/spectral_replicate),
                     family=gaussian(), data= traits, seed=112)
summary(chl_mod)
plot(chl_mod)

posterior_chl <- as.matrix(chl_mod)

plot_title <- ggtitle("Chlorophyll Posterior distributions",
                      "with medians and 80% intervals")
mcmc_areas(posterior_chl[,1:6],
           prob = 0.8) + plot_title

ggsave(paste0(figpath,'Coeff_Chl_Plot.png'), width = 10, bg = 'white')


# Model creation lignin #####
lig_mod <- brms::brm(formula = t_mean_Lignin ~ MillMethod*DryingMethod + (1|Species_Code),
                      family=gaussian(), data= traits, seed=112, iter = 5000)
summary(lig_mod)
plot(lig_mod)


posterior_lig <- as.matrix(lig_mod)

# plot_title <- ggtitle("Phenolic Posterior distributions",
#                       "with medians and 80% intervals")
# mcmc_areas(posterior_phen[,1:9],
#            #pars = c("cyl", "drat", "am", "wt"),
#            prob = 0.8) + plot_title + theme(text = element_text(size = 22))
#ggsave(paste0(figpath,'Full_Interact_Phen_Plot.png'),
#       width = 20, height = 10 , bg = 'white')


jpeg(paste0(figpath,'Full_Interact_Lignin_Plot_MCMCvis.jpeg'))
MCMCplot(posterior_lig[,1:7],labels = c('Intercept','Ball Mill','Fine Rotary','Flash freezing',
                                         'Ball Mill/Flash freeze interaction',
                                         'Fine Rotary/Flash free interaction','Species random effect s.d.'))
dev.off()
# Model creation starch #####
starch_mod <- brms::brm(formula = t_mean_Starch ~ MillMethod*DryingMethod + (1|Species_Code),
                     family=gaussian(), data= traits, seed=112, iter = 5000)
summary(starch_mod)
plot(starch_mod)


posterior_starch <- as.matrix(starch_mod)

# plot_title <- ggtitle("Phenolic Posterior distributions",
#                       "with medians and 80% intervals")
# mcmc_areas(posterior_phen[,1:9],
#            #pars = c("cyl", "drat", "am", "wt"),
#            prob = 0.8) + plot_title + theme(text = element_text(size = 22))
#ggsave(paste0(figpath,'Full_Interact_Phen_Plot.png'),
#       width = 20, height = 10 , bg = 'white')


jpeg(paste0(figpath,'Full_Interact_Starch_Plot_MCMCvis.jpeg'))
MCMCplot(posterior_starch[,1:7],labels = c('Intercept','Ball Mill','Fine Rotary','Flash freezing',
                                        'Ball Mill/Flash freeze interaction',
                                        'Fine Rotary/Flash free interaction','Species random effect s.d.'))





