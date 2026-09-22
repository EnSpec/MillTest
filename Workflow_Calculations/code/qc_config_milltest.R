##################################################
#
# qc_config_milltest.R
#
# Project-specific QC configuration for the Mill Test 2024 EcoSIS deposit.
# Committed with the repo deliberately -- this is part of the deposit's
# provenance, not just a runtime setting (per the 2026-09-20 QC standard
# decision in CLAUDE.md: shared checks live in enspec-qc, everything
# data-dependent -- grouping variable, bounds, thresholds -- lives here).
#
# For this deposit: FLAG-ONLY, TIMEBOXED (Henry, 2026-09-20). Nothing in
# `bounds_table` below triggers a removal; qc_apply_removals() is not
# called anywhere in TraitSpectralQC.R. `removal_policy` is kept as an
# explicit empty vector so that's a visible decision, not an omission.
#
##################################################

library(tidyverse)

# ---- Bounds tables ----------------------------------------------------

# Physical/definitional bounds -- true regardless of species or literature,
# because of how the value is computed (unit-based impossibility, matching
# Henry's "percent carbon below 0 or above 100" example).
physical_bounds <- tribble(
  ~trait,           ~lower, ~upper, ~source,    ~reason,
  "water_content",  0,      0.98,   "physical", "= (Fresh_mass - Dry_mass) / Fresh_mass (field_data provenance, confirmed 2026-09-22); bounded to [0,1) by construction -- can't be negative or reach 1 (would require zero dry mass)"
)

# Literature-sourced bounds, all in mg/g dry mass unless noted. Pulled
# 2026-09-22 from TRY 6.0 (Kattge et al. 2020; download
# /Volumes/Enspec/users/henry/TRY_Aug_2026/51461.txt) via
# enspec-qc::qc_try_bounds(), ErrorRisk <= 4, StdValue > 0 (isotopes
# excepted). d15N/lma use the same literature sources already cited in the
# GCFR trait QC (Workflow3_Outlier_Assess.R) rather than the TRY pull, for
# consistency with that precedent.
literature_bounds <- tribble(
  ~trait,                ~lower,    ~upper,   ~source,                                ~reason,
  "nitrogen_IRMS_mg_g",  0.6,       468.1,    "TRY (Kattge et al. 2020)",             "Leaf N content per dry mass",
  "nitrogen_mg_g",       0.6,       468.1,    "TRY (Kattge et al. 2020)",             "Leaf N content per dry mass (Brookside panel)",
  "phosphorus_mg_g",     0.094,     10.7,     "TRY (Kattge et al. 2020)",             "Leaf P content per dry mass",
  "potassium_mg_g",      0.3,       156.0,    "TRY (Kattge et al. 2020)",             "Leaf K content per dry mass",
  "calcium_mg_g",        0.40,      84.0,     "TRY (Kattge et al. 2020)",             "Leaf Ca content per dry mass",
  "magnesium_mg_g",      0.277,     16.45,    "TRY (Kattge et al. 2020)",             "Leaf Mg content per dry mass",
  "sulfur_mg_g",         0.447,     17.95,    "TRY (Kattge et al. 2020)",             "Leaf S content per dry mass",
  "boron_mg_g",          0.0063,    0.399,    "TRY (Kattge et al. 2020)",             "Leaf B content per dry mass",
  "iron_mg_g",           0.0086,    2.273,    "TRY (Kattge et al. 2020)",             "Leaf Fe content per dry mass",
  "manganese_mg_g",      0.0021,    12.2,     "TRY (Kattge et al. 2020)",             "Leaf Mn content per dry mass",
  "copper_mg_g",         0.00112,   0.1209,   "TRY (Kattge et al. 2020)",             "Leaf Cu content per dry mass",
  "zinc_mg_g",           0.0022,    0.798,    "TRY (Kattge et al. 2020)",             "Leaf Zn content per dry mass",
  "aluminum_mg_g",       0.004,     40.70,    "TRY (Kattge et al. 2020)",             "Leaf Al content per dry mass",
  "carbon_mg_g",         18.7,      657.9,    "TRY (Kattge et al. 2020)",             "Leaf C content per dry mass",
  "cellulose_mg_g",      62.9,      426.2,    "TRY (Kattge et al. 2020)",             "Leaf cellulose content per dry mass",
  "hemicellulose_mg_g",  87.1,      450.0,    "TRY (Kattge et al. 2020)",             "Leaf hemicellulose content per dry mass",
  "lignin_recal_mg_g",   13.7,      429.0,    "TRY (Kattge et al. 2020)",             "Leaf lignin content per dry mass",
  "phenolics_mg_g",      0.066,     33.23,    "TRY (Kattge et al. 2020)",             "Leaf phenolics content per dry mass",
  "d13C",                -39,       -9.8,     "TRY (Kattge et al. 2020)",             "Leaf delta13C signature",
  "d15N",                -14.4,     21.4,     "Craine et al. 2015, Plant and Soil",   "matches GCFR trait QC precedent (Workflow3_Outlier_Assess.R)",
  "lma_g_m2",            14,        1500,     "Wright et al. 2004, Nature",           "matches GCFR trait QC precedent (Workflow3_Outlier_Assess.R)",

  # chlorophyll_1..5 -- RESOLVED 2026-09-22 (Henry pointed at
  # bioscape-ground-data/Workflow8_Foliar_Chemistry_Collate/code/
  # step1_chemistry_collation.R for the units question): that script's data
  # dictionary states its own Chl1-5 columns are "Chlorophyll measurement
  # mg/m^2 made on leaf #1 replicate using a CCM-300" (an Opti-Sciences
  # chlorophyll content meter) -- leaf-AREA basis, not dry-mass. Corroborated
  # independently in this repo: the archived Mill_Test_Analysis.R drops
  # CFR1-5 columns (the CCM-300's raw fluorescence-ratio output) alongside
  # keeping Chl1-5 (the converted mg/m^2 values) from the same source
  # Chlorophyll.csv -- same raw+converted column pairing bioscape uses, same
  # lab, consistent with the same instrument. TRY's per-dry-mass chlorophyll
  # trait (used in the first bounds attempt) does not apply here at all.
  #   TRY's *per-leaf-area* chlorophyll trait pool turned out to mix true
  # g/m^2 mass measurements with raw SPAD/CCI/FCI instrument-index readings
  # under the same TraitName (confirmed 2026-09-22: pooled 99th percentile
  # jumps from 0.96 to 52+ once index-unit rows are included) -- filtered to
  # UnitName == "g m-2" only (n = 33,903) before taking this range, or the
  # bound would have been contaminated by unitless index values. Full
  # min-max of that filtered set, x1000 for g/m2 -> mg/m2.
  "chlorophyll_1",       63.8,      1296.3,   "TRY (Kattge et al. 2020), UnitName == 'g m-2' only", "Leaf chlorophyll content per leaf area (CCM-300, mg/m^2)",
  "chlorophyll_2",       63.8,      1296.3,   "TRY (Kattge et al. 2020), UnitName == 'g m-2' only", "Leaf chlorophyll content per leaf area (CCM-300, mg/m^2)",
  "chlorophyll_3",       63.8,      1296.3,   "TRY (Kattge et al. 2020), UnitName == 'g m-2' only", "Leaf chlorophyll content per leaf area (CCM-300, mg/m^2)",
  "chlorophyll_4",       63.8,      1296.3,   "TRY (Kattge et al. 2020), UnitName == 'g m-2' only", "Leaf chlorophyll content per leaf area (CCM-300, mg/m^2)",
  "chlorophyll_5",       63.8,      1296.3,   "TRY (Kattge et al. 2020), UnitName == 'g m-2' only", "Leaf chlorophyll content per leaf area (CCM-300, mg/m^2)"
)

# NOTE on the Brookside trace-element hard-bounds flags (aluminum_mg_g,
# copper_mg_g, iron_mg_g and similar): CONFIRMED 2026-09-22, not just
# suspected -- BrooksideExtract.R's clean_lt_values() floors any raw "< X"
# below-detection read to X/2 (half the reported per-element detection
# limit), matching the WisTraits precedent it already cites. Cross-checked
# against bioscape-ground-data's own Brookside collation
# (step1_chemistry_collation.R lines ~262-274), which confirms this lab
# routinely gets below-detection reads from this same vendor panel. A
# hard-bounds flag on one of these elements is very likely a legitimate
# detection-floored value, not a transcription error -- worth a quick look
# before assuming it's a problem, but not a reason to loosen the bound
# itself (the bound is still doing its job: surfacing values a reader
# should know are floored, not measured).

# TODO (Henry to confirm before this is final -- deliberately left NA/loose
# rather than guessed, following the "verify every number before writing it
# down" lesson from the citation pass elsewhere in this project):
#   - oil_content_mg_g: TRY's "Leaf lipid content per leaf dry mass" trait
#     returned 0 usable rows in this pull (checked 2026-09-22) -- no
#     literature range available from this source. Physical ceiling only.
#   - sodium_mg_g: no TRY trait for leaf Na found. Physical ceiling only.
#   - particle_size_mean_um / _variance / _skew / _kurtosis: not a
#     literature-bounds candidate (instrument/process output, no
#     independent "plausible range" in the trait literature) -- covered by
#     magnitude/distribution checks only, no hard bounds.
placeholder_ceiling_bounds <- tribble(
  ~trait,             ~lower, ~upper, ~source,    ~reason,
  "oil_content_mg_g", 0,      1000,   "physical", "mg/g of dry mass cannot exceed 1000 (100%); TODO tighter literature bound (TRY lipid trait had no usable rows in this pull)",
  "sodium_mg_g",      0,      1000,   "physical", "mg/g of dry mass cannot exceed 1000 (100%); TODO literature bound, no TRY leaf-Na trait found"
)

bounds_table <- bind_rows(physical_bounds, literature_bounds, placeholder_ceiling_bounds)

# ---- Grouping variables per trait category -----------------------------
# Henry, 2026-09-22: tree-level physical traits are swept at the species
# level; chemistry is best addressed at the treatment x species level
# (drying treatment -- FF/OD -- is the axis these assays actually vary
# over; none were re-run per mill treatment, see EcoSISMetadataSidecar.R);
# particle size at growth-form x mill-treatment, matching the manuscript's
# own particle-size table grouping (ParticleStat.R).
trait_groups <- list(
  tree_level = list(
    traits = c("fresh_mass_g", "dry_mass_g", "water_content", "leaf_area_cm2", "lma_g_m2",
              "chlorophyll_1", "chlorophyll_2", "chlorophyll_3", "chlorophyll_4", "chlorophyll_5"),
    group_var = "species_code",
    dedup_by = c("sample_name")
  ),
  drying_chemistry = list(
    traits = c("d13C", "d15N", "carbon_mg_g", "nitrogen_IRMS_mg_g", "phenolics_mg_g", "phenolics_sd",
              "hemicellulose_mg_g", "cellulose_mg_g", "lignin_recal_mg_g", "oil_content_mg_g", "oil_mass_mg"),
    group_var = "species_dry_treatment",
    dedup_by = c("sample_name", "dry_treatment")
  ),
  brookside_elemental = list(
    traits = c("nitrogen_mg_g", "phosphorus_mg_g", "magnesium_mg_g", "potassium_mg_g", "calcium_mg_g",
              "sulfur_mg_g", "boron_mg_g", "iron_mg_g", "manganese_mg_g", "copper_mg_g", "zinc_mg_g",
              "aluminum_mg_g", "sodium_mg_g"),
    group_var = "species_code",
    dedup_by = c("sample_name")
  ),
  particle_size = list(
    traits = c("particle_size_mean_um", "particle_size_variance", "particle_size_skew", "particle_size_kurtosis"),
    group_var = "growth_form_mill_treatment",
    dedup_by = c("sample_name", "mill_treatment")
  )
)

# ---- Wide-format replicate sets ----------------------------------------
# Traits measured as several replicate COLUMNS on the same individual,
# rather than several rows. The CCM-300 chlorophyll reads (leaf 1-5 per
# tree) are the one place in this dataset with genuine within-sample
# instrument replication, which makes them the only place the
# leave-one-out bad-measure check can actually run -- easy to miss,
# because the replicate structure is hidden in the column layout rather
# than in a replicate column. TraitSpectralQC.R pivots these long before
# calling qc_bad_single_measure().
#
# Motivating real case (2026-09-22): MILL24_0039 (SEPU) reads
# 218/205/161/34/281 mg/m^2 across its five leaves -- the 34 is 5-8x below
# its own siblings, consistent with the probe not being seated on the leaf.
# The hard-bounds sweep happens to catch this one too (34 < 63.8), but the
# leave-one-out check is the more sensitive test: it would also catch a bad
# read that stayed inside the literature range.
replicate_column_sets <- list(
  chlorophyll = list(
    cols = c("chlorophyll_1", "chlorophyll_2", "chlorophyll_3",
            "chlorophyll_4", "chlorophyll_5"),
    group_var = "sample_name",
    dedup_by = c("sample_name")
  )
)

# ---- Covariation checks --------------------------------------------------
# Trait pairs expected to strongly covary (robust SMA). First row mirrors
# the GCFR N-vs-LMA leaf-economics-spectrum precedent directly; second is
# Mill-Test-specific.
covariation_pairs <- tribble(
  ~trait1,               ~trait2,     ~log_scale, ~note,
  "nitrogen_IRMS_mg_g",  "lma_g_m2",  TRUE,       "leaf economics spectrum (GCFR precedent: N vs LMA)",
  "carbon_mg_g",         "lma_g_m2",  TRUE,       "structural-carbon vs LMA covariation"
)

# ---- Thresholds -----------------------------------------------------------
thresholds <- list(
  # Applies to the leave-one-out qc_bad_single_measure() check, which runs
  # on `replicate_column_sets` above (currently the CCM-300 chlorophyll
  # reads -- the only within-sample instrument replication carried into the
  # derived data). The TPC/ANKOM assays also have raw QC replicates, but
  # their *Extract.R scripts resolve those to one value per sample before
  # writing output, so they can't be checked here without going back to the
  # raw workbooks -- worth doing if the phenolics flags need chasing down.
  bad_measure_ratio   = 2,     # qc_bad_single_measure / qc_bad_ratio_component
  magnitude_log10     = 1,     # qc_magnitude_shift
  distribution_z      = 3.5,   # qc_distribution_outliers
  covariation_z       = 3,     # qc_covariation_outliers
  spectral_flat_range = 0.03,  # qc_spectral_flat
  spectral_flat_low   = 0.05,
  spectral_flat_high  = 0.95,
  spectral_angle_z    = 3      # qc_spectral_group_outliers
)

# ---- Removal policy ---------------------------------------------------
# Empty on purpose: everything in this deposit is flag-only per Henry's
# 2026-09-20 decision. Revisit (name traits here) only if/when the project
# moves off the timeboxed flag-only approach.
removal_policy <- character(0)
