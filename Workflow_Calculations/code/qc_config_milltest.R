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
# For this deposit: FLAG-ONLY by default (timeboxed, Henry 2026-09-20), with
# exactly one exception added 2026-09-23 -- spectra with R350 >= 0.9 are
# removed and logged, because that can't be a real sample measure. See
# `removal_policy` below; every other check only flags.
#
# Trait bounds are split into `removable_bounds` (physically impossible
# values) and `flag_only_bounds` (literature/TRY ranges). That split is
# load-bearing, not cosmetic: literature ranges never drive removals
# (Henry, 2026-09-23), and the guard next to `removal_policy` enforces it.
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

# A negative concentration, mass or area is impossible (Henry, 2026-09-23).
# Built programmatically rather than typed out 30 times, with the carve-out
# stated explicitly so it stays auditable: ISOTOPE RATIOS ARE LEGITIMATELY
# NEGATIVE (d13C runs about -25 to -30 permil, d15N can take either sign),
# so they get no zero floor and keep their signed literature ranges.
#
# This gap is how a real error hid. MILL24_0035 FF carries
# hemicellulose_mg_g = -157.1 (raw workbook: Perc_Hemiceullose = -15.71%,
# faithfully converted by AnkomExtract.R -- the error is in the source data,
# not the script). In the ANKOM sequential method hemicellulose = NDF - ADF,
# so a negative means ADF came out larger than NDF, which shouldn't happen;
# the same sample's OD run is a normal +17.30%. Until now that value only
# showed up as a *literature* flag, which badly understates it: it isn't
# outside a compiled range, it's impossible.
nonnegative_traits <- c(
  # chemistry, per dry mass
  "carbon_mg_g", "nitrogen_IRMS_mg_g", "phenolics_mg_g", "phenolics_sd",
  "hemicellulose_mg_g", "cellulose_mg_g", "lignin_recal_mg_g",
  "oil_content_mg_g", "oil_mass_mg",
  # Brookside elemental panel
  "nitrogen_mg_g", "phosphorus_mg_g", "magnesium_mg_g", "potassium_mg_g",
  "calcium_mg_g", "sulfur_mg_g", "boron_mg_g", "iron_mg_g", "manganese_mg_g",
  "copper_mg_g", "zinc_mg_g", "aluminum_mg_g", "sodium_mg_g",
  # masses, areas, derived structure
  "fresh_mass_g", "dry_mass_g", "leaf_area_cm2", "lma_g_m2",
  "chlorophyll_1", "chlorophyll_2", "chlorophyll_3", "chlorophyll_4", "chlorophyll_5",
  # particle size: a mean diameter and a variance can't be negative. Skew is
  # signed by definition, and kurtosis is deliberately left alone --
  # ParticleStat.R reports it on the Pearson scale, but asserting a floor
  # there would be over-claiming.
  "particle_size_mean_um", "particle_size_variance"
)

physical_bounds <- bind_rows(
  physical_bounds,
  tibble(
    trait  = nonnegative_traits,
    lower  = 0,
    upper  = NA_real_,
    source = "physical",
    reason = "a concentration, mass or area cannot be negative (isotope ratios excluded -- legitimately signed)"
  )
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
  # Micronutrients: UPPER BOUND ONLY, deliberately (2026-09-23). TRY's
  # compiled *minimum* is the wrong statistic for a lower bound on a trace
  # element -- it's the smallest value anyone happened to publish, not a
  # plausibility floor, and there's no reason a leaf can't hold less Al than
  # the least-Al leaf in the literature. Worse, Brookside reports these as
  # ppm with a detection limit, and BrooksideExtract.R floors below-detection
  # reads to half that limit, which lands *below* TRY's minimum by
  # construction. Using TRY's min here generated 1728 of 2772 literature
  # flags (Al 33 samples, Cu 10, Fe 5) purely from below-detection values
  # being below-detection. "Unusually low" is a distribution question, and
  # the distribution/magnitude checks already cover it. Upper bounds stay --
  # those are meaningful, since a very high value suggests contamination or a
  # unit error.
  "boron_mg_g",          NA,        0.399,    "TRY (Kattge et al. 2020), upper only", "Leaf B content per dry mass; lower bound dropped -- see note above",
  "iron_mg_g",           NA,        2.273,    "TRY (Kattge et al. 2020), upper only", "Leaf Fe content per dry mass; lower bound dropped -- see note above",
  "manganese_mg_g",      NA,        12.2,     "TRY (Kattge et al. 2020), upper only", "Leaf Mn content per dry mass; lower bound dropped -- see note above",
  "copper_mg_g",         NA,        0.1209,   "TRY (Kattge et al. 2020), upper only", "Leaf Cu content per dry mass; lower bound dropped -- see note above",
  "zinc_mg_g",           NA,        0.798,    "TRY (Kattge et al. 2020), upper only", "Leaf Zn content per dry mass; lower bound dropped -- see note above",
  "aluminum_mg_g",       NA,        40.70,    "TRY (Kattge et al. 2020), upper only", "Leaf Al content per dry mass; lower bound dropped -- see note above",
  "carbon_mg_g",         18.7,      657.9,    "TRY (Kattge et al. 2020)",             "Leaf C content per dry mass",
  "cellulose_mg_g",      62.9,      426.2,    "TRY (Kattge et al. 2020)",             "Leaf cellulose content per dry mass",
  "hemicellulose_mg_g",  87.1,      450.0,    "TRY (Kattge et al. 2020)",             "Leaf hemicellulose content per dry mass",
  "lignin_recal_mg_g",   13.7,      429.0,    "TRY (Kattge et al. 2020)",             "Leaf lignin content per dry mass",
  # PHENOLICS UPPER BOUND -- NEEDS HENRY'S CALL (flagged 2026-09-23).
  # This bound flags 44 of 60 samples, values running 33.5-108.6 mg/g against
  # a TRY max of 33.23. That pattern says "wrong bound", not "bad data": our
  # TPC is Folin-Ciocalteu gallic-acid-equivalents on oak and conifer foliage,
  # where tannin-rich material in the 50-150 mg/g GAE range is unremarkable,
  # whereas TRY's "Leaf phenols content per leaf dry mass" is a small trait
  # (n = 1225) that may not be assay-comparable. Deliberately NOT widened on
  # my own judgement -- that's a domain call. Options: drop the upper bound
  # like the micronutrients, substitute a GAE-specific literature range, or
  # keep it and accept the flags as advisory.
  "phenolics_mg_g",      0.066,     33.23,    "TRY (Kattge et al. 2020) -- SUSPECT, see note", "Leaf phenolics content per dry mass; flags 44/60 samples, likely not assay-comparable to Folin-Ciocalteu GAE",
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

# Two SEPARATE bounds tables, run as two separate checks -- not one combined
# sweep (Henry, 2026-09-23). Only physically impossible values are ever
# candidates for removal; a literature/TRY range is flag-only, always,
# because this lab works with very diverse material and a true value outside
# TRY's compiled range isn't surprising. Keeping them structurally separate
# means a future project can't enable removals and silently take the
# literature bounds along with them -- see the removal_policy guard below.
removable_bounds <- bind_rows(physical_bounds, placeholder_ceiling_bounds)
flag_only_bounds <- literature_bounds

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

# ---- Sequential assay chains -------------------------------------------
# ANKOM fiber is a sequential wash: NDF, then ADF on the NDF residue, then
# ADL on the ADF residue. A failure at an early stage puts everything
# derived after it in doubt, whether or not the later value looks sane
# (Henry, 2026-09-23). Traits listed in processing order.
#
# Policy is "flag", not "remove", and that's a considered choice for the one
# case this currently fires on. MILL24_0035 FF has an impossible
# hemicellulose, and tracing the arithmetic shows exactly why: hemicellulose
# = Perc_Remaining_Post_NDF - Perc_Remaining_Post_ADF, and that sample's
# stated Perc_Remaining_Post_NDF (16.82%) disagrees with its own weights,
# which imply 45.31%. Across the rest of the FF batch stated and
# weight-derived agree to within ~0.7 points, and Perc_Remaining_Post_ADF is
# consistent for every row including this one. So a single cell is wrong.
# Cellulose (post-ADF minus post-ADL) and lignin (post-ADL) don't use that
# cell, so they're very likely fine -- but "very likely fine, per Claude's
# arithmetic" isn't the standard for a deposit, so they get flagged for a
# human to confirm rather than silently trusted or silently dropped.
#
# Side note worth acting on separately: the underlying value is recoverable.
# Recomputing post-NDF from the weights gives hemicellulose ~12.8%, an
# unremarkable number for this batch (range up to 39.3%). Fixing that one
# cell would restore the measurement rather than lose it.
sequential_assay_chains <- list(
  ankom_fiber = list(
    chain    = c("hemicellulose_mg_g", "cellulose_mg_g", "lignin_recal_mg_g"),
    key_cols = c("sample_name", "dry_treatment"),
    policy   = "flag"
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

  # qc_spectral_group_outliers. Switched from robust-z to an ABSOLUTE angle
  # threshold in degrees (2026-09-23). A robust z within a 6-scan group
  # computes its MAD on 5 angles, so the scale estimate is mostly noise, and
  # a set whose scans agree unusually tightly flags a perfectly good sibling
  # just for being slightly less tight. The angle itself is on a fixed,
  # physically interpretable scale, so a degree threshold means the same
  # thing across reruns and across projects -- and it's something a data user
  # can actually reason about.
  #
  # Set from the observed distribution on this dataset (1980 non-reference
  # scans): median 0.212 deg, 95th 0.518, 99th 0.703, max 1.277. At 0.75 deg
  # this flags 12 scans (0.61%), which fits "outliers should be rare in a
  # controlled system" far better than robust-z > 3 did (60 scans, 3.0%).
  spectral_angle_method   = "absolute",
  spectral_angle_max_deg  = 0.75,
  spectral_angle_z        = 3,   # only used if method is switched to "robust_z"

  # PCA review flags (qc_spectral_pca_flags). Review-only, never removal.
  # k and the thresholds live here rather than in the function, per the
  # per-project-config rule.
  pca_n_pc            = 5,
  pca_within_z        = 3,     # replicate vs. its own sample centroid
  pca_between_z       = 3,     # sample centroid vs. its group centroid

  # Assay-specific checks (Henry, 2026-09-23).
  #
  # Phenolics: the TPC sheets report a mean GAE and an SD across their own
  # duplicate/triplicate measures, carried through by TPCExtract.R as
  # phenolics_mg_g / phenolics_sd. A CV above ~10% means the assay disagreed
  # with itself badly enough not to trust that result, independent of whether
  # the value looks plausible. Observed distribution here: median 0.25%,
  # 99th percentile 11.2%, max 12.5% -- so 10% flags 2 of 120, appropriately
  # rare.
  phenolics_max_cv    = 0.10,

  # ANKOM blank bag: an empty bag carried through the same washes should only
  # lose weight. A gain means it leaked and took on material, so it was
  # shedding sample material too and the whole batch is suspect. 1% is a
  # threshold in common use elsewhere; any gain at all is reported regardless,
  # since a blank has no business gaining weight.
  ankom_blank_increase = 0.01
)

# ---- ANKOM start weight -------------------------------------------------
# The protocol calls for 0.5 g of sample per bag, +/- 0.05
# (Hobbie_Ankom_Protocol_Frye_edited2025.docx, prep step 4), so a start weight
# outside 0.450-0.550 g means the weighing was mis-entered or the bag was
# mis-packed (Henry, 2026-09-24). Worth checking because the start weight is
# the denominator of all three fiber fractions: a wrong one scales every trait
# for that sample without making any of them look impossible.
#
# FLAG-ONLY, deliberately. A weight slightly outside the window is a protocol
# deviation, not an impossibility -- the assay arithmetic still holds, so the
# value may be perfectly usable. It is the far-off ones that indicate a
# transcription error, and a human should decide which is which.
ankom_weight_bounds <- tibble::tribble(
  ~trait,        ~lower, ~upper, ~source,                              ~reason,
  "sample_wt_g",  0.450,  0.550, "Hobbie/Frye ANKOM protocol, step 4", "start weight outside the protocol's 0.5 g +/- 0.05 window -- mis-entered weight or a mis-packed bag; it is the denominator of all three fiber fractions"
)

# ---- Spectral-angle reference -------------------------------------------
# "medoid" (the real scan with the smallest summed angle to the others) or
# "albedo" (the real scan closest to the group's median brightness).
# Mill Test is dry powder measured in a press apparatus -- a controlled
# setting where the replicates should be near-identical and the question is
# which one doesn't belong -- so medoid (Henry, 2026-09-23). Albedo is
# expected to matter more for fresh-leaf and field spectroscopy.
spectral_angle_reference <- "medoid"

# ---- Single-band threshold ----------------------------------------------
# From the SHIFT dried-ground reflectance DAAC product, which removes every
# spectrum with R350 >= 0.9 as "abnormal reflectance". Dry leaf powder sits
# far below that at 350 nm (Mill Test's own max is 0.13, checked
# 2026-09-22), so a value that high means the white reference panel or an
# empty puck got measured instead of the sample.
#
# `band` can be a single wavelength or c(lower, upper) to average over a
# range -- averaging 350-400 is worth considering, since 350 nm alone is the
# noisiest band on an ASD. Left at the single band to match SHIFT exactly.
spectral_band_check <- list(
  band  = 350,
  upper = 0.9,
  lower = NULL
)

# ---- Removal policy ---------------------------------------------------
# Named checks whose flags become REMOVALS. Everything else is flag-only.
#
# Two exceptions to this deposit's flag-only default, both Henry 2026-09-23:
#
#   spectral_band_threshold - an R350 above 0.9 can't be a real sample
#     measure, so those spectra are dropped and logged. Removes nothing on
#     the current data (Mill Test has none) but the policy is correct for
#     reruns and for adopting projects.
#
#   trait_physical_bounds - "any negative values (completely impossible)
#     should be dropped and logged." A physically impossible value isn't
#     salvageable, so the value is NA'd (not the whole row -- the rest of
#     that sample's data is fine) and written to removal_log.csv. On the
#     current data this drops exactly one value: MILL24_0035 FF
#     hemicellulose_mg_g = -157.1.
#
# Trait *literature* bounds stay flag-only and must NEVER appear here; the
# guard below enforces that rather than trusting a comment.
removal_policy <- c("spectral_band_threshold", "trait_physical_bounds")

stopifnot(
  "literature bounds are flag-only and must not drive removals (CLAUDE.md, Henry 2026-09-23)" =
    !("trait_literature_bounds" %in% removal_policy),
  "no literature-bound trait may be named in removal_policy" =
    !any(flag_only_bounds$trait %in% removal_policy)
)

