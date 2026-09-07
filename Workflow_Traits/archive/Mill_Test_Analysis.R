# Henry makes a comment

### Mill Test Code


setwd('/Users/annabellemajerus/Desktop/Mill Test R/')

library(tidyverse)

#loading csv files

LMA_Data = read.csv('LMA_data.csv')
Chlorophyll = read.csv('Chlorophyll.csv')
Spp_Checklist = read.csv('Spp_Checklist.csv')
Field_Sample_Inventory = read.csv('Field_Sample_Inventory.csv')

#creating dataframe

data <- full_join(Chlorophyll, Field_Sample_Inventory, join_by(Sample_ID))
data <- data %>% full_join(LMA_Data, join_by(Sample_ID)) %>% select(-Sampling_Date.y, -Notes.y)
data <- data %>% rename(Sampling_Date = Sampling_Date.x, Notes = Notes.x) %>% arrange(Sample_ID)

#Linking Species ID to growth form categories
Spp_Checklist <- Spp_Checklist %>% select(- Number.of.Samples.Needed, - Current.Samples.Collected, - Complete.)
Spp_Checklist <- Spp_Checklist %>% rename(Species_Code = Species.Code, Type = Type..Broadleaf..Conifer..Forb..Graminoid.)

data <- data %>% full_join(Spp_Checklist, join_by(Species_Code))

#calculating water content
data <- data %>% mutate(Water_Content = (Fresh_mass - Dry_mass) / (Fresh_mass))

#cleaning up the data frame
data <- data %>% select(-Notes, -Dry_mass_date, -Dry_mass_person, -CFR1, -CFR2, -CFR3, -CFR4, -CFR5)
data<- data %>% select(-X)
write.csv(data, file = "/Users/annabellemajerus/Desktop/Mill Test R/CSVs/sample_info.csv", row.names = FALSE)

#creating a boxplot of the chlorophyll data broken up by growth form

data_long <- data %>%
  pivot_longer(cols = starts_with("Chl"),  # Specify columns to reshape
               names_to = "Chl",     # Name for the new category column
               values_to = "Chl_Value")       # Name for the new value column
data_long <- data_long %>% select(-Chl)

ggplot(data_long, aes(x=Type, y=Chl_Value)) + geom_boxplot() +xlab('Growth Form') +ylab('Chl Value')
ggsave("chlorophyll_growth.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')

#creating a boxplot of leaf water content broken up by growth form

ggplot(data = data, aes(x=Type, y=Water_Content)) +geom_boxplot() +xlab('Growth Form') +ylab('Leaf Water Content')
ggsave("water_content_growth.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')

#creating a boxplot of conifer chlorophyll broken up by species

conifer_data_long <- data_long %>% filter(Type == "Conifer")
ggplot(conifer_data_long, aes(x=Species_Code, y=Chl_Value)) + geom_boxplot() +xlab('Species') +ylab('Chl Value')
ggsave("chlorophyll_conifer.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')


#creating a boxplot of conifer leaf water content broken up by species

conifer_data <- data %>% filter(Type == 'Conifer')
ggplot(conifer_data, aes(x=Species_Code, y=Water_Content)) + geom_boxplot() +xlab('Species') +ylab('Leaf Water Content')
ggsave("conifer_water_content.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')

#creating a boxplot of broadleaf chlorophyll broken up by species

broadleaf_data_long <- data_long %>% filter(Type == 'Broadleaf')
ggplot(broadleaf_data_long, aes(x=Species_Code, y=Chl_Value)) + geom_boxplot() +xlab('Species') +ylab('Chl Value')
ggsave("broadleaf_chlorophyll.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')

#creating a boxplot of broadleaf leaf water content broken up by species

broadleaf_data <- data %>% filter(Type == 'Broadleaf')
ggplot(broadleaf_data, aes(x=Species_Code, y=Water_Content)) + geom_boxplot() +xlab('Species') +ylab('Leaf Water Content')
ggsave("broadleaf_water_content.png", path = '/Users/annabellemajerus/Desktop/Mill Test R/Figures')
