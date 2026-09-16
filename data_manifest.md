# Data manifest — Mill Test 2024 EcoSIS deposit

What should accompany this code repo's Zenodo DOI as the trait + spectra
dataset DOI'd on EcoSIS. Compiled 2026-09-11 from the current state of
`/Volumes/Enspec/projects/Mill24/`; update as items land or get resolved.

Sizes are approximate (`du -h`), current as of 2026-09-11.

## Must include — primary measurements, not regenerable from anything else

| File | Size | What it is |
|---|---|---|
| `Mill24_RawSpec.csv` | 58M | Raw ASD spectra, all samples x treatments x replicates. The base of every spectral analysis in the manuscript. |
| `field_data/sample_info.csv` | 10K | Canonical per-sample metadata: Sample_ID, Species_Code, Species, Type, coordinates, fresh/dry mass, water content, chlorophyll (Chl1-5), sampling date. |
| `ChemResults/Brookside.csv` | 54K | Observed wet chemistry (N, Ca, K, P) from Brookside Labs — OD + 20-mesh material only. Ground truth for the RMSE/NRMSE comparison. |
| `particle_size/data/full/**/*.csv` | 2.1M | LS 13320 particle-size-analyzer exports, one per sample x treatment (64 files covering the real 22-individual study set). **Resolved 2026-09-15**: the raw Beckman Coulter LS instrument-export format (metadata blocks + a `[SampleStats]` section with pre-computed moments) is the correct, intended format — matches what Zach's own script has always read via fixed row-slice indices; `ParticleStat.R` rewritten to parse it by label lookup instead. Two files (`MILL24_0002_SIXT...`, `MILL24_0014_BALL...`) have an internal `GroupID` that doesn't match their filename — confirmed with Zach this is a rename-after-export artifact (he renamed the output file rather than redo the ~10min measurement), not bad data; the script now trusts the filename and logs the mismatch as a `GroupID_mismatch` provenance column rather than excluding the file. All 64 files included; ready for deposit. |
| `particle_size/data/distribution/Jun13/*.csv` | ~40K | Henry's two early single-treatment protocol-testing runs (MILL24_0031 buckthorn/OD-ball, MILL24_0065 white cedar/OD-sixty-mesh) — real data on real study individuals, just incomplete (1 of 3 treatments each) and not part of Zach's 22-individual campaign. **Excluded from the manuscript's particle-size analysis** (`ParticleStat.R` now reads only `data/full/`), **but include in the data release** — good data, just not usable for the treatment comparison. |

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
aggregate. `sample_info.csv`'s provenance is now fully traceable. Still to
do: actually stage these two sheets as their own deposit files (not just
reference them here) once the EcoSIS metadata alignment pass (see
CLAUDE.md) is further along.

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

**Decided 2026-09-15 (Henry)**: include all of this alongside the trait +
spectra data, even though none of it is read by any script in this repo or
part of the four analyses the manuscript describes (spectral difference,
N/Ca trait prediction, Bayesian ANOVA, particle size). Rationale: it's all
associated data from the same sample collection, and this manuscript and
the `chemistry-sample-handling` manuscript (which *does* use the isotope
file directly, via `isotope_comparison_results.R` on the server) can both
just cite the same shared EcoSIS release rather than splitting it across
two deposits.

- `ChemResults/Report - 13C15N - BIOCORE_05.26.26.xlsx` (67K) — isotope ratios
- `ChemResults/Mill Test_{FF,OD}_TPC.xlsx` (591K + 593K) — TPC assay
- `ChemResults/Ankom_Primary_Template_Zach_Mill{FF,OD}.xlsx` (13K + 13K) — fiber assay

Henry: "we did a lot of this already in a different project" — there may be
an existing template/precedent for structuring a combined multi-assay
chemistry release worth reusing rather than figuring this out from scratch.
Not yet identified which project/files that refers to.

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
