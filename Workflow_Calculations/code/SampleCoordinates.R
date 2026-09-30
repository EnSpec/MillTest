##################################################
#
# Title: Sample Coordinates
#
# Project: Mill Test 2024
#
# Purpose: Rebuild every sample's collection coordinates from the raw field
# records, so the locations shipped in `field_data/sample_info.csv` (and from
# there the EcoSIS sidecar and the site map) trace back to a source.
#
# Sources, in priority order:
#   1. Google Maps pins. The field crew dropped a pin for each tree in a shared
#      Google Maps list ("Mill24"; the same list the inventory workbook links
#      to). 43 pins cover 41 samples. A dated snapshot of the list is saved
#      under `field_data/raw_coordinates/` the first time this script runs,
#      and every later run reads the snapshot, not the live list, because a
#      shared list can be edited after the fact.
#   2. The "Field Sample Inventory" sheet of
#      `field_data/mill_test_inventory_data_log.xlsx`, for the 25 samples with
#      no pin. Its coordinates were typed in by hand, and three carry
#      transcription errors (see `coordinate_corrections` below).
#
# Cross-check only (never a coordinate source): 9 trees were sampled for the
# Lakeshore Nature Preserve project (LSNP24) on the same day as for this
# study. The inventory's Notes column carries the LSNP24 ID, and the LSNP24
# tree sheet marks the same 9 trees "mill sample". Their field-delineated
# crown centers are compared against the coordinates used here. A crown
# center is not the collection point, so a gap of a few metres is expected.
#
# Outputs:
#   derived/field/sample_coordinates.csv       one row per sample, with source,
#                                              any correction applied, and the
#                                              cross-check distances
#   derived/field/cross_project_sample_links.csv
#                                              Mill Test <-> LSNP24 tree links.
#                                              The linked samples are the same
#                                              tree on the same day, so any
#                                              model that trains on both
#                                              datasets must keep each pair in
#                                              the same train/test split.
#   field_data/sample_info.csv                 X_Coord (latitude) and Y_Coord
#                                              (longitude) replaced with the
#                                              rebuilt values; all other
#                                              columns untouched. The version
#                                              from before the first rebuild
#                                              is kept alongside as a backup.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

library(tidyverse)
library(readxl)
library(jsonlite)
library(sf)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

raw_dir <- file.path(data_root, "field_data", "raw_coordinates")
out_dir <- file.path(data_root, "derived", "field")
dir.create(raw_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

google_list_id  <- "9hsHK70GyO4ngY71QAx838GjG7vq_w"
google_snapshot <- file.path(raw_dir, "google_maps_mill24_list_20260930.txt")

# Crown centers for the LSNP24 trees, from the LSNP24 project's field crown
# delineation (UTM 16N). The `_centers` layer is used, not the
# `_centroids_shifttohyspex` layer, which was moved to align with imagery.
lsnp24_crown_gpkg <- "/Volumes/Enspec/users/sjgraves/data/vector/field_delineated_crowns/lsnp24_crowns_20240809_centers.gpkg"
crown_snapshot    <- file.path(raw_dir, "lsnp24_crown_centers_mill_links.csv")

haversine_m <- function(lat1, lon1, lat2, lon2) {
  to_rad <- pi / 180
  dlat <- (lat2 - lat1) * to_rad
  dlon <- (lon2 - lon1) * to_rad
  a <- sin(dlat / 2)^2 + cos(lat1 * to_rad) * cos(lat2 * to_rad) * sin(dlon / 2)^2
  2 * 6371000 * asin(sqrt(a))
}

# --- 1. Field inventory sheet ----------------------------------------------
inventory <- read_excel(
  file.path(data_root, "field_data", "mill_test_inventory_data_log.xlsx"),
  sheet = "Field Sample Inventory", .name_repair = "unique_quiet"
) %>%
  filter(str_detect(Sample_ID, "^MILL\\s*24_\\d{4}$")) %>%
  transmute(
    Sample_ID    = str_replace(Sample_ID, "^MILL\\s+24", "MILL24"),
    Species_Code = str_remove(Species_Code, "_.*$"),  # SEPU_BLADE/_STEM -> SEPU
    Sampling_Date = as.integer(Sampling_Date),
    sheet_lat    = as.numeric(X_Coord),  # X_Coord is latitude despite its name
    sheet_lon    = as.numeric(Y_Coord),
    inventory_notes = Notes
  )

stopifnot("inventory Sample_IDs must be unique" = !anyDuplicated(inventory$Sample_ID))

# --- 2. Hand-entry corrections -----------------------------------------------
# Each correction is checked against the value it replaces, so if the
# inventory sheet is ever fixed at the source this script stops instead of
# applying a correction twice.
coordinate_corrections <- tribble(
  ~Sample_ID,    ~field,      ~from,       ~to,          ~evidence,
  "MILL24_0006", "sheet_lon", -89.932177,  -89.432177,
    "Dropped digit. As entered the tree plots ~40 km west of every other sample. The corrected point is ~10 m from this tree's LSNP24_0009 crown center and beside MILL24_0007/0008, sampled the same day.",
  "MILL24_0065", "sheet_lat",  43.098408,   43.0918408,
    "Dropped digit. The Google Maps pin for this tree is 43.0918408, -89.4324523; as entered it sits ~730 m north of the other white cedars (0062-0064), sampled the same day.",
  "MILL24_0048", "sheet_lon", -89.42121,   -89.42812,
    "Probable dropped digit. As entered it sits ~510 m east of every other sample; the other red pines sampled the same day (0049, 0053) are at -89.4280 to -89.4281. No pin or crown exists to confirm, and no field GPS backup exists."
)

for (i in seq_len(nrow(coordinate_corrections))) {
  corr <- coordinate_corrections[i, ]
  row  <- which(inventory$Sample_ID == corr$Sample_ID)
  current <- inventory[[corr$field]][row]
  if (length(row) != 1 || abs(current - corr$from) > 1e-9) {
    stop(sprintf("Correction for %s expected %s = %s but found %s; has the inventory changed?",
                 corr$Sample_ID, corr$field, corr$from, current))
  }
  inventory[[corr$field]][row] <- corr$to
}

# --- 3. Google Maps pins -----------------------------------------------------
if (!file.exists(google_snapshot)) {
  # Unofficial endpoint the Google Maps web client uses to load a shared list.
  pb <- paste0("!1m4!1s", google_list_id,
               "!2e1!3m1!1e1!2e2!3e2!4i500!6m3!1s!7e81!28e2!12e1!10m0!21m0")
  url <- paste0("https://www.google.com/maps/preview/entitylist/getlist",
                "?authuser=0&hl=en&gl=us&pb=", URLencode(pb, reserved = TRUE))
  download.file(url, google_snapshot, quiet = TRUE)
  message("Saved a new Google Maps list snapshot: ", google_snapshot)
}

# The response starts with an anti-JSON-hijacking line, `)]}'`.
google_raw <- read_lines(google_snapshot)
google_list <- fromJSON(paste(google_raw[-1], collapse = "\n"), simplifyVector = FALSE)
stopifnot("snapshot is not the expected list" = google_list[[1]][[1]][[1]] == google_list_id)

pins <- map_dfr(google_list[[1]][[9]], function(item) {
  tibble(
    pin_label = item[[4]] %||% "",
    pin_lat   = item[[2]][[6]][[3]],
    pin_lon   = item[[2]][[6]][[4]],
    pin_created_utc = as.POSIXct(item[[10]][[1]], origin = "1970-01-01", tz = "UTC")
  )
}) %>%
  mutate(
    pin_label = str_squish(pin_label),
    pin_sample = str_match(pin_label, "(?i)mill\\s*24[_\\s]+0*(\\d{1,4})")[, 2],
    pin_sample = if_else(is.na(pin_sample), NA_character_,
                         sprintf("MILL24_%04d", as.integer(pin_sample)))
  )

# Pins whose label names the wrong sample. Both corrections are backed by an
# exact coordinate match to the inventory row and by the species in the label.
pin_label_overrides <- tribble(
  ~pin_label,               ~Sample_ID,    ~evidence,
  "Mill24_0014 red oak",    "MILL24_0013",
    "A second '0014' pin. MILL24_0014 is a hackberry with its own correctly labelled pin; MILL24_0013 is the red oak sampled the same day, and its inventory coordinates equal this pin exactly.",
  "Mill24_0039 red cedar",  "MILL24_0040",
    "MILL24_0039 is yellow foxtail (stem) and shares its point with MILL24_0038 (blade); MILL24_0040 is the red cedar, and its inventory coordinates equal this pin exactly."
)

pins <- pins %>%
  left_join(pin_label_overrides %>% select(pin_label, override = Sample_ID), by = "pin_label") %>%
  mutate(Sample_ID = coalesce(override, pin_sample)) %>%
  select(-override, -pin_sample)

unassigned_pins <- pins %>% filter(is.na(Sample_ID))
pins <- pins %>% filter(!is.na(Sample_ID))

stopifnot("each sample may have at most one pin" = !anyDuplicated(pins$Sample_ID),
          "every pin must name a sample in the inventory" = all(pins$Sample_ID %in% inventory$Sample_ID),
          "every label override must match a pin" = all(pin_label_overrides$Sample_ID %in% pins$Sample_ID))

# --- 4. LSNP24 crown centers (cross-check only) -----------------------------
links <- inventory %>%
  mutate(linked_sample_id = str_extract(inventory_notes, "LSNP24_\\d{4}")) %>%
  filter(!is.na(linked_sample_id)) %>%
  select(Sample_ID, Species_Code, Sampling_Date, linked_sample_id)

if (!file.exists(crown_snapshot)) {
  crowns <- st_read(lsnp24_crown_gpkg, quiet = TRUE) %>% st_transform(4326)
  xy <- st_coordinates(crowns)
  tibble(linked_sample_id = toupper(crowns$treeid), crown_species = crowns$species,
         crown_lon = xy[, 1], crown_lat = xy[, 2]) %>%
    filter(linked_sample_id %in% links$linked_sample_id) %>%
    mutate(source = lsnp24_crown_gpkg) %>%
    write.csv(crown_snapshot, row.names = FALSE)
  message("Saved LSNP24 crown centers for the linked trees: ", crown_snapshot)
}
crowns <- read.csv(crown_snapshot)
stopifnot("every linked LSNP24 tree needs a crown center" = all(links$linked_sample_id %in% crowns$linked_sample_id))

# --- 5. Assemble ---------------------------------------------------------------
sample_coordinates <- inventory %>%
  left_join(pins, by = "Sample_ID") %>%
  left_join(links %>% select(Sample_ID, linked_sample_id), by = "Sample_ID") %>%
  left_join(crowns %>% select(linked_sample_id, crown_lat, crown_lon), by = "linked_sample_id") %>%
  left_join(coordinate_corrections %>% select(Sample_ID, correction = evidence), by = "Sample_ID") %>%
  left_join(pin_label_overrides %>% select(Sample_ID, pin_label_note = evidence), by = "Sample_ID") %>%
  mutate(
    coord_source = case_when(
      !is.na(pin_lat)    ~ "google_maps_pin",
      !is.na(correction) ~ "field_inventory_corrected",
      TRUE               ~ "field_inventory"
    ),
    latitude  = round(coalesce(pin_lat, sheet_lat), 7),
    longitude = round(coalesce(pin_lon, sheet_lon), 7),
    pin_vs_inventory_m = haversine_m(pin_lat, pin_lon, sheet_lat, sheet_lon),
    crown_vs_used_m    = haversine_m(crown_lat, crown_lon, latitude, longitude),
    crosscheck_flag = case_when(
      crown_vs_used_m > 15 ~ "more than 15 m from the LSNP24 crown center; see notes",
      TRUE ~ NA_character_
    ),
    notes = case_when(
      Sample_ID == "MILL24_0009" ~ "LSNP24 field notes record this tree as a black locust clump; the collection point and the delineated crown center may mark different stems.",
      TRUE ~ NA_character_
    )
  )

# With the corrections applied, every pin should agree with the hand-entered
# inventory to within rounding. A larger gap means a new transcription error.
bad_pins <- sample_coordinates %>% filter(pin_vs_inventory_m > 1)
if (nrow(bad_pins) > 0) {
  print(bad_pins %>% select(Sample_ID, pin_label, pin_lat, pin_lon, sheet_lat, sheet_lon, pin_vs_inventory_m))
  stop("Google Maps pins disagree with the inventory sheet by more than 1 m for the samples above.")
}

# Every sample should fall inside the study area (all trees are within ~1.5 km
# of each other on the UW-Madison campus).
centre_lat <- median(sample_coordinates$latitude)
centre_lon <- median(sample_coordinates$longitude)
far <- sample_coordinates %>%
  filter(haversine_m(latitude, longitude, centre_lat, centre_lon) > 2000)
if (nrow(far) > 0) {
  print(far %>% select(Sample_ID, latitude, longitude, coord_source))
  stop("Samples above are more than 2 km from the study-area centre.")
}

# --- 6. Write outputs ----------------------------------------------------------
sample_coordinates %>%
  select(Sample_ID, Species_Code, Sampling_Date, latitude, longitude, coord_source,
         correction, pin_label, pin_created_utc, pin_label_note,
         inventory_lat = sheet_lat, inventory_lon = sheet_lon, pin_vs_inventory_m,
         linked_sample_id, crown_lat, crown_lon, crown_vs_used_m, crosscheck_flag, notes) %>%
  write.csv(file.path(out_dir, "sample_coordinates.csv"), row.names = FALSE, na = "")

links %>%
  left_join(sample_coordinates %>% select(Sample_ID, crown_vs_used_m), by = "Sample_ID") %>%
  transmute(
    Sample_ID, Species_Code, Sampling_Date,
    linked_project   = "LSNP24 (Lakeshore Nature Preserve, 2024)",
    linked_sample_id,
    relationship     = "same tree, sampled the same day",
    crown_center_distance_m = round(crown_vs_used_m, 1)
  ) %>%
  write.csv(file.path(out_dir, "cross_project_sample_links.csv"), row.names = FALSE)

# sample_info.csv: replace the two coordinate columns only.
sample_info_path <- file.path(data_root, "field_data", "sample_info.csv")
backup_path <- file.path(data_root, "field_data", "sample_info_pre_coordinate_rebuild_20260930.csv")
if (!file.exists(backup_path)) invisible(file.copy(sample_info_path, backup_path))

sample_info <- read.csv(sample_info_path)
stopifnot("sample_info.csv and the inventory must list the same samples" =
            setequal(sample_info$Sample_ID, sample_coordinates$Sample_ID))
species_check <- sample_info %>%
  select(Sample_ID, Species_Code) %>%
  inner_join(sample_coordinates %>% select(Sample_ID, inv_code = Species_Code), by = "Sample_ID") %>%
  filter(Species_Code != inv_code)
stopifnot("species codes must agree between sample_info.csv and the inventory" = nrow(species_check) == 0)

sample_info <- sample_info %>%
  select(-X_Coord, -Y_Coord) %>%
  left_join(sample_coordinates %>% select(Sample_ID, X_Coord = latitude, Y_Coord = longitude),
            by = "Sample_ID") %>%
  relocate(X_Coord, Y_Coord, .after = Sampling_Date)
write.csv(sample_info, sample_info_path, row.names = FALSE)

# --- 7. Report -----------------------------------------------------------------
cat(sprintf("Coordinates for %d samples: %s\n", nrow(sample_coordinates),
            paste(names(table(sample_coordinates$coord_source)),
                  table(sample_coordinates$coord_source), sep = " = ", collapse = ", ")))
cat(sprintf("Largest pin vs. inventory gap after corrections: %.2f m\n",
            max(sample_coordinates$pin_vs_inventory_m, na.rm = TRUE)))
cat("LSNP24 crown-center distances (m):\n")
print(sample_coordinates %>% filter(!is.na(linked_sample_id)) %>%
        transmute(Sample_ID, linked_sample_id, crown_vs_used_m = round(crown_vs_used_m, 1)))
if (nrow(unassigned_pins) > 0) {
  cat("Pins in the list that name no sample (not used):\n")
  print(unassigned_pins %>% select(pin_label, pin_lat, pin_lon))
}
