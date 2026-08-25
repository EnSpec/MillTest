########################################
#
# Title: Chemical Analysis
#
# Project: Mill Test 2024
#
# Date: 8/24/2025
#
# Authors: Zach Breuer, Mill Test Team
#
########################################

library(tidyverse)
library(ggpmisc)
library(cowplot)
library(vegan)
setwd("C:/Mill24/data/Elements")

# Load in necessary dataset

PredictedChem <- read.csv("Z:/projects/Mill24/ChemResults/DryTraits_NEONModel.csv")
ObservedChem <- read.csv("Z:/projects/Mill24/ChemResults/Brookside.csv")

# Sort, filter, and join datasets

PredictedChem <- PredictedChem %>% 
  mutate(sample_name = sampledata_head) %>% 
  select(sample_name,
         t_mean_Nitrogen, 
         t_mean_Potassium,
         t_mean_Phosphorus,
         t_mean_Calcium) %>% 
  mutate(treatment = substring(sample_name, 1, 19)) %>% 
  group_by(treatment) %>% 
  summarize(PredictedNitrogen = mean(t_mean_Nitrogen),
            PredictedPotassium = mean(t_mean_Potassium),
            PredictedPhosphorus = mean(t_mean_Phosphorus),
            PredictedCalcium = mean(t_mean_Calcium)) %>% 
  mutate(Sample_ID = substring(treatment, 1, 11)) %>% 
  rename(sample_name = treatment)

ObservedChem <- ObservedChem %>% 
  select(Sample_ID,
         Nitrogen,
         Potassium,
         Phosphorous,
         Calcium) %>% 
  rename(ObservedNitrogen = Nitrogen,
         ObservedPotassium = Potassium,
         ObservedPhosphorus = Phosphorous,
         ObservedCalcium = Calcium)
Chemistry <- left_join(PredictedChem, ObservedChem, join_by("Sample_ID"))

Chemistry <- Chemistry %>% 
  filter(!is.na(ObservedPhosphorus))
Chemistry$ObservedNitrogen <- as.numeric(as.character(Chemistry$ObservedNitrogen))
Chemistry$ObservedPotassium <- as.numeric(as.character(Chemistry$ObservedPotassium))
Chemistry$ObservedPhosphorus <- as.numeric(as.character(Chemistry$ObservedPhosphorus))
Chemistry$ObservedCalcium <- as.numeric(as.character(Chemistry$ObservedCalcium))

# Add columns containing treatment information and convert units of traits

Chemistry <- Chemistry %>% 
  mutate(DryingTreatment = substring(sample_name, 13, 14)) %>% 
  mutate(MillingTreatment = substring(sample_name, 16, 19)) %>% 
  mutate(ObservedCalcium = ObservedCalcium * 10) %>% 
  mutate(ObservedNitrogen = ObservedNitrogen * 10)


# Create linear models comparing observed and predicted calcium values for all treatments

NEONCalciumODTWEN <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "TWEN"))
NEONCalciumFFTWEN <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "TWEN"))
NEONCalciumODBALL <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "BALL"))
NEONCalciumFFBALL <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "BALL"))
NEONCalciumODSIXT <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "SIXT"))
NEONCalciumFFSIXT <- lm(ObservedCalcium ~ PredictedCalcium, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "SIXT"))

summary(NEONCalciumODTWEN)
summary(NEONCalciumFFTWEN)
summary(NEONCalciumODBALL)
summary(NEONCalciumFFBALL)
summary(NEONCalciumODSIXT)
summary(NEONCalciumFFSIXT)

# Create linear models for observed and predicted nitrogen values for all treatments

NEONNitrogenODTWEN <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "TWEN"))
NEONNitrogenFFTWEN <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "TWEN"))
NEONNitrogenODBALL <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "BALL"))
NEONNitrogenFFBALL <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "BALL"))
NEONNitrogenODSIXT <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "OD" & MillingTreatment == "SIXT"))
NEONNitrogenFFSIXT <- lm(ObservedNitrogen ~ PredictedNitrogen, Chemistry, subset = (DryingTreatment == "FF" & MillingTreatment == "SIXT"))

summary(NEONNitrogenODTWEN)
summary(NEONNitrogenFFTWEN)
summary(NEONNitrogenODBALL)
summary(NEONNitrogenFFBALL)
summary(NEONNitrogenODSIXT)
summary(NEONNitrogenFFSIXT)

# Calculate normalized RMSE values for all linear models

ChemistryNRMSE <- Chemistry %>% 
  mutate(sqerrorN = (PredictedNitrogen - ObservedNitrogen)^2,
         sqerrorCa = (PredictedCalcium - ObservedCalcium)^2)

RMSEODTWENN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "TWEN" & DryingTreatment == "OD")$sqerrorN) / 60)
RMSEODSIXTN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "SIXT" & DryingTreatment == "OD")$sqerrorN) / 60)
RMSEODBALLN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "BALL" & DryingTreatment == "OD")$sqerrorN) / 60)
RMSEFFTWENN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "TWEN" & DryingTreatment == "FF")$sqerrorN) / 60)
RMSEFFSIXTN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "SIXT" & DryingTreatment == "FF")$sqerrorN) / 60)
RMSEFFBALLN <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "BALL" & DryingTreatment == "FF")$sqerrorN) / 60)

RMSEODTWENCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "TWEN" & DryingTreatment == "OD")$sqerrorCa) / 60)
RMSEODSIXTCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "SIXT" & DryingTreatment == "OD")$sqerrorCa) / 60)
RMSEODBALLCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "BALL" & DryingTreatment == "OD")$sqerrorCa) / 60)
RMSEFFTWENCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "TWEN" & DryingTreatment == "FF")$sqerrorCa) / 60)
RMSEFFSIXTCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "SIXT" & DryingTreatment == "FF")$sqerrorCa) / 60)
RMSEFFBALLCa <- sqrt(sum(subset(ChemistryNRMSE, MillingTreatment == "BALL" & DryingTreatment == "FF")$sqerrorCa) / 60)

ObservedChem <- ObservedChem %>% 
  filter(grepl("MILL24", Sample_ID))

ObservedChem$ObservedNitrogen <- as.numeric(as.character(ObservedChem$ObservedNitrogen))
ObservedChem$ObservedCalcium <- as.numeric(as.character(ObservedChem$ObservedCalcium))

NTWENRange <- max(subset(ChemistryNRMSE, MillingTreatment == "TWEN")$ObservedNitrogen) - min(subset(ChemistryNRMSE, MillingTreatment == "TWEN")$ObservedNitrogen)
NBALLRange <- max(subset(ChemistryNRMSE, MillingTreatment == "BALL")$ObservedNitrogen) - min(subset(ChemistryNRMSE, MillingTreatment == "BALL")$ObservedNitrogen)
NSIXTRange <- max(subset(ChemistryNRMSE, MillingTreatment == "SIXT")$ObservedNitrogen) - min(subset(ChemistryNRMSE, MillingTreatment == "SIXT")$ObservedNitrogen)

CaTWENRange <- max(subset(ChemistryNRMSE, MillingTreatment == "TWEN")$ObservedCalcium) - min(subset(ChemistryNRMSE, MillingTreatment == "TWEN")$ObservedCalcium)
CaBALLRange <- max(subset(ChemistryNRMSE, MillingTreatment == "BALL")$ObservedCalcium) - min(subset(ChemistryNRMSE, MillingTreatment == "BALL")$ObservedCalcium)
CaSIXTRange <- max(subset(ChemistryNRMSE, MillingTreatment == "SIXT")$ObservedCalcium) - min(subset(ChemistryNRMSE, MillingTreatment == "SIXT")$ObservedCalcium)


NRMSEODTWENN <- RMSEODTWENN / NTWENRange
NRMSEODSIXTN <- RMSEODSIXTN / NSIXTRange
NRMSEODBALLN <- RMSEODBALLN / NBALLRange
NRMSEFFTWENN <- RMSEFFTWENN / NTWENRange
NRMSEFFSIXTN <- RMSEFFSIXTN / NSIXTRange
NRMSEFFBALLN <- RMSEFFBALLN / NBALLRange

NRMSEODTWENCa <- RMSEODTWENCa / CaTWENRange
NRMSEODSIXTCa <- RMSEODSIXTCa / CaSIXTRange
NRMSEODBALLCa <- RMSEODBALLCa / CaBALLRange
NRMSEFFTWENCa <- RMSEFFTWENCa / CaTWENRange
NRMSEFFSIXTCa <- RMSEFFSIXTCa / CaSIXTRange
NRMSEFFBALLCa <- RMSEFFBALLCa / CaBALLRange

# Create plot for nitrogen comparison

mill_list = c(
  "BALL" = "Ball Milled",
  "SIXT" = "Fine Mesh Milled",
  "TWEN" = "Twenty Mesh Milled"
)

mill_labeller = function(variable, value) {
  return(mill_list[value])
}

RMSEText = data.frame(Trait = c("Nitrogen", "Nitrogen", "Nitrogen", "Calcium", "Calcium", "Calcium"),
                      DryingTreatment = c("OD", "OD", "OD", "OD", "OD", "OD"),
                      MillingTreatment = c("TWEN", "BALL", "SIXT", "TWEN", "BALL", "SIXT"),
                      Text = c("RMSE\nOD: 4.7283\nFF: 2.5155\nNRMSE\nOD: 0.1587\nFF: 0.08441",
                               "RMSE\nOD: 3.6028\nFF: 2.3976\nNRMSE\nOD: 0.1209\nFF: 0.08046",
                               "RMSE\nOD: 3.3014\nFF: 3.2074\nNRMSE\nOD: 0.1108\nFF: 0.1076",
                               "RMSE\nOD: 11.1227\nFF: 8.4293\nNRMSE\nOD: 0.1375\nFF: 0.1042",
                               "RMSE\nOD: 10.6364\nFF: 8.0178\nNRMSE\nOD: 0.1315\nFF: 0.0991",
                               "RMSE\nOD: 10.8417\nFF: 7.3402\nNRMSE\nOD: 0.1340\nFF: 0.0907"))


NEONNitrogenPlot <- ggplot(Chemistry, aes(x = PredictedNitrogen, y = ObservedNitrogen, color = DryingTreatment)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  geom_abline(slope = 1, intercept = 0, lwd = 1, linetype = "dashed") +
  scale_color_manual(values = c("#7AC5CD", "#d73027")) +
  geom_text(data = subset(RMSEText, Trait == "Nitrogen"), aes(label = Text), x = 8, y = 32, size = 2.5, inherit.aes = FALSE, hjust = 0) +
  facet_wrap(~MillingTreatment, labeller = mill_labeller) +
  xlab("Predicted Nitrogen") +
  ylab("Observed Nitrogen") +
  theme_bw() +
  labs(color = "Drying Treatment")

NEONNitrogenPlot

ggsave("NEONNitrogen.png", NEONNitrogenPlot, dpi = 320, scale = 2, width = 5, height = 1.875)

# Create plot for calcium comparison

NEONCalciumPlot <- ggplot(Chemistry, aes(x = PredictedCalcium, y = ObservedCalcium, color = DryingTreatment)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  geom_abline(slope = 1, intercept = 0, lwd = 1, linetype = "dashed") +
  scale_color_manual(values = c("#7AC5CD", "#d73027")) +
  geom_text(data = subset(RMSEText, Trait == "Calcium"), aes(label = Text), x = -5.5, y = 61.5, inherit.aes = FALSE, size = 2.5, hjust = 0) +
  facet_wrap(~MillingTreatment, labeller = mill_labeller) +
  theme_bw() +
  xlab("Predicted Calcium") +
  ylab("Observed Calcium") +
  labs(color = "Drying Treatment")
NEONCalciumPlot

ggsave("NEONCalcium.png", NEONCalciumPlot, dpi = 320, scale = 2, width = 5, height = 1.875)

# Create plot grid for chemistry

ObsvsPredPlotGrid <- plot_grid(NEONNitrogenPlot, NEONCalciumPlot, cols = 1, labels = c("A", "B"))
ObsvsPredPlotGrid

ggsave("ChemPlotGrid.png", ObsvsPredPlotGrid, dpi = 320, scale = 2, width = 5, height = 2.75)

################################# Variance Partitioning Analysis #################################################

# Load in sample information and join with chemistry data

sample_info <- read.csv("C:/Mill24/PCAFigures/PCA_Figures/CSV_Data/sample_info.csv") %>% 
  select(Sample_ID, Species_Code, Type)

PredictedChemVPA <- full_join(PredictedChem, sample_info, join_by(Sample_ID)) %>%  
  mutate(DryingTreatment = substring(sample_name, 13, 14)) %>% 
  mutate(MillingTreatment = substring(sample_name, 16, 19))

VPAModelCa <- varpart(Y = PredictedChem$PredictedCalcium, X = ~PredictedChemVPA$Species_Code, ~PredictedChemVPA$Type, ~PredictedChemVPA$MillingTreatment, ~PredictedChemVPA$DryingTreatment, data = PredictedChemVPA, chisquare = FALSE)  

summary(VPAModelCa)

VPACa <- plot(VPAModelCa, bg = 2:5)

VPAModelN <- varpart(Y = PredictedChem$PredictedNitrogen, X = ~PredictedChemVPA$Species_Code, ~PredictedChemVPA$Type, ~PredictedChemVPA$MillingTreatment, ~PredictedChemVPA$DryingTreatment, data = PredictedChemVPA, chisquare = FALSE)  

summary(VPAModelN)

VPAN <- plot(VPAModelN, bg = 2:5)



