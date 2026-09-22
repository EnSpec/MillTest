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

## Must include — primary measurements, not regenerable from anything else

| File | Size | What it is |
|---|---|---|
| `Mill24_RawSpec.csv` | 58M | Raw ASD spectra, all samples x treatments x replicates. The base of every spectral analysis in the manuscript. |
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
| `derived/ecosis/spectral_metadata_sidecar.csv` | ~1M | `Workflow_Calculations/code/EcoSISMetadataSidecar.R` — the per-spectrum EcoSIS metadata sidecar (2418 rows, 66 columns). **Updated 2026-09-17**: now also carries per-sample x mill-treatment particle-size moments (`particle_size_mean_um`/`_variance`/`_skew`/`_kurtosis`); per-sample x dry-treatment isotope (`d13C`/`d15N`/`carbon_mg_g`/`nitrogen_IRMS_mg_g`), TPC (`phenolics_mg_g`/`_sd`), ANKOM (`hemicellulose_mg_g`/`cellulose_mg_g`/`lignin_recal_mg_g`), and fat-assay (`oil_content_mg_g`/`oil_mass_mg`) values; the full per-sample Brookside elemental panel (`nitrogen_mg_g` through `sodium_mg_g`, 13 elements); per-sample chlorophyll (`chlorophyll_1`-`5`); and per-sample leaf traits (`fresh_mass_g`/`dry_mass_g`/`water_content`/`leaf_area_cm2`/`lma_g_m2`) — see "Not used by this manuscript's analyses" below for where each is cleaned from. **Renamed 2026-09-17 (Henry)**: `carbon_pct`/`nitrogen_pct`/`oil_content_pct` → `carbon_mg_g`/`nitrogen_IRMS_mg_g`/`oil_content_mg_g`, converting all three to mg/g for unit consistency with the rest of the deposit ("IRMS" distinguishes this elemental-analyzer-derived %N from Brookside's separately-assayed `nitrogen_mg_g`). **Added 2026-09-17**: `leaf_area_cm2` (from `field_data/Mill24_LMA.xlsx` via new script `LeafAreaExtract.R`) and `lma_g_m2` (= `dry_mass_g` / `leaf_area_cm2` × 10000), joined at the Sample_ID level like the other tree-level fields. Populated only where each source has coverage (particle size: 22 samples, isotope: 11, TPC: 60, ANKOM: 23, fat assay: 8, Brookside: 60, chlorophyll: 62, fresh/dry mass + water content: 52, leaf area/LMA: 52), NA elsewhere (expected, not a join bug). Still pending the controlled-vocabulary check noted in CLAUDE.md before calling this final. |

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
| ANKOM (fiber assay) | `ChemResults/Ankom_Primary_Template_Zach_Mill{FF,OD}.xlsx` (13K + 13K) | Clean already — verified no other project mixed in, just needed percent→mg/g conversion and the BLANK QC row dropped. | `Workflow_Calculations/code/AnkomExtract.R` → `derived/ankom/ankom_mill_test.csv` (46 rows, 23 samples). Ran clean. |
| Fat/oil content | `/Volumes/Enspec/projects/fat_assay_development/raw_data/Defat_test_samples.xlsx` | Same mixed-project problem as isotope: 8 Mill Test samples (MILL24_0001/0007/0011/0017/0036/0040/0049/0060, FF+OD) mixed with 8 unrelated SHIFT-project rows in the same sheets, plus an entirely SHIFT "Samples" sheet. | `Workflow_Calculations/code/FatAssayExtract.R` → `derived/fat_assay/fat_assay_mill_test.csv` (16 rows, 8 samples). Ran clean. |

All four raw source files above are still included in the deposit zip
(reproducibility/provenance), but are no longer the primary form this data
takes — see `derived/ecosis/spectral_metadata_sidecar.csv`'s row in the
table above for the joined version. The isotope/TPC/ANKOM/fat-assay values
are per-sample x drying-treatment, not per-replicate or per-mill-treatment
(none of these assays were re-run per mill treatment), so every mill
treatment x replicate row within a sample x dry treatment shares the same
joined value — expected, not a join bug. Coverage is partial for all four
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
