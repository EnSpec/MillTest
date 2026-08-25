
library("FactoMineR")
library("factoextra")
library(tidyverse)
library(ggpubr)

spectral_data_NM<- read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/5nmResampleSpectra_NM.csv")
spectral_data_OD_NM<- read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/5nmResampleSpectra_OD_NM.csv")
spectral_data_OD_OM<- read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/5nmResampleSpectra_OD_OM.csv")
spectral_data_OM<- read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/5nmResampleSpectra_OM.csv")
sample_data <- read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/sample_info.csv")
drytrait_data_NM = read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/DryTraits_NM.csv")
drytrait_data_OM = read.csv("C:/Users/amajerus/Desktop/MillTest/PCAFiles/DryTraits_OM.csv")

#OLD MODEL PCAS

#refining drytrait_data.csv to only contain trait means
drytrait_data_OM <- drytrait_data_OM %>% select(- sample_name, -Species) %>% filter(Type == "Broadleaf" | Type == "Conifer") %>%  select(-contains('std'))

#BOTH OD AND FF
#performing pca on drytrait_data, defining columns 1:5 as supplementary variables and the traits as active
drytrait_OM.pca <- PCA(drytrait_data_OM, quali.sup = 1:5, graph = FALSE)
#creating a scree plot of the dry trait pca
scree_plot_OM<- fviz_eig(drytrait_OM.pca, addlabels = TRUE, ylim = c(0,50))

#plotting individual pca plots and pca biplots by growth form and mill method
OM_Growth_PCA<- fviz_pca_ind(drytrait_OM.pca, geom.ind = "point",
                          col.ind = drytrait_data_OM$Type,   # Color by the supplementary variable 'Group'
                          palette = "jco",                 # Choose a color palette (optional)
                          addEllipses = TRUE,              # Add confidence ellipses (optional)
                          legend.title = "Growth Form", repel = TRUE)

OM_Mill_PCA <- fviz_pca_ind(drytrait_OM.pca, geom.ind = "point",
                         col.ind = drytrait_data_OM$MillMethod,   # Color by the supplementary variable 'Group'
                         palette = "jco",                 # Choose a color palette (optional)
                         addEllipses = TRUE,              # Add confidence ellipses (optional)
                         legend.title = " Mill Type", repel = TRUE)

OM_DryingMethod_PCA <- fviz_pca_ind(drytrait_OM.pca, geom.ind = "point",
                         col.ind = drytrait_data_OM$DryingMethod,   # Color by the supplementary variable 'Group'
                         palette = "jco",                 # Choose a color palette (optional)
                         addEllipses = TRUE,              # Add confidence ellipses (optional)
                         legend.title = " Mill Type", repel = TRUE)
OM_DryingMethod_Biplot <- fviz_pca_biplot(drytrait_OM.pca, geom.ind = "point",
                                  col.ind = drytrait_data_OM$DryingMethod,   # Color by the supplementary variable 'Group'
                                  palette = "jco",                 # Choose a color palette (optional)
                                  addEllipses = TRUE,              # Add confidence ellipses (optional)
                                  legend.title = "Drying Method", repel = TRUE)
#saving plots to pngs
png("OM_DryingMethod_Biplot.png")
print(OM_DryingMethod_Biplot)
dev.off()

png("OM_DryingMethod_PCA.png")
print(OM_DryingMethod_PCA)
dev.off()

png("OM_Mill_PCA.png")
print(OM_Mill_PCA)
dev.off()

png("OM_Growth_PCA.png")
print(OM_Growth_PCA)
dev.off()

png("scree_plot_OM.png")
print(scree_plot_OM)
dev.off()

#Making boxplots of important trait data
#Nitrogen
OM_Nitrogen<- ggplot(drytrait_data_OM, aes(x=DryingMethod, y=t_mean_Nitrogen)) + facet_wrap(~Type) + geom_boxplot() + xlab('Drying Method') + ylab('t_mean_Nitrogen') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried Nitrogen by Drying Method")
#NSC
OM_NSC<- ggplot(drytrait_data_OM, aes(x=DryingMethod, y=t_mean_NSC)) + facet_wrap(~Type) + geom_boxplot() + xlab('Drying Method') + ylab('t_mean_NSC') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried NSC by Drying Method")
#saving plots to pdf
ggexport(plotlist = list(OM_Nitrogen, OM_NSC),
         filename = "OM_Trait_Boxplots.pdf")
#Lignin
OM_Lignin<- ggplot(drytrait_data_OM, aes(x=DryingMethod, y=t_mean_Lignin)) + facet_wrap(~Type) + geom_boxplot() + xlab('Drying Method') + ylab('t_mean_Lignin') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried Lignin by Drying Method")
ggexport(OM_Lignin, filename = "OM_Lignin.png")

#Making a csv with just FF samples
FF_Drytraits_OM = drytrait_data_OM %>% filter(DryingMethod == "FF")

#performing pca on drytrait_data, defining columns 1:5 as supplementary variables and the traits as active
FF_Drytraits_OM.pca <- PCA(FF_Drytraits_OM, quali.sup = 1:5, graph = FALSE)
#creating a scree plot of the dry trait pca
FF_scree_plot_OM<- fviz_eig(FF_Drytraits_OM.pca, addlabels = TRUE, ylim = c(0,50))

#plotting individual pca plots and pca biplots by growth form and mill method
FF_OM_Growth_PCA<- fviz_pca_ind(FF_Drytraits_OM.pca, geom.ind = "point",
                             col.ind = FF_Drytraits_OM$Type,   # Color by the supplementary variable 'Group'
                             palette = "jco",                 # Choose a color palette (optional)
                             addEllipses = TRUE,              # Add confidence ellipses (optional)
                             legend.title = "Growth Form", repel = TRUE)

FF_OM_Mill_PCA <- fviz_pca_ind(FF_Drytraits_OM.pca, geom.ind = "point",
                            col.ind = FF_Drytraits_OM$MillMethod,   # Color by the supplementary variable 'Group'
                            palette = "jco",                 # Choose a color palette (optional)
                            addEllipses = TRUE,              # Add confidence ellipses (optional)
                            legend.title = " Mill Type", repel = TRUE)


FF_OM_MillMethod_Biplot <- fviz_pca_biplot(FF_Drytraits_OM.pca, geom.ind = "point",
                                          col.ind = FF_Drytraits_OM$MillMethod,   # Color by the supplementary variable 'Group'
                                          palette = "jco",                 # Choose a color palette (optional)
                                          addEllipses = TRUE,              # Add confidence ellipses (optional)
                                          legend.title = "Mill Method", repel = TRUE)
