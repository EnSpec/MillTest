spectral_data<- read.csv("C:/Users/amajerus/Desktop/MillTest/CSVs/5nmResampleSpectraEdit.csv")
sample_data <- read.csv("C:/Users/amajerus/Desktop/MillTest/CSVs/sample_info.csv")
drytrait_data <- read.csv("C:/Users/amajerus/Desktop/MillTest/CSVs/DryTraitsEdit.csv")

library("FactoMineR")
library("factoextra")
library(tidyverse)
library(ggpubr)

#refining drytrait_data.csv to only contain trait means
drytrait_data <- drytrait_data %>% select(- X, - sample_name, -Species) %>% select(-contains('std'))

#performing pca on drytrait_data, defining rows 1:4 as supplementary variables and the traits as active
drytrait.pca <- PCA(drytrait_data, quali.sup = 1:4, graph = FALSE)
#creating a scree plot of the dry trait pca
scree_plot<- fviz_eig(drytrait.pca, addlabels = TRUE, ylim = c(0,50))

  
#plotting individual pca plots and pca biplots by growth form and mill method
Growth_PCA<- fviz_pca_ind(drytrait.pca, geom.ind = "point",
             col.ind = drytrait_data$Type,   # Color by the supplementary variable 'Group'
             palette = "jco",                 # Choose a color palette (optional)
             addEllipses = TRUE,              # Add confidence ellipses (optional)
             legend.title = "Growth Form", repel = TRUE)

Mill_PCA <- fviz_pca_ind(drytrait.pca, geom.ind = "point",
             col.ind = drytrait_data$MillMethod,   # Color by the supplementary variable 'Group'
             palette = "jco",                 # Choose a color palette (optional)
             addEllipses = TRUE,              # Add confidence ellipses (optional)
             legend.title = " Mill Type", repel = TRUE)

OD_Growth_Biplot <- fviz_pca_biplot(drytrait.pca, geom.ind = "point",
             col.ind = drytrait_data$Type,   # Color by the supplementary variable 'Group'
             palette = "jco",                 # Choose a color palette (optional)
             addEllipses = TRUE,              # Add confidence ellipses (optional)
             legend.title = "Growth Form", repel = TRUE)

OD_Mill_Biplot <- fviz_pca_biplot(drytrait.pca, geom.ind = "point",
                                    col.ind = drytrait_data$MillMethod,   # Color by the supplementary variable 'Group'
                                    palette = "jco",                 # Choose a color palette (optional)
                                    addEllipses = TRUE,              # Add confidence ellipses (optional)
                                    legend.title = "Mill Type", repel = TRUE)

#saving plots to pdfs
pdf("OD_Growth_Biplot.pdf")
print(OD_Growth_Biplot)
dev.off()

pdf("OD_Mill_Biplot.pdf")
print(OD_Mill_Biplot)
dev.off()

pdf("OD_Mill_PCA.pdf")
print(Mill_PCA)
dev.off()

pdf("OD_Growth_PCA.pdf")
print(Growth_PCA)
dev.off()

pdf("OD_Screeplot.pdf")
print(scree_plot)
dev.off()

#Making boxplots of important trait data
drytrait_data <- drytrait_data %>% filter(!(Type %in% c("Graminoid", "Forb")))

#Phenolics
OD_Phenolics<- ggplot(drytrait_data, aes(x=MillMethod, y=t_mean_Phenolics)) + facet_wrap(~Type) + geom_boxplot() + xlab('Mill Method') + ylab('t_mean_Phenolics') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried Phenolics by Mill Method")
#Nitrogen
OD_Nitrogen<- ggplot(drytrait_data, aes(x=MillMethod, y=t_mean_Phenolics)) + facet_wrap(~Type) + geom_boxplot() + xlab('Mill Method') + ylab('t_mean_Nitrogen') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried Nitrogen by Mill Method")
#NSC
OD_NSC<- ggplot(drytrait_data, aes(x=MillMethod, y=t_mean_Phenolics)) + facet_wrap(~Type) + geom_boxplot() + xlab('Mill Method') + ylab('t_mean_NSC') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried NSC by Mill Method")
#Calcium
OD_Calcium <- ggplot(drytrait_data, aes(x=MillMethod, y=t_mean_Phenolics)) + facet_wrap(~Type) + geom_boxplot() + xlab('Mill Method') + ylab('t_mean_Calcium') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried Calcium by Mill Method")
#d15
OD_d15 <- ggplot(drytrait_data, aes(x=MillMethod, y=t_mean_Phenolics)) + facet_wrap(~Type) + geom_boxplot() + xlab('Mill Method') + ylab('t_mean_d15N') +geom_violin(alpha = 0.5) + ggtitle("Oven Dried d15 by Mill Method")
#saving plots to pdf
ggexport(plotlist = list(OD_Phenolics, OD_Nitrogen, OD_NSC, OD_Calcium, OD_d15),
         filename = "Trait_Boxplots.pdf")
