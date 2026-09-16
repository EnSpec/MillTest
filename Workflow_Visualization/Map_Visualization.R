######################

#Project: Mill Test 2024

#Author(s): Annabelle Majerus

#File: Mapping Points

# 2026-09-11: rewritten off mapview (interactive-viewer package, not in
# renv.lock -- its spatial stack (leaflet/raster/terra/sp) won't build here
# without system GDAL) onto sf + ggplot2 for a static publication figure.
# Also fixes a real coordinate bug found while doing this: despite the
# names, X_Coord in sample_info.csv is latitude (~43 deg N) and Y_Coord is
# longitude (~-89 deg W) -- confirmed against the actual data. The old
# st_as_sf() call used coords = c("X_Coord", "Y_Coord"), i.e. (lat, lon) where
# sf expects (lon, lat) -- every point would have plotted transposed. The
# mapview() call above it had xcol/ycol the other way around and was correct;
# this rewrite uses that (correct) orientation throughout.

###########################

library(tidyverse)
library(sf)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "maps")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  filter(Type %in% c("Broadleaf", "Conifer"), Species_Code != "GLTR")

# coords = c(lon, lat); Y_Coord is the longitude column despite its name (see
# note above).
mill_sf <- st_as_sf(sample_info, coords = c("Y_Coord", "X_Coord"), crs = 4326)

sample_map <- ggplot(mill_sf) +
  geom_sf(aes(color = Type), size = 2, alpha = 0.8) +
  theme_bw() +
  labs(color = "Growth form", title = "Mill Test 2024 sample locations")

# coord_sf() preserves true geographic aspect ratio; the sample sites span
# ~40 km east-west but only ~2 km north-south, so a near-square canvas leaves
# most of the frame blank. Sized to roughly match that real aspect instead.
ggsave(file.path(out_dir, "sample_locations.png"), sample_map,
       width = 10, height = 3.5, dpi = 300)
