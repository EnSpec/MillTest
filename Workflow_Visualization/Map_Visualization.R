######################

#Project: Mill Test 2024

#Author(s): Annabelle Majerus (original); Mill Test Team (publication version)

#File: Mapping Points

# Supplement figure: locations of the 61 sampled trees on a public-domain
# topographic basemap, with a scale bar, north arrow, and a Wisconsin inset.
#
# History
# 2026-09-11: rewritten off mapview (interactive-viewer package whose spatial
# stack won't build without system GDAL) onto sf + ggplot2. Also fixed a real
# coordinate bug: despite the names, X_Coord in sample_info.csv is latitude
# (~43 deg N) and Y_Coord is longitude (~-89 deg W); the old st_as_sf() call
# used (lat, lon) where sf expects (lon, lat), so every point plotted
# transposed.
# 2026-09-30: coordinates in sample_info.csv are rebuilt from the raw field
# records by Workflow_Calculations/code/SampleCoordinates.R (three hand-entry
# errors corrected); run that first.
# 2026-10-18: publication version. USGS National Map basemap (public domain),
# ggspatial scale bar and north arrow, points coloured by species (shape by
# growth form), Wisconsin inset.
# 2026-10-19: colour now encodes growth form only (two Okabe-Ito colours) and
# shape encodes species within growth form, because the 11-colour species
# palette had several near-identical blues that could not be told apart.
#
# Basemap and offline behaviour
# Tiles come from the USGS National Map "USGS Topo" service and are cached in
# <data_root>/derived/maps/tile_cache, so re-running does not need the
# network once the tiles exist. If the tiles are neither cached nor
# downloadable, the figure is drawn without a basemap (points, scale bar and
# north arrow only) and a message says so; the script never fails for lack of
# a network. Basemap credit (USGS, public domain) is printed on the figure.

###########################

library(tidyverse)
library(sf)
library(ggspatial)
library(cowplot)
# jpeg (tile decoding) and abind (stitching) are called with :: below

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "maps")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)
tile_cache <- file.path(out_dir, "tile_cache")
dir.create(tile_cache, showWarnings = FALSE)

# Design population only (61 trees, 11 species), as in the manuscript
sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv")) %>%
  filter(Type %in% c("Broadleaf", "Conifer"), Species_Code != "GLTR")

# coords = c(lon, lat); Y_Coord is the longitude column despite its name.
mill_sf <- st_as_sf(sample_info, coords = c("Y_Coord", "X_Coord"), crs = 4326)

# --- styling: colour = growth form, shape = species -------------------------
# Eleven species cannot be told apart by colour alone under colour-vision
# deficiency, so colour carries only growth form (two Okabe-Ito colours) and
# shape identifies the species within its growth form. Shapes are reused across
# growth forms; the shape + colour pair is unique. Darker outlines of the same
# hue keep the points legible on the topographic basemap.
broadleaf_species <- c(
  "Hackberry (Celtis occidentalis)", "Black Locust (Robinia pseudoacacia)",
  "Red Oak (Quercus rubra)", "Sugar Maple (Acer saccharum)",
  "Pagoda Dogwood (Cornus alternifolia)", "Buckthorn (Rhamnus cathartica)")
conifer_species <- c(
  "Red Pine (Pinus resinosa)", "White Pine (Pinus strobus)",
  "Red Cedar (Juniperus virginiana)", "Norway Spruce (Picea abies)",
  "White Cedar (Thuja occidentalis)")
species_levels <- c(broadleaf_species, conifer_species)
stopifnot(all(unique(mill_sf$Species) %in% species_levels))

# circle, square, diamond, triangle up, triangle down are fillable (21-25);
# the sixth broadleaf species gets a cross (4), drawn in the outline colour
species_shape <- setNames(c(21, 22, 23, 24, 25, 4, 21, 22, 23, 24, 25),
                          species_levels)
form_fill    <- c(Broadleaf = "#E69F00", Conifer = "#009E73")
form_outline <- c(Broadleaf = "#7A5200", Conifer = "#00553D")
form_labels  <- c(Broadleaf = "Broadleaf", Conifer = "Needle/scale-leaf")
species_form <- ifelse(species_levels %in% broadleaf_species, "Broadleaf", "Conifer")

# legend labels: common name, scientific name in italics
legend_label <- function(x) {
  common <- sub(" \\(.*$", "", x)
  sci <- sub("^.*\\((.*)\\)$", "\\1", x)
  sprintf('"%s ("*italic("%s")*")"', common, sci)
}

mill_sf <- mill_sf %>%
  mutate(Species = factor(Species, levels = species_levels),
         Type = factor(Type, levels = c("Broadleaf", "Conifer")))

# --- basemap: USGS National Map tiles, cached, no raster/terra needed -----------
# Slippy-map (XYZ) tiles in Web Mercator (EPSG:3857). Tiles are downloaded
# once into tile_cache and re-used; if any needed tile can't be cached or
# fetched, get_basemap() returns NULL and the map is drawn without a basemap.

tile_url <- "https://basemap.nationalmap.gov/arcgis/rest/services/USGSTopo/MapServer/tile/%d/%d/%d"
zoom <- 16

tile_index <- function(lon, lat, z) {
  lon <- unname(lon); lat <- unname(lat)  # keep c(x =, y =) names clean
  n <- 2^z
  c(x = floor((lon + 180) / 360 * n),
    y = floor((1 - log(tan(lat * pi / 180) + 1 / cos(lat * pi / 180)) / pi) / 2 * n))
}
tile_extent_3857 <- function(x, y, z) {
  origin <- pi * 6378137
  size <- 2 * origin / 2^z
  c(xmin = -origin + x * size, xmax = -origin + (x + 1) * size,
    ymax = origin - y * size, ymin = origin - (y + 1) * size)
}

get_basemap <- function(bb_lonlat, z) {
  lo <- tile_index(bb_lonlat["xmin"], bb_lonlat["ymax"], z)  # top-left tile
  hi <- tile_index(bb_lonlat["xmax"], bb_lonlat["ymin"], z)  # bottom-right tile
  xs <- lo["x"]:hi["x"]; ys <- lo["y"]:hi["y"]
  rows <- list()
  for (yy in ys) {
    row <- list()
    for (xx in xs) {
      f <- file.path(tile_cache, sprintf("usgstopo_z%d_%d_%d.jpg", z, xx, yy))
      if (!file.exists(f)) {
        ok <- tryCatch({
          suppressWarnings(download.file(sprintf(tile_url, z, yy, xx), f,
                                         mode = "wb", quiet = TRUE))
          TRUE }, error = function(e) FALSE)
        if (!ok) { unlink(f); return(NULL) }
      }
      img <- tryCatch(jpeg::readJPEG(f), error = function(e) NULL)
      if (is.null(img)) { unlink(f); return(NULL) }
      row[[length(row) + 1]] <- img
    }
    rows[[length(rows) + 1]] <- do.call(abind::abind, c(row, list(along = 2)))
  }
  img <- do.call(abind::abind, c(rows, list(along = 1)))
  ext_tl <- tile_extent_3857(min(xs), min(ys), z)
  ext_br <- tile_extent_3857(max(xs), max(ys), z)
  list(img = as.raster(img),
       xmin = unname(ext_tl["xmin"]), xmax = unname(ext_br["xmax"]),
       ymin = unname(ext_br["ymin"]), ymax = unname(ext_tl["ymax"]))
}

# map extent: bounding box of the points plus padding, in lon/lat then 3857
bb <- st_bbox(mill_sf)
bb_num <- setNames(as.numeric(bb)[1:4], c("xmin", "ymin", "xmax", "ymax"))
pad_x <- (bb_num["xmax"] - bb_num["xmin"]) * 0.30
pad_y <- (bb_num["ymax"] - bb_num["ymin"]) * 0.30
bb_pad <- c(xmin = unname(bb_num["xmin"] - pad_x), ymin = unname(bb_num["ymin"] - pad_y),
            xmax = unname(bb_num["xmax"] + pad_x), ymax = unname(bb_num["ymax"] + pad_y))
bb_3857 <- st_bbox(st_transform(st_as_sfc(st_bbox(bb_pad, crs = st_crs(4326))), 3857))

basemap <- get_basemap(bb_pad, zoom)
if (is.null(basemap)) {
  message("USGS tiles are neither cached nor downloadable; drawing the map ",
          "without a basemap.")
}

mill_3857 <- st_transform(mill_sf, 3857)

map_main <- ggplot() +
  {if (!is.null(basemap))
    annotation_raster(basemap$img, xmin = basemap$xmin, xmax = basemap$xmax,
                      ymin = basemap$ymin, ymax = basemap$ymax,
                      interpolate = TRUE)} +
  geom_sf(data = mill_3857, aes(shape = Species, fill = Type, colour = Type),
          size = 3, stroke = 0.7, alpha = 0.95) +
  scale_shape_manual(values = species_shape, name = "Species",
                     labels = parse(text = legend_label(species_levels)),
                     drop = FALSE,
                     guide = guide_legend(order = 2, override.aes = list(
                       fill = unname(form_fill[species_form]),
                       colour = unname(form_outline[species_form]),
                       size = 3, stroke = 0.7))) +
  scale_fill_manual(values = form_fill, labels = form_labels,
                    name = "Growth form",
                    guide = guide_legend(order = 1, override.aes = list(
                      shape = 21, colour = unname(form_outline), size = 3.5))) +
  scale_colour_manual(values = form_outline, guide = "none") +
  annotation_scale(location = "bl", width_hint = 0.25, text_cex = 0.8) +
  annotation_north_arrow(location = "tr", which_north = "true",
                         style = north_arrow_minimal(text_size = 9),
                         height = unit(1.2, "cm"), width = unit(1.2, "cm")) +
  coord_sf(xlim = c(bb_3857["xmin"], bb_3857["xmax"]),
           ylim = c(bb_3857["ymin"], bb_3857["ymax"]),
           crs = st_crs(3857), default_crs = st_crs(3857),
           datum = st_crs(4326), expand = FALSE) +
  labs(x = "Longitude", y = "Latitude",
       caption = if (!is.null(basemap))
         "Basemap: U.S. Geological Survey, The National Map (USGS Topo); public domain."
       else "Basemap unavailable offline; USGS Topo tiles not cached.") +
  theme_bw(base_size = 11) +
  theme(legend.position = "right", legend.text = element_text(size = 8),
        panel.grid = element_line(colour = "grey85", linewidth = 0.2),
        plot.caption = element_text(size = 7, hjust = 0))

# --- Wisconsin inset -------------------------------------------------------
wi <- st_as_sf(maps::map("state", "wisconsin", plot = FALSE, fill = TRUE))
site <- st_as_sfc(st_bbox(mill_sf)) %>% st_centroid()
inset <- ggplot() +
  geom_sf(data = wi, fill = "grey95", colour = "grey30", linewidth = 0.3) +
  geom_sf(data = site, shape = 21, fill = "black", colour = "black", size = 2.6) +
  theme_void() +
  theme(panel.border = element_rect(colour = "black", fill = NA, linewidth = 0.4),
        plot.background = element_rect(fill = "white", colour = NA))

full <- ggdraw(map_main) +
  draw_plot(inset, x = 0.108, y = 0.60, width = 0.17, height = 0.28)

ggsave(file.path(out_dir, "sample_locations.png"), full,
       width = 8.5, height = 5.5, dpi = 300, bg = "white")
message("Wrote ", file.path(out_dir, "sample_locations.png"),
        if (is.null(basemap)) " (no basemap)" else "")
