# Data manifest — Mill Test 2024 EcoSIS deposit

What should accompany this code repo's Zenodo DOI as the trait + spectra
dataset DOI'd on EcoSIS. Compiled 2026-09-11 from the current state of
`/Volumes/Enspec/projects/Mill24/`; update as items land or get resolved.

Sizes are approximate (`du -h`), current as of 2026-09-11.

**New 2026-09-17**: `derived/README_mill_test_chemistry_and_spectroscopy.txt`
— a data-documentation README (methods, file-by-file data dictionary,
sample coverage) meant to sit at the root of the deposit zip, modeled on
the ACRES lab's own precedent for a similar data hand-off. Separate from
the internal/external project-history READMEs still pending (see
CLAUDE.md "Next up" item 2) — this one documents the data for downstream
users, not the project's own scope history.

## Deposit layout (decided 2026-09-30): EcoSIS package + Zenodo data record

**Why:** Kate Thompson (EcoSIS), relaying Justin, 2026-09-30: no hard size limit, but ~50 MB is getting close and ~100 MB only if absolutely required; put intermediate processing data elsewhere (GitHub etc.) and link it from the EcoSIS package; multiple related submissions are fine if the description explains how they connect. Henry's decision: **hybrid**. The spectra and their metadata go to EcoSIS regardless; everything else goes to a Zenodo data record with its own DOI, linked from the EcoSIS description (editable after publication, no new DOI). The code repo keeps its own separate Zenodo DOI. The groupings below are a proposal from that decision; confirm each assignment before assembling.

**Package A: EcoSIS (built 2026-10-19: 138 files, 58.5 MB, `deposit/package_A/` on the server)**

Assembled by `Workflow_Calculations/code/BuildDepositPackageA.R`, which rebuilds the folder from scratch, checks it (spectra and sidecar keys match; no non-MILL24 sample IDs in the chemistry files) and writes `MANIFEST_md5.txt`.

| File | Size | Note |
|---|---|---|
| `Mill24_spectra_jumpcorrected.csv` | 50.6M | The deduplicated, jump-corrected spectra from `spectralpredictr/SpectralPredictR_raw_spectra.csv` (2376 scans, key column `spectra`, bare-nm headers 350-2500, 7 decimals). **Replaces `Mill24_RawSpec.csv`**, which has 18 extra rows (the earlier scans of re-scanned sets) and no `spectra` key; the two agree to 1.5e-7 on every kept scan. |
| `spectral_metadata_sidecar.csv` and `spectral_metadata_sidecar_with_qc_flags.csv` | 3.7M | Both ship (the README explains how they relate). |
| `qc/` (45 flag/summary CSVs, `removal_log.csv`) and `qc/qc_review_decisions.csv` | 2.3M | The spectral shape review: all 70 flagged spectra kept (2026-10-19). `qc_review_plots.pdf` (7M) goes to Package B. |
| `predicted_traits/DimensionsDryTraitPredictions.csv` | 1.6M | |
| `field_data/` (`sample_info.csv`, `sample_coordinates.csv`, `cross_project_sample_links.csv`, `raw_coordinates/`) | <0.3M | Coordinates rebuilt 2026-09-30. |
| `particle_size/` (per-sample and summary CSVs, `raw_exports/`, `raw_exports_pilot_Jun13/`) | 2.2M | |
| `chemistry/` (isotope, TPC, ANKOM x4, fat assay, Brookside, leaf area; all cleaned Mill Test rows only) | <0.2M | **Replaces the raw `ChemResults/Brookside.csv`, isotope report and fat-assay workbook** that an earlier version of this table listed: those are lab logs shared with other projects (Brookside.csv holds ABOVE, BIOSCAPE, LNG24 and other rows) and are in neither package. |
| `taxonomy/`, `README.txt`, `MANIFEST_md5.txt` | small | `README.txt` is generated from `derived/README_package_A_ecosis.txt` (server). |

**Package B: Zenodo data record (built 2026-10-19: 2854 files, 1158 MB, `deposit/package_B/` on the server)**

Assembled by `Workflow_Calculations/code/BuildDepositPackageB.R` (rebuilds from scratch, checks file counts and that no non-MILL24 files, `.rds` fits or pilot sheets ship, writes `MANIFEST_md5.txt`). README source: `derived/README_package_B_zenodo.txt` (server).

| Folder | Size | Note |
|---|---|---|
| `DrySpec/` (2418 `.asd`) | 85M | Original uncorrected instrument files, both sessions of re-scanned sets. |
| `LeafScans/` (101 `.jpg`, incl. `PlantID/`) | 70M | JPEGs only (no `Thumbs.db`). |
| `spectral_intermediates/` | 117M | VN and 5 nm resampled spectra. The raw (jump-corrected) spectra are in Package A, so `SpectralPredictR_raw_spectra.csv` is not repeated. |
| `BootstrappedData/` (264 CSVs) | 291M | Exhaustive 36-pair difference output (name is stale; see the to-do rename). |
| `analysis_outputs/` | 586M | `spectral_difference`, `spectral_difference_vn`, `grind_variance`, `treatment_agreement`, `bootstrap`, `maps` (no tile cache), `anova` (summaries, diagnostics, figures **and the two brms fits `*_model.rds`**, ~280M each). |
| `qc_review/qc_review_plots.pdf` | 7.5M | |
| `leaf_area_code/leaf_area_approvedbyTing.ipynb` | 17K | The leaf-area notebook used for the scans (Ting Zheng's code); copied into the repo at `Workflow_Calculations/code/leaf_area/` 2026-10-19. |
| `raw_workbooks/` | 1.7M | ANKOM x2, TPC x4 (two from `chemistry_sample_handling/raw_chem_inputs`), `Mill24_LMA.xlsx`, and the inventory workbook as one CSV per sheet **without the `2022_MillTest` sheet** (an equipment pilot on WisAsp/SHIFT samples). All scanned cell by cell for other projects' sample IDs. |
| Not shipped | | `LMA_Processing_Training/`, `Pictures/`, `derived/data_join/`, `derived/trait_comparisons/`, the raw isotope/fat-assay/Brookside logs. |

**Cross-links to set once both DOIs exist:** EcoSIS description (short DOI list: Zenodo data record, protocol DOIs, later the paper); Zenodo record "related identifiers" (EcoSIS package, code repo); `CITATION.cff` (EcoSIS and data-record DOIs as related); manuscript Data availability (EcoSIS, data record, code repo). Order: EcoSIS package and data record first, then finalize `CITATION.cff`, then tag the code release.

**To do for the split:** restructure this manifest's tables to carry a `Package` column (A/B); split the deposit assembly (zip/build step) into two outputs; write the two READMEs; re-run QC and the coordinate regeneration before building Package A; check the final Package A size against Kate's ~50-100 MB guidance and ask her whether ~60 MB is acceptable or whether to split by drying method.

## Must include — primary measurements, not regenerable from anything else

| File | Size | What it is |
|---|---|---|
| `Mill24_RawSpec.csv` | 58M | ASD spectra, all samples x treatments x replicates. The base of every spectral analysis in the manuscript. **Correction 2026-09-23: despite the filename, these are already jump-corrected, not raw.** `R(1000) == R(1001)` and `R(1800) == R(1801)` exactly in 100% of spectra, and those are the only two exactly-equal adjacent band pairs in all 2151 bands — the signature of a boundary-matching splice correction. Worth stating plainly in the deposit README so nobody treats this file as uncorrected input; anyone who needs genuinely uncorrected spectra has to go back to `DrySpec/*.asd`. |
| `field_data/sample_info.csv` | 10K | Canonical per-sample metadata: Sample_ID, Species_Code, Species, Type, coordinates, fresh/dry mass, water content, chlorophyll (Chl1-5), sampling date. |
| `ChemResults/Brookside.csv` | 54K | Observed wet chemistry (full element panel — N, P, Mg, K, Ca, S, B, Fe, Mn, Cu, Zn, Al, Na) from Brookside Labs — OD + 20-mesh material only. Ground truth for the manuscript's N/Ca RMSE/NRMSE comparison. **Not a Mill Test file in origin** (confirmed 2026-09-17): it's a running multi-project lab submission log — BIOSCAPE/ABOVE/MONGOLIA/LSNP24/LNG24 samples share the same file, some repeated hundreds of times as a bulk project label. New script `Workflow_Calculations/code/BrooksideExtract.R` filters to the 60 `MILL24_*` rows, converts everything to a consistent mg/g (below-detection "< X" values floored to half the detection limit, matching the convention in `WisTraits/Code/hytraits_data_create.R`) → `derived/brookside/brookside_mill_test.csv`, now also joined into the EcoSIS sidecar (see below). Raw file stays in the deposit zip as backup/provenance. |
| `particle_size/data/full/**/*.csv` | 2.1M | LS 13320 particle-size-analyzer exports, one per sample x treatment (64 files covering the real 22-individual study set). **Resolved 2026-09-15**: the raw Beckman Coulter LS instrument-export format (metadata blocks + a `[SampleStats]` section with pre-computed moments) is the correct, intended format — matches what Zach's own script has always read via fixed row-slice indices; `ParticleStat.R` rewritten to parse it by label lookup instead. Two files (`MILL24_0002_SIXT...`, `MILL24_0014_BALL...`) have an internal `GroupID` that doesn't match their filename — confirmed with Zach this is a rename-after-export artifact (he renamed the output file rather than redo the ~10min measurement), not bad data; the script now trusts the filename and logs the mismatch as a `GroupID_mismatch` provenance column rather than excluding the file. All 64 files included; ready for deposit. |
| `particle_size/data/distribution/Jun13/*.csv` | ~40K | Henry's two early single-treatment protocol-testing runs (MILL24_0031 buckthorn/OD-ball, MILL24_0065 white cedar/OD-sixty-mesh) — real data on real study individuals, just incomplete (1 of 3 treatments each) and not part of Zach's 22-individual campaign. **Excluded from the manuscript's particle-size analysis** (`ParticleStat.R` now reads only `data/full/`), **but include in the data release** — good data, just not usable for the treatment comparison. |
| `LeafScans/**/*.jpg` (incl. `PlantID/`) | 62M | Leaf photos by capture date, filenames keyed to Sample_ID. **Decided 2026-09-17 (Henry): include all of them** — cheap relative to everything else in this deposit, preserves provenance for future leaf-area/species-ID work. No documented EcoSIS file-size limit found (their tutorial only lists parseable datasheet extensions: `.xls/.xlsx/.csv/.tsv/.spectra/.zip`); plan to zip this folder into one resource and test the actual upload early rather than assume it's fine. |

Also consider whether the raw `DrySpec/{FreezeDried,OvenDried}/*.asd` files
(102M, 2418 files) should be included alongside `Mill24_RawSpec.csv`, or
whether the merged CSV is sufficient — the `.asd` files are the actual
instrument output `Mill24_RawSpec.csv` was presumably extracted from, so
they carry marginal reproducibility value over the CSV unless someone wants
to re-extract with different software.

## Regenerable via the published code — recommended for convenience, not strictly required

These can all be reproduced from the "must include" files plus the
Zenodo-DOI'd code, so their omission wouldn't break reproducibility — but
including them saves anyone re-running a multi-file pipeline just to get the
same numbers used in the manuscript.

| File | Size | Produced by |
|---|---|---|
| `spectralpredictr/DimensionsDryTraitPredictions.csv` | 1.6M | `Workflow_Calculations/code/SpectralPredictR.R` — predicted N/Ca (+ 17 other traits). Regenerated for real 2026-09-11; this is what the manuscript's RMSE and Bayesian ANOVA analyses actually use. |
| `spectralpredictr/SpectralPredictR_raw_spectra.csv` | 49M | same script — jump-corrected spectra, pre-normalization |
| `spectralpredictr/SpectralPredictR_VN_jumpcorrected_spectra.csv` | 93M | same script — `spectrolab::normalize()` output. **Not actually used downstream within SpectralPredictR.R itself** (see CLAUDE.md FLAG), but `DataJoin.R` reads it. |
| `spectralpredictr/SpectralPredictR_5nmresampled_spectra.csv` | 19M | same script — 5 nm resampled, vector-normalized |
| `BootstrappedData/` | **169M** | `Workflow_Calculations/code/BootstrapCode.R` — per-sample, per-treatment-comparison difference-spectrum output. **Regenerated 2026-09-15** with the final procedure: exhaustive enumeration of all 6x6=36 replicate-pair combinations (not a random bootstrap draw), which is why this is now ~170M instead of the previous ~4.9G — small enough that including it raw in the deposit is a reasonable option now, not just documenting the method. |
| `derived/spectral_difference/` (`table1_spectral_regions_long.csv`, `_wide.csv`, `table1.docx`, `table1.tex`, `particle_size_*.csv`) | <1M | `Table1_SpectralDifferenceRegions.R` — Table 1 as mean ± 95% CI across trees (n = 61 / 30 / 31), with SD and within-tree replicate-pair SD in the long CSV; `ParticleSizeGrowthFormConfound.R` — particle size by growth form and the particle-size / growth-form regression for the milling contrast. |
| `derived/anova/` (`variance_decomposition.csv`, `variance_shares.png`, `effects_and_variance.png`, `ppc_combined.png`, `*_coefficients_MCMCvis.jpeg`) | ~3M | `Workflow_Analysis/AnovaVarianceAndChecks.R` — post-processing of the saved brms fits (`*_model.rds` from `Predicted_Trait_Analysis.R`): variance shares by level with 95% intervals, posterior predictive checks, coefficient plot. |
| `derived/maps/sample_locations.png` | <1M | `Workflow_Visualization/Map_Visualization.R` — supplement map of the 61 sampled trees on a public-domain USGS National Map basemap (tiles cached in `derived/maps/tile_cache/`, not deposited), with scale bar, north arrow and Wisconsin inset. |
| `derived/ecosis/spectral_metadata_sidecar.csv` | ~1M | `Workflow_Calculations/code/EcoSISMetadataSidecar.R` — the per-spectrum EcoSIS metadata sidecar (**2376 rows**, 66 columns). **Fixed 2026-09-23**: was 2418 rows for only 2376 unique spectra. 7 sample x treatment combinations were scanned twice about a month apart (5 Sample_IDs: 0020, 0028, 0034, 0037, 0059 = 42 replicate-level duplicates); `SpectralPredictR.R` keeps the later scan (confirmed with Zach 2026-09-15 as correct for all 7), but this script wasn't applying the same rule, so `spectra` was not a unique key and joining the sidecar to any spectral file produced 42 spurious duplicate rows. Now deduplicated to the later scan per spectrum, with an assertion so it can't regress. **Updated 2026-09-17**: now also carries per-sample x mill-treatment particle-size moments (`particle_size_mean_um`/`_variance`/`_skew`/`_kurtosis`); per-sample x dry-treatment isotope (`d13C`/`d15N`/`carbon_mg_g`/`nitrogen_IRMS_mg_g`), TPC (`phenolics_mg_g`/`_sd`), ANKOM (`hemicellulose_mg_g`/`cellulose_mg_g`/`lignin_recal_mg_g`), and fat-assay (`oil_content_mg_g`/`oil_mass_mg`) values; the full per-sample Brookside elemental panel (`nitrogen_mg_g` through `sodium_mg_g`, 13 elements); per-sample chlorophyll (`chlorophyll_1`-`5`); and per-sample leaf traits (`fresh_mass_g`/`dry_mass_g`/`water_content`/`leaf_area_cm2`/`lma_g_m2`) — see "Not used by this manuscript's analyses" below for where each is cleaned from. **Renamed 2026-09-17 (Henry)**: `carbon_pct`/`nitrogen_pct`/`oil_content_pct` → `carbon_mg_g`/`nitrogen_IRMS_mg_g`/`oil_content_mg_g`, converting all three to mg/g for unit consistency with the rest of the deposit ("IRMS" distinguishes this elemental-analyzer-derived %N from Brookside's separately-assayed `nitrogen_mg_g`). **Added 2026-09-17**: `leaf_area_cm2` (from `field_data/Mill24_LMA.xlsx` via new script `LeafAreaExtract.R`) and `lma_g_m2` (= `dry_mass_g` / `leaf_area_cm2` × 10000), joined at the Sample_ID level like the other tree-level fields. Populated only where each source has coverage (particle size: 22 samples, isotope: 11, TPC: 60, ANKOM: 23, fat assay: 8, Brookside: 60, chlorophyll: 62, fresh/dry mass + water content: 52, leaf area/LMA: 52), NA elsewhere (expected, not a join bug). **Added 2026-09-24**: `Workflow_Calculations/code/TaxonHarmonize.R` appends `scientific_name_wfo`/`scientific_name_authorship`/`family_wfo`/`taxonomic_status_wfo`/`wfo_taxon_id`/`wfo_backbone_version` — all 14 species resolved against the WFO static backbone (v.2026.6), all `Accepted`, all populated (no NAs). Now 2376 rows, **72 columns**. See "Taxon harmonization" below. Still pending the controlled-vocabulary check noted in CLAUDE.md before calling this final. |
| `derived/treatment_agreement/` (CSVs, `F1`–`F3` PNGs, supplement Word tables) | ~2M | `Workflow_Analysis/TreatmentAgreement.R` and `TreatmentAgreementSupplement.R` — per-cell agreement of predictions with the oven-dried 20-mesh reference (bias, proportionality, unsystematic error, CCC, Bland–Altman), break-even reference offsets vs the measured freeze-dried − oven-dried isotope offsets (n = 11 ball-milled trees), predicted vs measured FF − OD nitrogen shift, IRMS vs Brookside nitrogen, and reference-free treatment contrasts. |

## Sample coordinates — rebuilt from raw field records (2026-09-30)

`Workflow_Calculations/code/SampleCoordinates.R` rebuilds the `X_Coord`
(latitude) / `Y_Coord` (longitude) columns of `field_data/sample_info.csv`;
no other column changes. The pre-rebuild file is kept as
`field_data/sample_info_pre_coordinate_rebuild_20260930.csv`.

| Source | Samples | Notes |
|---|---|---|
| Google Maps pins (field crew's shared "Mill24" list; snapshot `field_data/raw_coordinates/google_maps_mill24_list_20260930.txt`) | 41 | Agree with the inventory sheet to ≤ 0.06 m once corrections are applied. Two pin labels name the wrong sample (a second "0014" pin is 0013; the "0039 red cedar" pin is 0040); both are resolved by exact coordinate match. Two pins name no sample and are unused. |
| Inventory sheet (`mill_test_inventory_data_log.xlsx`, "Field Sample Inventory") | 25 | Hand-entered. |

**Corrections** (all dropped digits, each checked against the value it replaces):
- MILL24_0006 longitude −89.932177 → −89.432177 (was ~40 km west of every other sample; the corrected point is ~10 m from this tree's LSNP24 crown center).
- MILL24_0065 latitude 43.098408 → 43.0918408 (matches its Google Maps pin; was ~730 m north).
- MILL24_0048 longitude −89.42121 → −89.42812 (was ~510 m east of everything; the other red pines sampled that day sit at −89.4280 to −89.4281). **No pin, crown or GPS backup exists to confirm this one** — Henry's call, 2026-09-30.

**LSNP24 cross-check.** 9 trees were sampled for both this study and the
Lakeshore Nature Preserve 2024 project on the same day (MILL24_0001/0006/0007/0008/0009/0035/0036/0037/0045
↔ LSNP24_0004/0009/0010/0011/0013/0056/0051/0053/0059; recorded in both projects'
field sheets). Crown centers are used only as a cross-check: 2–12 m from the
coordinates used, except MILL24_0009 (42 m; a black locust clump, so the
collection point and the crown center may mark different stems). The links are
in `derived/field/cross_project_sample_links.csv`. Because each pair is the same
tree, any model trained on both datasets (e.g. WisTraits) must keep a pair in
the same train/test split.

## Taxon harmonization — scientific authority for species names

**New 2026-09-24.** Mill Test has only 14 species (11 tree species plus a
forb and a graminoid), hand-entered in `field_data/sample_info.csv` as
"Common Name (Scientific name)" strings. Small enough to be a real adopter of
the shared harmonization module, not too small to bother: harmonizing against
a named authority and being able to state which backbone version was used is
a checkable claim a deposit can make, and 14 names is small enough that every
result was reviewed by hand.

`Workflow_Calculations/code/TaxonHarmonize.R` runs the shared functions in
[`EnSpec/enspec-qc`](https://github.com/EnSpec/enspec-qc) (`taxon_harmonize.R`,
`wfo_backbone.R`) against the World Flora Online static backbone
(v.2026.6, `/Volumes/Enspec/users/henry/WFO_backbones/`). Runs **before**
`TraitSpectralQC.R` and after `EcoSISMetadataSidecar.R`, whose output it
annotates in place with `scientific_name_wfo`, `scientific_name_authorship`,
`family_wfo`, `taxonomic_status_wfo`, `wfo_taxon_id`, and
`wfo_backbone_version` (2376 rows x 72 columns, up from 66).

**Result: all 14 species matched, all `Accepted`, one name changed.**
`PHDE` was entered as *Phytolacca decandra* (American Pokeweed); WFO resolves
that to its accepted name, *Phytolacca americana*. The entered name and the
WFO name both ship in the deposit, so nothing is silently overwritten. The
other 13 already matched their WFO-accepted name exactly (post-APG family
placements now correctly recorded too — e.g. *Acer* under Sapindaceae, not
the old Aceraceae; *Celtis* under Cannabaceae).

**WFO backbone currency, checked and recorded, not silently trusted.**
`wfo_backbone_check()` is offline-first by design — WFO publishes no
machine-readable version index, and its download page's TLS chain fails to
verify from this machine, so there is no reliable way to script "is this the
newest version." The check always flags this explicitly rather than reporting
a clean bill of health (`derived/taxonomy/wfo_backbone_flags.csv`):
"v.2026.6 may be out of date -- currency was NOT verified against WFO."
That flag ships with the deposit's QC outputs so a downstream user sees the
same caveat.

**A real bug caught and fixed while building this**: the backbone file is
tab-separated but its fields are genuinely double-quoted (e.g.
`"Schoenoxiphium ecklonii var. ecklonii"`). The first read used
`data.table::fread(..., quote = "")`, disabling quote parsing entirely, which
left literal quote marks in every name and made all 14 species look
"changed" by harmonization rather than just the 1 that actually was. Caught
because the wrong result was implausible (14 of 14 changing is not what
"harmonization" should look like for common tree species), not because
anything errored. Fixed by using default quote handling; re-run confirmed
against the raw file with a direct read of the first 5 rows before trusting
the full run.

`derived/taxonomy/taxon_harmonized_mill_test.csv` is the standalone per-species
table (one row per species, everything above plus `name_entered` and
`name_changed`), included in the deposit as its own reference file alongside
the sidecar.

## Data quality checks — flag columns that ship with the deposit

**New 2026-09-22.** First implementation of the project-wide QC standard
(see CLAUDE.md "Data QC standard"): hold this data to DAAC-level QC even
though this deposit isn't NASA-funded or DAAC-bound. The shared,
project-agnostic checks live in a separate repo,
[`EnSpec/enspec-qc`](https://github.com/EnSpec/enspec-qc); everything
data-dependent (grouping variable per trait, bounds, thresholds) lives in
`Workflow_Calculations/code/qc_config_milltest.R`, committed here because
it's part of this deposit's provenance.

**Flag-only, with three exceptions** (Henry, 2026-09-20 / 2026-09-23 / 2026-09-30). Every
check writes a flag table; flags are broadcast to the per-spectrum grain and
carried into the deposit as four columns, split by kind (2026-10-19):
`spectral_flag` / `n_spectral_flags` (scan-level `spectral_*` checks; 29 spectra, 1.2%) and
`trait_flag` / `n_trait_flags` (tree-level trait checks broadcast to every spectrum of the tree;
1296 spectra, 54.5%, because 60 of 66 trees carry at least one of ~40 trait checks). Three checks remove rather than flag, by two *different*
mechanisms — the distinction matters:

- `spectral_band_threshold` (R350 >= 0.9) and `spectral_nir_plateau_floor`
  (mean R1100–1300 < 0.3, added 2026-09-30 to match ACRES) drop the **whole
  spectrum row**, because such a scan isn't a measurement of the sample at
  all (white reference / empty puck read, or probe not on a sample). Both
  remove nothing on the current data (max R350 here is 0.13; min NIR
  plateau is 0.656).
- `trait_physical_bounds` NA's the **offending value only**, keeping the row,
  because the rest of that sample's measurements are fine. Fires on nothing on
  the current data: the one value it caught on 2026-09-23 has since been
  corrected at source (see `ankom_formula_mismatch` below).

Everything removed is written to `removal_log.csv` with its value, the bound
it violated, and the date.

**Physical bounds and literature bounds are separate checks, on purpose**
(Henry, 2026-09-23). Only physically impossible values are removal-eligible;
a literature/TRY range only ever flags, because this lab works with diverse
material and a true value outside TRY's compiled range isn't surprising. The
config enforces this with a guard rather than a comment. The practical
payoff is that a reader can tell the two apart in the outputs.

**`derived/qc/` is cleared at the start of every run** (added 2026-09-24).
Several outputs there are conditional — a flag table only appears when its
check fires — so a file from an earlier run would otherwise survive into a
later one and be read as current. It had already happened: after the ANKOM fix
stopped the physical-bounds and cascade checks from firing, their previous flag
tables were still sitting in the directory, alongside a `spectra_qc_cleaned.csv`
left by the run whose removal bug dropped 18 whole spectra.

**Read flag counts at the sample level, not the row level.** Flags are
broadcast to the per-spectrum grain, so one bad per-sample chemistry value
becomes 18–36 rows. `qc_check_summary.csv` reports both `n_flagged` (rows)
and `n_distinct_units` (samples); the second is the one that means
something. An early version of this section quoted 2772 literature-bound
flags, which was ~96 real sample × trait problems wearing a big number.

| File | Size | Produced by |
|---|---|---|
| `derived/qc/spectral_metadata_sidecar_with_qc_flags.csv` | ~1.8M | `Workflow_Calculations/code/TraitSpectralQC.R` — the sidecar plus `spectral_flag` / `n_spectral_flags` / `trait_flag` / `n_trait_flags`. **Decided 2026-09-23 (Henry): ship this ALONGSIDE the bare sidecar, not instead of it** — and explain the distinction in the deposit README, so a user knows the flagged version is the same data plus advisory columns, not a different or filtered dataset. |
| `derived/qc/qc_check_summary.csv` | 1.5K | same — one row per check, with how many rows it flagged. The short QC report. |
| `derived/qc/qc_quality_flag_by_spectrum.csv` | ~180K | same — per-spectrum flag reasons, joinable to any other spectral file by `spectra`. |
| `derived/qc/*_flags.csv` | ~550K total | same — one table per check, carrying the offending value, the group median/bound it was compared against, and the deviation. 39 tables in the current run. |
| `derived/qc/removal_log.csv` | small | same — what the removal policy actually removed, and why. Empty on the current run (0 spectra removed, 0 trait values NA'd); present regardless so "nothing was removed" is an explicit, checkable statement rather than an absent file. |
| `derived/qc/spectral_jump_correction_status.csv` | small | same — per splice point, the share of spectra with an exact `R(splice) == R(splice+1)` match, i.e. whether the file has already been jump-corrected. Documents *why* the splice-jump check was skipped. |

What runs, and what it found on the 2026-09-24 run (2376 spectra):

- **`trait_physical_bounds`** — **0 samples.** Nothing in the dataset is
  physically impossible. The 2026-09-23 run flagged and dropped one value
  (`MILL24_0035` FF `hemicellulose_mg_g = -157.1`); that turned out to be a
  broken formula in the source workbook, has been corrected, and the sample
  now reports a normal 120.80 mg/g. See `ankom_formula_mismatch` below.
- **`ankom_fiber_cascade`** — **0 values.** ANKOM is a sequential wash
  (NDF → ADF on the NDF residue → ADL on the ADF residue), so a failure at an
  early stage puts everything derived after it in doubt regardless of whether
  the later value looks sane. With no physical-bounds failure there is nothing
  to cascade from. The 2026-09-23 run flagged `MILL24_0035` FF's cellulose and
  lignin as downstream of its then-failing hemicellulose; both are clean now.
- **`ankom_start_weight`** — **0 samples.** The protocol calls for 0.5 g of
  sample per bag, ±0.05 (Hobbie/Frye ANKOM protocol, prep step 4), and that
  weight is the denominator of all three fiber fractions — so a mis-entered or
  mis-packed start weight scales every trait for that sample without making any
  of them look impossible. All 46 Mill Test bags are inside the window
  (0.4647–0.5473 g). Flag-only: a small deviation is a protocol deviation, not
  bad data, and a human should judge which is which. Added 2026-09-24 (Henry).
- **`ankom_formula_mismatch`** — **2 values, and this check is the reason the
  deposit is correct.** The ANKOM workbooks report each fiber fraction as a
  spreadsheet formula over the typed-in weights. Two rows of the FF workbook
  have formulas whose **relative row references had slipped**, so they read a
  neighbouring sample's weight — a dragged fill-handle or inserted row. A full
  audit of the workbook found 7 such formulas across rows 15 and 21. The
  consequence for the deposit:
  - `MILL24_0035` (row 15): `Perc_Remaining_Post_NDF` read `F14` instead of
    `F15`, which is what produced the impossible −157.1 mg/g hemicellulose
    that the 2026-09-23 run caught. **Corrected in the workbook 2026-09-24.**
  - `MILL24_0057` (row 21): five formulas read `D22` (the *next* row's bag
    tare) instead of `D21`. One of them is
    `Percent_Lignin_recalcitrants`, which **is** deposited: it reported
    142.36 mg/g where the weights give **153.95**. This is the point of the
    check — an 11.6 mg/g error in a value that is entirely plausible, sits
    inside every bound, and matches its own batch. No bounds check, group
    comparison, cascade or literature range could see it. Only recomputation
    could.
  - The OD workbook is clean (0 off-row references).

  **`AnkomExtract.R` therefore no longer trusts the workbook's derived
  columns.** It recomputes all three fractions from the raw weights and the
  batch's blank-bag corrections, taken directly from
  `Hobbie_Ankom_Protocol_Frye_edited2025.docx` (the lab's ANKOM protocol,
  authored by Frye, which is where the template's formulas came from), and
  writes the workbook's own reported values beside them to
  `derived/ankom/ankom_reported_vs_recomputed.csv`. `TraitSpectralQC.R` runs
  enspec-qc's `qc_derived_mismatch()` over that pair. **The recomputed values
  are the ones in the deposit**, so a future reference slip cannot change a
  deposited number — it can only raise this flag. Note the check also catches
  a stale cached value, where the formula is right but the file was last saved
  without recalculating: `readxl` returns the cache, not the formula.
- **`phenolics_relative_error`** — **2 samples.** The TPC sheets report a
  mean GAE and an SD over their own duplicate/triplicate measures, so this
  asks whether the assay agreed with itself — something no
  comparison-to-other-samples check can see. Flags CV > 10%: `MILL24_0010`
  OD (12.5%) and `MILL24_0014` OD (11.7%). The rest of the distribution is
  tight (median 0.25%).
- **`ankom_blank_drift`** — **2 step-gains recorded, no batch condemned.**
  Each ANKOM batch carries a blank bag through the same NDF → ADF → ADL wash
  sequence; it should only ever lose weight, and a gain means it leaked and
  took on material, implying it shed sample material too and the whole batch
  is suspect. The FF blank gained **+0.62% at the NDF step** (0.5669 →
  0.5704 g) and the OD blank **+0.11% at ADL**. Both sit below the 1% bad-data
  threshold in common use, so neither batch is condemned — but the FF gain is
  worth knowing about, since 23 samples share that batch. **Propagation is
  batch-wide and verified**: tested at a 0.5% threshold, the FF batch
  breaches and all 23 of its samples get flagged. Whether 1% is the right
  cut — or whether any gain at all should condemn a batch — is a threshold
  decision, and FF turns on the moment it drops below 0.62%.
  Requires `AnkomExtract.R` to have written
  `derived/ankom/ankom_blanks_mill_test.csv` — that script previously
  discarded the BLANK rows, throwing away the only batch-level quality
  information these workbooks carry.
- **`trait_literature_bounds`** — 47 samples, all advisory, and **44 of them
  are phenolics alone**. Bounds are TRY 6.0 (Kattge et al. 2020) for the
  elements and chemistry, Wright et al. 2004 for LMA, Craine et al. 2015 for
  d15N. Three things to know:
  1. **The phenolics upper bound is suspect and needs a call.** It flags
     44/60 samples, values 33.5–108.6 mg/g against a TRY max of 33.23. That
     pattern says wrong bound, not bad data: our TPC is Folin-Ciocalteu
     gallic-acid-equivalents on oak and conifer foliage, where 50–150 mg/g
     GAE is unremarkable, while TRY's "Leaf phenols content" is a small trait
     (n=1225) that may not be assay-comparable. Left in place deliberately
     rather than widened on a guess. Resolve it and literature flags drop to
     3 samples.
  2. **Micronutrient lower bounds were dropped** (B, Fe, Mn, Cu, Zn, Al —
     upper bounds kept). TRY's compiled *minimum* is the wrong statistic for
     a trace-element floor: it's the smallest published value, not a
     plausibility limit, and since `BrooksideExtract.R` floors
     below-detection reads to half the detection limit, those land below
     TRY's minimum *by construction*. That alone was generating 48 spurious
     sample-level flags (Al 33, Cu 10, Fe 5) which said nothing except
     "below detection was below detection." "Unusually low" is a
     distribution question, and the distribution checks already cover it.
  3. Chlorophyll is a CCM-300 leaf-area measurement in mg/m², so its bounds
     come from TRY's per-leaf-area chlorophyll trait filtered to
     `UnitName == "g m-2"` — that trait pools true mass measurements with
     unconvertible SPAD/CCI/FCI index readings, and the unfiltered range is
     meaningless.
- **Magnitude / decimal-shift and distribution flags** — robust, computed
  within the grouping variable each trait actually varies over (species
  for tree-level traits; species x drying treatment for the chemistry;
  growth form x mill treatment for particle size).
- **Leave-one-out bad-replicate check** — runs on the CCM-300 chlorophyll
  reads, the one place in the derived data with genuine within-individual
  instrument replication (5 leaves per tree, stored as 5 columns). Found 4
  suspect reads, all failing low (ratio 0.16-0.49 vs. their own siblings),
  consistent with the probe not seating on the leaf. Only one of the four
  was also below the literature floor — the other three are only visible
  against their own siblings.
- **Spectral checks** — all run against `SpectralPredictR_raw_spectra.csv`
  (jump-corrected, pre-normalization), **not** the 5nm resampled file, which
  is vector-normalized and has no meaningful reflectance scale to threshold
  against.
  - *flat/extreme*: 0. *out-of-range reflectance*: 0.
  - *`spectral_band_threshold`* (R350 >= 0.9, from the SHIFT dried-ground
    DAAC product): 0. Mill Test's max R350 is 0.13, so there are no
    accidental white-reference or empty-puck measurements in this dataset.
  - *`spectral_nir_plateau_floor`* (mean R1100–1300 < 0.3, added 2026-09-30,
    same as ACRES; deliberate probe-off scans read 0.01–0.15): 0. Min here
    is 0.656, 1st percentile 0.729.
  - **The two shape checks below run on SNV spectra (400–2450 nm) since
    2026-09-30**, via enspec-qc's `snv_over_range()`, so they compare
    spectral shape rather than the brightness/scatter differences that
    particle size and packing put between scans (in this dataset SNV cuts
    the grind share of spectral variance from 23% to 5%). The physical
    checks above stay on reflectance.
  - *`spectral_group_outlier`*: **18 (0.9%)** on SNV (was 12 on
    reflectance, 8 in common), by spectral angle within the
    6-replicate set (sample x mill x dry treatment). The reference is the
    **medoid** — the real scan with the smallest summed angle to the others
    — not a synthetic per-wavelength median (Henry, 2026-09-23: compare to
    a spectrum somebody actually measured, so a flag can be gone back to
    and looked at). The reference used is recorded per group as provenance.
    **Threshold is an absolute angle, 1.6° on SNV (was 0.75° on
    reflectance), not a robust z-score.** With
    only 6 scans per group a robust z computes its MAD on 5 angles, so the
    scale estimate is mostly noise and a tightly-agreeing group flags a
    perfectly good sibling for being slightly less tight; that approach
    flagged 60 (2.5%). The observed within-group distribution on SNV
    spectra is median 0.454°, 95th 1.091°, 99th 1.565°, max 2.969°
    (reflectance: 0.212 / 0.518 / 0.703 / 1.277), so 1.6° is a
    conservative cut that matches "outliers should be rare in a controlled
    system". A degree threshold also means the same thing across reruns and
    projects, and is interpretable by a data user. One-sided throughout: a
    small angle is good agreement, never a defect.
  - *`spectral_pca_review`*: 31 flags on SNV (was 28 on reflectance) for
    **manual review only**, never removal — 24 at the within-sample level (a
    replicate far from its own sample centroid) and 7 at the between-sample
    level (a sample far from its species' centroid). The PCA is fit once
    across all spectra and both levels measured in that shared space; top 5
    PCs carry 97.3% of variance (98.8% on reflectance).
    **Reviewed 2026-10-19 (Henry):** every flagged spectrum (18 angle, 24
    within-sample PCA, and all scans of the 7 between-sample sets; 70 spectra
    in all) was inspected on SNV and reflectance plots and **kept**. Reason:
    this study is about naturally observed variation among replicates, so
    removing the tails would bias it; a trait-mapping user may choose to
    reject some. Per-spectrum decisions and rationales:
    `derived/qc_review/qc_review_decisions.csv`; plots:
    `qc_review_plots.pdf` (script `QCReviewPlots.R`). No removals result.
  - *`spectral_splice_jump`*: **skipped, by design.** It only means anything
    on uncorrected spectra, and `qc_detect_jump_corrected()` confirms both
    available CSVs are already corrected (exact `R(splice) == R(splice+1)`
    in 100% of spectra at both 1000 and 1800 nm). Recorded in
    `spectral_jump_correction_status.csv` rather than reported as a vacuous
    all-clear. To actually run it, the uncorrected `DrySpec/*.asd` binaries
    would need re-reading.

Read the headline percentage carefully. A large share of spectra carry at
least one flag, but that is mostly one suspect phenolics bound broadcast
across 44 samples × 18 rows each. At the sample level: **1 physically
impossible value** (the negative hemicellulose), 3 samples with genuinely
low-but-plausible chemistry, 4 suspect chlorophyll replicate reads, 12
spectral shape outliers out of 2376, and 44 samples hitting a phenolics
bound that probably doesn't apply to our assay. Nothing was removed.
(Spectral shape outliers are 18 since the 2026-09-30 switch to SNV; 1620 of
2376 spectra carry at least one flag, was 1624.)
`qc_check_summary.csv` — specifically its `n_distinct_units` column — is the
honest view.

**Still open before the deposit is final**: no confirmed literature range
for `oil_content_mg_g` (TRY's lipid trait returned no usable rows) or
`sodium_mg_g` (no TRY leaf-Na trait) — both have a physical 0-1000 mg/g
ceiling only. Particle-size moments deliberately have no literature
bounds (instrument output, not a trait with an independent plausible
range).

## Collected but not used in the manuscript — Henry wants these deposited anyway

**New 2026-09-16**: `Mill24_RawSpec.csv` / `DrySpec/` / `BootstrappedData/`
carry 66 samples, not the manuscript's 61. 5 are out of the manuscript's
scope, confirmed with Henry:
- `MILL24_0003`, `MILL24_0004` (Type=Forb, American pokeweed) and
  `MILL24_0038`, `MILL24_0039` (Type=Graminoid, yellow foxtail) — from an
  early attempt to add herbaceous growth-form categories to the study
  design that was dropped as too resource-intensive. Real, good spectral
  data on real samples — include in the EcoSIS deposit, excluded from the
  manuscript's spectral-difference analysis (`Table1_SpectralDifferenceRegions.R`
  / `SpectralDifferenceCurves.R` now restrict to Type %in%
  c("Broadleaf","Conifer")).
- `MILL24_0015` (Species_Code=GLTR, honey locust) — a mis-identified
  *Robinia pseudoacacia* replacement collection, not a real 7th broadleaf
  species; already excluded from the Bayesian ANOVA in
  `Predicted_Trait_Analysis.R` (`Species_Code != "GLTR"`), now also
  excluded from the spectral-difference scripts for the same reason. Real
  data (it's a real leaf sample, just not part of the intended 11-species
  design) — include in the deposit.

None of these 5 have Brookside wet-chemistry data, so the RMSE/NRMSE
pipeline was never at risk of including them.

New 2026-09-14: Zach provided
`field_data/mill_test_inventory_data_log.xlsx`, a 9-sheet measurement log.
Two of those sheets are raw trait data collected per individual tree (not
split per treatment) just to characterize the sample set overall — not
read by any script in this repo or used in any manuscript analysis, but
Henry wants them included in the EcoSIS release regardless.

| Sheet | Size | What it is |
|---|---|---|
| `LMA` | 53 rows | Fresh/dry mass per Sample_ID, raw (not the treatment-split LMA the manuscript would need). |
| `Chlorophyll` | 62 rows | Chl1-5 / CFR1-5 per Sample_ID, raw. |

**Confirmed 2026-09-15 (Henry)**: these sheets are the same underlying
measurements aggregated into `field_data/sample_info.csv`'s `Water_Content`
and `Chl1-5` columns (see `archive/README.md` under `Workflow_Traits/` —
`Mill_Test_Analysis.R`, which produced `sample_info.csv`, was built from
`LMA_data.csv` and `Chlorophyll.csv` among other inputs) — the inventory
version just carries some extra metadata beyond what made it into the
aggregate. `sample_info.csv`'s provenance is now fully traceable.

**Resolved 2026-09-17 (Henry)**: rather than staging these two raw sheets
as their own deposit files, `EcoSISMetadataSidecar.R` now pulls
`Fresh_mass`/`Dry_mass`/`Water_Content`/`Chl1-5` straight from
`sample_info.csv` (which already has them) and joins them into the sidecar
at the Sample_ID level, broadcast across every treatment/replicate row for
that sample — these are tree-level measurements, not treatment-level, same
as species/coordinates. Covers 62 samples for chlorophyll, 52 for
fresh/dry mass and water content (matches `sample_info.csv`'s own
coverage gaps, not a new problem). The raw `LMA`/`Chlorophyll` sheets
(with their extra CFR1-5 and provenance-date/person columns not carried
into `sample_info.csv`) are still worth including in the deposit zip
alongside the rest of `mill_test_inventory_data_log.xlsx` for full
provenance, but are no longer the only way to get these values.

The same workbook's `Sample Inventory` sheet (397 rows: Sampling_Date,
Sample_ID, Type, Grinding Type, Grind_Date, Grind_Person, Spectra_Date,
Spectra_Person) is the measurement log needed to validate the
duplicate-spectral-scan handling in `SpectralPredictR.R` — see CLAUDE.md's
2026-09-14 status entry. Not itself a deposit candidate (it's a lab
logbook, not a trait measurement), but flagged here since it arrived in
the same file.

## Needs resolution before deposit — currently placeholder or unverified

| File | Size | Issue |
|---|---|---|
| `spectralpredictr/DryTraits_NM.csv` | 3.1M | **Still Henry's placeholder** — not produced by any script currently in the repo. Used by `Predicted_Trait_Analysis.R` only for the Sample_ID -> Type/Species/Species_Code lookup (not for trait values). Needs either a real regeneration path or confirmation that its current content is actually fine to publish as-is. NM = "New Mill", the rotary mill equipment actually used for the study (confirmed 2026-09-11). |

## Not used by this manuscript's analyses, but included in the deposit anyway

None of this is read by any script that produces this manuscript's own four
analyses (spectral difference, N/Ca trait prediction, Bayesian ANOVA,
particle size) — included anyway because it's all associated data from the
same sample collection, and this manuscript + `chemistry-sample-handling`
(isotope) can cite one shared EcoSIS release instead of splitting it across
two deposits.

**Revised 2026-09-17 (Henry): clean and join these into the per-spectrum
EcoSIS sidecar directly, not just ship the raw xlsx files** — a raw workbook
is much less useful to a downstream user than the same values already
joined onto the spectra by Sample_ID x drying treatment. Raw files are still
included in the deposit zip as backup/full provenance, but the sidecar
(`derived/ecosis/spectral_metadata_sidecar.csv`) is now the primary way this
data is actually usable. Turned out three of the four sources needed real
cleaning work, not just a copy:

| Source | Raw file(s) | Issue found | Clean script → output |
|---|---|---|---|
| Isotope (δ13C/δ15N, %C/%N) | `ChemResults/Report - 13C15N - BIOCORE_05.26.26.xlsx` (67K) | **Not a Mill Test file in origin** — its own metadata says `Study = BIOCORE`; only 22 of its rows (11 samples x FF/OD) are Mill Test, mixed with ~60 unrelated Biocore Tree samples in the same run. Per `chemistry-sample-handling/CLAUDE.md`, this comparison is itself a small side-check for that project, not manuscript-scope for either project. | `Workflow_Calculations/code/IsotopeExtract.R` → `derived/isotope/isotope_mill_test.csv` (22 rows). Ran clean. |
| TPC (phenolics) | `ChemResults/Mill Test_{FF,OD}_TPC.xlsx` (591K + 593K) | Broadleaf-heavy batch only (30 samples) — a second, needle-leaved-conifer batch (samples 035-066) was run later and lives **only** in `chemistry_sample_handling/raw_chem_inputs/` (`08042026-FF BALL_GAE.xlsx` / `07302026 - OD BALL_GAE.xlsx`), never copied into Mill24 at all. Both batches also need Code/Plant.ID triplicate-QC parsing (calibration standards + QC re-runs share the same Code prefix as real samples). | `Workflow_Calculations/code/TPCExtract.R` → `derived/tpc/tpc_mill_test.csv` (120 rows, 60 samples: 30 broadleaf + 30 conifer). Parsing logic matches `chemistry-sample-handling/code/chemistry_comparison_results.R`, which reads the same Mill24 files for a different analysis. Ran clean, no ID collisions between the two batches. |
| ANKOM (fiber assay) | `ChemResults/Ankom_Primary_Template_Zach_Mill{FF,OD}.xlsx` (15K + 13K) | No other project mixed in. **But the FF workbook's arithmetic was broken** (found 2026-09-24): 7 formulas across rows 15 and 21 had relative row references that had slipped, so they read a neighbouring sample's weight. Corrupted `MILL24_0035` hemicellulose (caught as impossible) and `MILL24_0057` lignin (11.6 mg/g too low, and entirely plausible-looking). OD is clean. | `Workflow_Calculations/code/AnkomExtract.R` → `derived/ankom/ankom_mill_test.csv` (46 rows, 23 samples) + `ankom_blanks_mill_test.csv` (batch QC blanks) + `ankom_sample_weights_mill_test.csv` (the raw weights every fraction is derived from — assay provenance, and the input to the start-weight check) + `ankom_reported_vs_recomputed.csv` (the math check's input). **Recomputes all three fractions from the raw weights per the lab protocol rather than reading the workbook's formula columns**, so a reference slip can no longer change a deposited value. Ran clean. |
| Fat/oil content | `/Volumes/Enspec/projects/fat_assay_development/raw_data/Defat_test_samples.xlsx` | Same mixed-project problem as isotope: 8 Mill Test samples (MILL24_0001/0007/0011/0017/0036/0040/0049/0060, FF+OD) mixed with 8 unrelated SHIFT-project rows in the same sheets, plus an entirely SHIFT "Samples" sheet. | `Workflow_Calculations/code/FatAssayExtract.R` → `derived/fat_assay/fat_assay_mill_test.csv` (16 rows, 8 samples). Ran clean. |

All four raw source files above are still included in the deposit zip
(reproducibility/provenance), but are no longer the primary form this data
takes — see `derived/ecosis/spectral_metadata_sidecar.csv`'s row in the
table above for the joined version. The isotope/TPC/ANKOM/fat-assay values
are per-sample x drying-treatment, and each was run on one mill
treatment's powder (2026-10-19): isotope, TPC and fat assay on ball-milled
(BALL) powder, ANKOM on 20-mesh (TWEN). The sidecar attaches each value to
that mill treatment's rows only and leaves the other mill rows NA. The fat
assay basis was confirmed by two people (2026-10-19). Brookside
(OD, 20-mesh) is the exception: joined at the Sample_ID level as the common
reference. Coverage is partial for all four
(isotope 11 samples, TPC 60, ANKOM 23, fat assay 8) — NA elsewhere.

Henry: "we did a lot of this already in a different project" — confirmed:
`chemistry-sample-handling/code/chemistry_comparison_results.R` already had
working, tested TPC/ANKOM parsing logic, reused here rather than re-derived
from scratch. Building the equivalent clean/combined output *within* the
chemistry-sample-handling repo itself (its own CLAUDE.md item 1b's
"shared omnibus EcoSIS deposit" idea) is explicitly deferred to a later
session — today's focus is Mill Test's own resubmission deadline.

**Not needed at all** (confirmed 2026-09-11, not just "out of scope" — actively
excluded): `spectralpredictr/DryTraits_OM.csv` and the
`5nmResampleSpectra_{OM,OD_OM}.csv` splits. OM = "Old Mill", one side of an
early rotary-mill-equipment comparison (Wiley vs. Eberbach) that was piloted
in the pipeline but dropped from the manuscript entirely — confirmed the OM
and NM trait files cover the identical 66 samples/treatments, just from the
two different mill machines. `Spectral_Visualization.R`, the only script
that read the OM split, has been archived
(`Workflow_Visualization/archive/`). `5nmResampleSpectra_{NM,OD_NM}.csv`
would only be needed if that script is ever revived against the real (NM)
mill instead.

## Not applicable / regenerable in-repo, no staging needed

Everything under `derived/` (all script outputs — RMSE tables, ANOVA model
`.rds` files, figures) — these are outputs of the published code applied to
the files above, not source data. `ChemResults/DryTraits_NEONModel.csv` is
superseded (see the FIXME history in `ChemistryAnalysis.R` /
`Predicted_Trait_Analysis.R` — it's missing columns the manuscript's
analyses need and isn't read by anything current).
