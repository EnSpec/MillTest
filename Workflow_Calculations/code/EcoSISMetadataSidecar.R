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
#
# 2026-09-17 (Henry): also join in particle size and the isotope/TPC/ANKOM/
# fat-assay chemistry data as real columns here, not just raw xlsx files
# alongside the deposit -- the per-spectrum shape is what people will
# actually use. See ParticleStat.R and the Isotope/TPC/Ankom/FatAssayExtract.R
# scripts for how each of those is cleaned before this join. None of these
# cover every sample (isotope: 11, TPC: 60, ANKOM: 23, fat assay: 8,
# particle size: 22) -- NA elsewhere is expected, not a join bug.
#
# 2026-09-17 (later, Henry): also add the full Brookside elemental panel
# (BrooksideExtract.R -- 60 samples, one assay per sample, OD + 20-mesh
# material only, joined at the Sample_ID level same as ChemistryAnalysis.R
# does) and the fresh/dry mass + chlorophyll values already carried in
# sample_info.csv. These are tree-level, not treatment-level (one
# measurement per individual, not per drying/milling treatment) -- joined
# at the Sample_ID level and broadcast across every treatment/replicate row
# for that sample, same as Species/Type/coordinates already are below.
#
# 2026-09-17 (even later, Henry): renamed carbon_pct/nitrogen_pct to
# carbon_mg_g/nitrogen_IRMS_mg_g and oil_content_pct to oil_content_mg_g,
# converting all three to mg/g for unit consistency with the rest of the
# deposit's chemistry values (source conversion lives in IsotopeExtract.R /
# FatAssayExtract.R, not here). "IRMS" in the nitrogen name distinguishes
# this elemental-analyzer-derived %N from Brookside's separately-assayed
# nitrogen_mg_g. Also added leaf mass per area (LMA = dry mass / leaf area)
# -- leaf_area_cm2 comes from LeafAreaExtract.R
# (field_data/Mill24_LMA.xlsx), joined at the Sample_ID level like the
# other tree-level fields; lma_g_m2 is computed here from that plus the
# Dry_mass already joined in from sample_info.csv.

# 2026-10-19 (Henry): isotope, TPC and fat assay values are attached to BALL
# rows only and ANKOM values to TWEN (20-mesh) rows only, matching the powder
# each assay was run on. Previously they were copied across all three mill
# treatments, which overstated what was measured.

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

# Per-sample x mill-treatment particle-size moments -- see
# Workflow_Analysis/ParticleStat.R. Treatment-level, not per-replicate, so
# every replicate row within a sample x mill treatment gets the same value.
# Only covers the 22-individual particle-size campaign (a subset of all 61-66
# samples) plus the 2 Jun13 pilot samples -- NA for everyone else, expected.
particle_size <- read.csv(file.path(data_root, "derived", "particle_size",
                                    "particle_size_per_sample.csv")) %>%
  select(Sample, Treatment, Mean, Variance, Skew, Kurtosis) %>%
  rename(
    particle_size_mean_um     = Mean,
    particle_size_variance    = Variance,
    particle_size_skew        = Skew,
    particle_size_kurtosis    = Kurtosis
  )

# Per-sample x DRY-treatment chemistry (isotope, TPC, ANKOM, fat assay) --
# see IsotopeExtract.R / TPCExtract.R / AnkomExtract.R / FatAssayExtract.R.
# Each assay was run once per sample x drying treatment, on ONE mill
# treatment's powder (see assay_mill_basis below), so the value is attached
# to that mill treatment's replicate rows only. None of these cover
# every sample -- isotope is 11 samples, TPC/ANKOM are subsets too -- NA
# elsewhere is expected, not a join bug. Henry's call 2026-09-17: worth
# joining these directly into the sidecar rather than only shipping raw
# xlsx files, since the per-spectrum shape is what actually gets used.

isotope <- read.csv(file.path(data_root, "derived", "isotope", "isotope_mill_test.csv"))
tpc     <- read.csv(file.path(data_root, "derived", "tpc", "tpc_mill_test.csv"))
ankom   <- read.csv(file.path(data_root, "derived", "ankom", "ankom_mill_test.csv"))
fat_assay <- read.csv(file.path(data_root, "derived", "fat_assay", "fat_assay_mill_test.csv"))

# Mill treatment of the powder each assay was run on (2026-10-19, Henry).
# Isotope, TPC and fat assay: ball mill (BALL). ANKOM: 20-mesh (TWEN), an
# assay requirement. The fat assay basis was confirmed independently by Zach
# and a second person (2026-10-19). Assay values are NA on the other mill
# treatments' rows, since no assay was run on that material.
# Brookside (OD, 20-mesh) is deliberately NOT restricted: it is joined at the
# Sample_ID level as the common reference for every treatment.
assay_mill_basis <- c(isotope = "BALL", tpc = "BALL", ankom = "TWEN", fat_assay = "BALL")
isotope   <- mutate(isotope,   mill_treatment = assay_mill_basis[["isotope"]])
tpc       <- mutate(tpc,       mill_treatment = assay_mill_basis[["tpc"]])
ankom     <- mutate(ankom,     mill_treatment = assay_mill_basis[["ankom"]])
fat_assay <- mutate(fat_assay, mill_treatment = assay_mill_basis[["fat_assay"]])

# Per-sample (not per-treatment) full elemental panel -- see
# BrooksideExtract.R. One Brookside assay per sample (OD + 20-mesh material
# only); joined at the Sample_ID level and broadcast across every
# treatment/replicate row for that sample, same as ChemistryAnalysis.R's own
# treatment of this file (the single assayed value is the shared ground
# truth every treatment's spectral prediction gets compared against, not
# itself specific to one treatment's material). Covers 60 of the ~61-66
# samples -- NA for the rest, expected.
brookside <- read.csv(file.path(data_root, "derived", "brookside", "brookside_mill_test.csv"))

# Per-sample leaf area, for computing leaf mass per area (LMA = dry mass /
# area) -- see LeafAreaExtract.R. Tree-level like Fresh_mass/Dry_mass above,
# not treatment-specific. Covers 52 of the ~61-66 samples -- NA for the rest.
leaf_area <- read.csv(file.path(data_root, "derived", "leaf_area", "leaf_area_mill_test.csv"))

# --- build the sidecar ---------------------------------------------------

# sample_info.csv's X_Coord/Y_Coord are latitude/longitude respectively
# (confirmed 2026-09-11 fixing Map_Visualization.R's transposed axes) --
# not X/Y in the usual map sense.

ecosis_sidecar <- spec_meta %>%
  left_join(
    sample_info %>%
      select(Sample_ID, Species, Species_Code, Type, X_Coord, Y_Coord,
            Chl1, Chl2, Chl3, Chl4, Chl5, Fresh_mass, Dry_mass, Water_Content),
    by = c("SampleID" = "Sample_ID")
  ) %>%
  # particle_size_per_sample.csv's Treatment uses the recoded milling labels
  # (Ball/Fine/Twenty); spec_meta's MillTreat is the raw asd-filename code
  # (BALL/SIXT/TWEN) -- recode here just to join, matching ParticleStat.R's
  # own recode() exactly.
  mutate(mill_treatment_label = recode(MillTreat,
                                       BALL = "Ball", SIXT = "Fine", TWEN = "Twenty")) %>%
  left_join(
    particle_size,
    by = c("SampleID" = "Sample", "mill_treatment_label" = "Treatment")
  ) %>%
  # Each assay is joined only on the mill treatment of the powder it was run
  # on (assay_mill_basis above), so the value is NA on the other mill rows.
  left_join(isotope,   by = c("SampleID" = "Sample_ID", "DryTreat" = "dry_treatment", "MillTreat" = "mill_treatment")) %>%
  left_join(tpc,       by = c("SampleID" = "Sample_ID", "DryTreat" = "dry_treatment", "MillTreat" = "mill_treatment")) %>%
  left_join(ankom,     by = c("SampleID" = "Sample_ID", "DryTreat" = "dry_treatment", "MillTreat" = "mill_treatment")) %>%
  left_join(fat_assay, by = c("SampleID" = "Sample_ID", "DryTreat" = "dry_treatment", "MillTreat" = "mill_treatment")) %>%
  left_join(brookside, by = c("SampleID" = "Sample_ID")) %>%
  left_join(leaf_area, by = c("SampleID" = "Sample_ID")) %>%
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
    particle_size_mean_um  = particle_size_mean_um,
    particle_size_variance = particle_size_variance,
    particle_size_skew     = particle_size_skew,
    particle_size_kurtosis = particle_size_kurtosis,
    d13C                   = d13C,
    d15N                   = d15N,
    carbon_mg_g            = carbon_mg_g,
    nitrogen_IRMS_mg_g     = nitrogen_IRMS_mg_g,
    phenolics_mg_g         = phenolics_mg_g,
    phenolics_sd           = phenolics_sd,
    hemicellulose_mg_g     = hemicellulose_mg_g,
    cellulose_mg_g         = cellulose_mg_g,
    lignin_recal_mg_g      = lignin_recal_mg_g,
    oil_content_mg_g       = oil_content_mg_g,
    oil_mass_mg            = oil_mass_mg,
    nitrogen_mg_g          = nitrogen_mg_g,
    phosphorus_mg_g        = phosphorus_mg_g,
    magnesium_mg_g         = magnesium_mg_g,
    potassium_mg_g         = potassium_mg_g,
    calcium_mg_g           = calcium_mg_g,
    sulfur_mg_g            = sulfur_mg_g,
    boron_mg_g             = boron_mg_g,
    iron_mg_g              = iron_mg_g,
    manganese_mg_g         = manganese_mg_g,
    copper_mg_g            = copper_mg_g,
    zinc_mg_g              = zinc_mg_g,
    aluminum_mg_g          = aluminum_mg_g,
    sodium_mg_g            = sodium_mg_g,
    fresh_mass_g           = Fresh_mass,
    dry_mass_g             = Dry_mass,
    water_content          = Water_Content,
    leaf_area_cm2          = leaf_area_cm2,
    lma_g_m2               = Dry_mass / leaf_area_cm2 * 10000,  # g/cm^2 -> g/m^2
    chlorophyll_1          = Chl1,
    chlorophyll_2          = Chl2,
    chlorophyll_3          = Chl3,
    chlorophyll_4          = Chl4,
    chlorophyll_5          = Chl5,
    project           = "Milling and drying comparison 2024",
    pi                = "Philip A. Townsend",
    affiliation       = "University of Wisconsin-Madison, Forest and Wildlife Ecology"
  )

# --- resolve duplicate-scanned spectra ----------------------------------
# 7 sample x treatment combinations were scanned twice about a month apart
# (5 Sample_IDs: 0020, 0028, 0034, 0037, 0059), giving 42 replicate-level
# duplicates. `SpectralPredictR.R` keeps the LATER scan and drops the
# earlier one -- confirmed with Zach 2026-09-15 as the right call for all 7
# cases -- so its output carries 2376 spectra. This script was not applying
# the same rule, which left the sidecar at 2418 rows for 2376 spectra:
# two metadata rows per affected spectrum, differing only in
# measurement_datetime. That makes `spectra` a non-unique key and gives
# anyone joining the sidecar to the spectral files 42 spurious duplicate
# rows. Found 2026-09-23 while wiring up the QC checks.
n_before <- nrow(ecosis_sidecar)

ecosis_sidecar <- ecosis_sidecar %>%
  group_by(spectra) %>%
  slice_max(measurement_datetime, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  arrange(sample_name, dry_treatment, mill_treatment, replicate)

cat(sprintf("Duplicate-scan resolution: %d rows -> %d (kept the later scan per spectrum)\n",
           n_before, nrow(ecosis_sidecar)))
stopifnot(!any(duplicated(ecosis_sidecar$spectra)))

write.csv(ecosis_sidecar, file.path(out_dir, "spectral_metadata_sidecar.csv"), row.names = FALSE)

cat(sprintf("Wrote %d rows to %s\n", nrow(ecosis_sidecar),
           file.path(out_dir, "spectral_metadata_sidecar.csv")))
cat(sprintf("Rows missing species/site join: %d\n", sum(is.na(ecosis_sidecar$species))))
