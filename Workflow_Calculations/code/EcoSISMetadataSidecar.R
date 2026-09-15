##################################################
#
# Title: EcoSIS Metadata Sidecar
#
# Project: Mill Test 2024
#
# Purpose: Build a per-spectrum metadata table matching the shape EcoSIS
# expects for the trait+spectra deposit (one row per spectrum, following
# the field layout of a real deposited UW-Madison/FERST dataset --
# https://tutorial.ecosis.org/demo_metadata.csv -- as a precedent).
# Not read by any analysis script -- deposit metadata only.
#
# Author: Mill Test Team, 2026 cleanup
#
##################################################

# 2026-09-15 (Henry): project = "Milling and drying comparison 2024",
# pi = "Philip A. Townsend", affiliation matches CITATION.cff,
# measurement_type = measurement = "REFL" (our sampling isn't a good fit
# for the demo's leaf-clip/canopy-style codes -- ground, milled, dried
# material in a press apparatus is a different context), with the
# milling/drying/replicate treatments as their own columns alongside the
# standard EcoSIS fields rather than folded into measurement_type.
#
# NOT the final version -- see CLAUDE.md. Still open: whether "REFL" and
# the fixed field values below match EcoSIS's actual controlled
# vocabulary (only checked against one example deposit, not their full
# documentation), and this depends on the duplicate-spectral-scan
# resolution already applied upstream in SpectralMeasurementMetadata.R.

library(tidyverse)

# --- data location (see README) --------------------------------------------
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")

out_dir <- file.path(data_root, "derived", "ecosis")
dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

# --- inputs ------------------------------------------------------------

# Per-replicate measurement provenance (person, time, instrument) --
# see Workflow_Calculations/code/SpectralMeasurementMetadata.R
spec_meta <- read.csv(file.path(data_root, "derived", "spectral_metadata",
                                "spectral_measurement_metadata.csv"))

sample_info <- read.csv(file.path(data_root, "field_data", "sample_info.csv"))

# --- build the sidecar ---------------------------------------------------

# sample_info.csv's X_Coord/Y_Coord are latitude/longitude respectively
# (confirmed 2026-09-11 fixing Map_Visualization.R's transposed axes) --
# not X/Y in the usual map sense.

ecosis_sidecar <- spec_meta %>%
  left_join(
    sample_info %>%
      select(Sample_ID, Species, Species_Code, Type, X_Coord, Y_Coord),
    by = c("SampleID" = "Sample_ID")
  ) %>%
  transmute(
    spectra           = sample_name,
    site              = "Lakeshore Nature Preserve",
    state             = "Wisconsin",
    latitude          = X_Coord,
    longitude         = Y_Coord,
    species           = Species,
    species_code      = Species_Code,
    growth_form       = Type,
    mill_treatment    = MillTreat,
    dry_treatment     = DryTreat,
    replicate         = Rep,
    sample_name       = SampleID,
    sample_year       = 2024,
    sample_type       = "Vegetation",
    measurement_type  = "REFL",
    measurement       = "REFL",
    measurement_datetime = spectra_datetime,
    measurement_person   = Spectra_Person,
    grind_date            = Grind_Date,
    grind_person           = Grind_Person,
    instrumentation   = "ASD FieldSpec 3",
    instrument_serial = instrument_num,
    calibration       = "Spectralon Ratio",
    wavelengths       = "Nanometers",
    column_units      = "Fraction",  # 0-1 reflectance, NOT percent -- confirmed 2026-09-15 against Mill24_RawSpec.csv value range
    project           = "Milling and drying comparison 2024",
    pi                = "Philip A. Townsend",
    affiliation       = "University of Wisconsin-Madison, Forest and Wildlife Ecology"
  )

write.csv(ecosis_sidecar, file.path(out_dir, "spectral_metadata_sidecar.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows to %s\n", nrow(ecosis_sidecar),
           file.path(out_dir, "spectral_metadata_sidecar.csv")))
cat(sprintf("Rows missing species/site join: %d\n", sum(is.na(ecosis_sidecar$species))))
