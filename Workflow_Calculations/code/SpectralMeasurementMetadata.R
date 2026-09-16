##################################################
#
# Title: Spectral Measurement Metadata
#
# Project: Mill Test 2024
#
# Purpose: Build a per-spectrum provenance table (measurement date/time,
# operator, grind date/operator, instrument) for the EcoSIS trait+spectra
# deposit. Not read by any analysis script -- provenance only.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

# Two sources, joined:
#  1. Per-REPLICATE measurement timestamp + instrument info, read directly
#     from each raw .asd file's binary header via the `asdreader` package
#     (spectrolab's own `extract_metadata=` is documented as ASD-unsupported
#     -- .sig/.sed only -- so this needed a different package; confirmed
#     2026-09-15). The ASD header's own operator/comment field is present
#     but empty in every file checked -- not a usable source for who took
#     the measurement.
#  2. Per-SAMPLE x TREATMENT (not per-replicate) grind + spectra operator,
#     read from the measurement-log spreadsheet Zach provided 2026-09-14
#     (`field_data/mill_test_inventory_data_log.xlsx`, `Sample Inventory`
#     sheet) -- this is where "who took the measurement" actually lives.

library(tidyverse)
library(asdreader)
library(readxl)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
specfolder <- Sys.getenv("MILL24_SPEC_FOLDER", unset = file.path(data_root, "DrySpec"))
out_dir <- file.path(data_root, "derived", "spectral_metadata")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- 1. per-replicate metadata from the raw .asd headers -------------------

asd_files <- list.files(specfolder, pattern = "\\.asd$", recursive = TRUE, full.names = TRUE)

read_asd_meta <- function(path) {
  md <- get_metadata(path)
  sample_name <- tools::file_path_sans_ext(basename(path))
  tibble(
    sample_name         = sample_name,
    spectra_datetime     = md$when,
    integration_time_ms = md$it,
    instrument           = md$instrument,
    instrument_num       = md$instrument_num,
    asd_comment           = md$comments,
    asd_file_version      = md$co
  )
}

asd_meta <- map(asd_files, read_asd_meta) %>% bind_rows()

asd_meta <- asd_meta %>%
  separate_wider_delim(
    sample_name, delim = "_",
    names = c("Mill", "SampleID", "DryTreat", "MillTreat", "Rep"),
    cols_remove = FALSE
  ) %>%
  mutate(
    measure_id = paste(Mill, SampleID, DryTreat, MillTreat, sep = "_"),
    SampleID   = paste0("MILL24_", SampleID)
  )

# --- 2. per-sample x treatment grind/spectra operator from the inventory ---

inventory_path <- file.path(data_root, "field_data", "mill_test_inventory_data_log.xlsx")

inventory <- read_excel(
  inventory_path, sheet = "Sample Inventory", skip = 1,
  col_names = c("Sampling_Date", "Sample_ID_num", "Type", "MillTreat",
               "Grind_Date", "Grind_Person", "Spectra_Date_inventory",
               "Spectra_Person", "Notes", "c10", "c11"),
  # Grind_Date/Spectra_Date_inventory read as "numeric": these cells hold
  # a plain YYYYMMDD integer (e.g. 20241230), not a native Excel date
  # serial -- col_type "date" would (and did) misinterpret that integer AS
  # a serial, giving nonsense dates (year 57318). "text" just stringifies
  # the underlying double in scientific notation ("2.024123E7"). Numeric
  # + manual %Y%m%d parsing is the only one of the three that's correct.
  col_types = c("text", "numeric", "text", "text", "numeric", "text",
               "numeric", "text", "text", "text", "text")
) %>%
  filter(!is.na(Sample_ID_num)) %>%
  mutate(
    SampleID = sprintf("MILL24_%04d", as.integer(Sample_ID_num)),
    DryTreat = Type,
    Grind_Date             = format(as.Date(as.character(Grind_Date), format = "%Y%m%d"), "%Y-%m-%d"),
    Spectra_Date_inventory = format(as.Date(as.character(Spectra_Date_inventory), format = "%Y%m%d"), "%Y-%m-%d")
  ) %>%
  select(SampleID, DryTreat, MillTreat, Grind_Date, Grind_Person,
        Spectra_Date_inventory, Spectra_Person, Notes)

# --- join + write ------------------------------------------------------

spectral_metadata <- asd_meta %>%
  left_join(inventory, by = c("SampleID", "DryTreat", "MillTreat"))

write.csv(spectral_metadata,
         file.path(out_dir, "spectral_measurement_metadata.csv"),
         row.names = FALSE)

cat(sprintf("Wrote %d rows (%d unique sample x treatment groups, %d unmatched against inventory) to %s\n",
           nrow(spectral_metadata),
           n_distinct(spectral_metadata$measure_id),
           sum(is.na(spectral_metadata$Spectra_Person)),
           file.path(out_dir, "spectral_measurement_metadata.csv")))
