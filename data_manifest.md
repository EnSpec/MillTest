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
| `particle_size/data/**/*.csv` | 2.1M | Raw LS 13320 particle-size-analyzer exports, one per sample x treatment (64 files, volume-% by diameter bin). Staged by Zach 2026-09-11. One file (`MILL24_0005_SIXT_10_01.$ls.csv`) has a known export artifact (Sample column increments instead of staying fixed) — `ParticleStat.R` skips it; regenerate that one file before deposit if possible. |

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
| `BootstrappedData/` | **4.9G** | `Workflow_Calculations/code/BootstrapCode.R` — per-sample bootstrap difference-spectrum draws. Large enough that including it raw is questionable; probably better to document the method + point to the code, unless EcoSIS's size limits are a non-issue. **Also currently stale** — predates the 2026-09-08 iteration-count/algorithm changes still awaiting Zach's confirmation; don't deposit until that's settled. |

## Needs resolution before deposit — currently placeholder or unverified

| File | Size | Issue |
|---|---|---|
| `spectralpredictr/DryTraits_NM.csv` | 3.1M | **Still Henry's placeholder** — not produced by any script currently in the repo. Used by `Predicted_Trait_Analysis.R` only for the Sample_ID -> Type/Species/Species_Code lookup (not for trait values). Needs either a real regeneration path or confirmation that its current content is actually fine to publish as-is. |
| `spectralpredictr/DryTraits_OM.csv` | 3.3M | Same status as `DryTraits_NM.csv`; not read by anything in the current repo — confirm whether it's needed for the deposit at all. |
| `spectralpredictr/5nmResampleSpectra_{NM,OM,OD_NM,OD_OM}.csv` | — | Per-treatment SpectralPredictR splits, still not staged. Needed by `Spectral_Visualization.R`; NM/OM/OD_NM/OD_OM meaning still unconfirmed (guess: NEON Model / Other Model — unconfirmed). |

## Out of scope for this manuscript — confirm before bundling

Collected, but not read by any script in this repo, and not part of the four
analyses the manuscript describes (spectral difference, N/Ca trait
prediction, Bayesian ANOVA, particle size):

- `ChemResults/Report - 13C15N - BIOCORE_05.26.26.xlsx` (67K) — isotope ratios
- `ChemResults/Mill Test_{FF,OD}_TPC.xlsx` (591K + 593K) — TPC assay
- `ChemResults/Ankom_Primary_Template_Zach_Mill{FF,OD}.xlsx` (13K + 13K) — fiber assay

These may belong to a different project's deposit (the isotope file in
particular is read directly by `chemistry-sample-handling`'s
`isotope_comparison_results.R` on the server — see CLAUDE.md's server-layout
notes). Confirm with Henry/Zach whether any of these should ride along with
this deposit or stay with that project's own release.

## Not applicable / regenerable in-repo, no staging needed

Everything under `derived/` (all script outputs — RMSE tables, ANOVA model
`.rds` files, figures) — these are outputs of the published code applied to
the files above, not source data. `ChemResults/DryTraits_NEONModel.csv` is
superseded (see the FIXME history in `ChemistryAnalysis.R` /
`Predicted_Trait_Analysis.R` — it's missing columns the manuscript's
analyses need and isn't read by anything current).
