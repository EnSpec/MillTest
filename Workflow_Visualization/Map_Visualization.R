######################

#Project: Mill Test 2024

#Author(s): Annabelle Majerus

#File: Mapping Points

###########################

install.packages("mapview")

library(tidyverse)
library(sf)
library(mapview)

#annabelle pc
sample_info = read.csv("C:\\Users\\amajerus\\Desktop\\MillTest\\MillTest\\General_Data\\sample_info.csv")
#annabelle mac
sample_info = read.csv("/Users/annabellemajerus/Desktop/Mega_Folder/Townsend/Mill_24/MillTestGit/General_Data/sample_info.csv")

sample_info = sample_info %>% filter(Type == "Broadleaf" | Type == "Conifer") %>% filter(Species_Code != "GLTR")

mapview(sample_info, xcol = "Y_Coord", ycol = "X_Coord", crs = 4269, grid = FALSE)
mill_sf <- st_as_sf(sample_info, coords = c("X_Coord", "Y_Coord"),  crs = 4326)
mapview(mill_sf, map.types = "CartoDB.DarkMatter") 
