########################################################
# Predicted_Trait_Analysis_other_traits.R  --  ARCHIVED, NON-FUNCTIONAL
#
# Chlorophyll / lignin / starch model fragments that used to sit at the
# bottom of Predicted_Trait_Analysis.R. They are NOT part of the Mill Test
# analysis: the formulas reference columns from a different project's data
# (AccessoryType, SppCode, LeafID, spectral_replicate,
# t_mean_Mass.based.chlorophyll.a...b, MillMethod, DryingMethod) that do not
# exist in the Mill Test `traits` table, so this script errors on the first
# model. Kept only as a record of what was pasted in.
#
# The manuscript ANOVA covers nitrogen and calcium only -- see
# ../Predicted_Trait_Analysis.R.
########################################################

library(tidyverse)
library(brms)
library(bayesplot)
library(MCMCvis)

# `traits`, `figpath` were globals in the original script; nothing sets them here.

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

jpeg(paste0(figpath,'Full_Interact_Starch_Plot_MCMCvis.jpeg'))
MCMCplot(posterior_starch[,1:7],labels = c('Intercept','Ball Mill','Fine Rotary','Flash freezing',
                                        'Ball Mill/Flash freeze interaction',
                                        'Fine Rotary/Flash free interaction','Species random effect s.d.'))
dev.off()
