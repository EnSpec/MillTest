# Mill Test 2024

Effects of foliar **sample handling** (freeze-dried vs. oven-dried) and
**milling method** (ball mill, fine rotary mesh, coarse rotary mesh) on:

1. reflectance spectra (350–2500 nm) of ground foliar material,
2. spectrally predicted foliar traits (nitrogen, calcium) and their error
   relative to wet-chemistry validation, and
3. milled particle-size distributions.

Foliar samples were collected from 11 species (6 deciduous broadleaf including
one understory shrub, 5 evergreen conifer) in the Lakeshore Nature Preserve,
University of Wisconsin–Madison, late July–August 2024. Each individual was
split into six drying × milling treatments, measured with an ASD FieldSpec 3
and plant probe, and a subset was sent for elemental analysis and particle-size
analysis. See the manuscript methods for full detail.

- **Data deposit** (traits + spectra): EcoSIS — DOI TBD
- **Code DOI**: Zenodo — TBD

## Treatments and sample naming

| Factor | Levels (code in `sample_name`) |
|---|---|
| Drying | freeze-dried / flash-frozen (`FF`), oven-dried 65 °C (`OD`) |
| Milling | ball mill (`BALL`), fine rotary — 40 mesh conifer / 60 mesh broadleaf (`SIXT`), coarse rotary — 20 mesh (`TWEN`) |

Spectral file names follow `MILL24_<id>_<drying>_<milling>_<replicate>`, e.g.
`MILL24_0001_OD_TWEN_00003`. `Sample_ID` is the first 11 characters
(`MILL24_0001`); six spectral replicates per treatment (3 wells × 2 rotations).
Trait-prediction inputs from SpectralPredictR carry the same information in a
`sampledata_head` column.

> **Known fragility:** the scripts extract drying/milling codes with fixed
> `substring()` offsets into `sample_name` rather than parsing delimited
> fields. Being addressed in the cleanup pass (see *Repository status*).

## Data

Nothing in this section is stored in the repo — it all lives on the EnSpec lab
server:

```
/Volumes/Enspec/projects/Mill24/
  Mill24_RawSpec.csv     raw ASD spectra, one row per spectral replicate
  DrySpec/               raw per-session .asd files (FreezeDried/, OvenDried/)
  ChemResults/           Brookside.csv (observed elemental, OD + 20-mesh only),
                         DryTraits_NEONModel.csv (predicted traits),
                         TPC / Ankom / 13C15N workbooks
  BootstrappedData/      output of BootstrapCode.R (one CSV per sample/pair)
  LeafScans/, LMA_Processing_Training/
  spectralpredictr/      SpectralPredictR export CSVs (see below)
  field_data/            sample_info.csv and its field-data inputs
  particle_size/         LS 13 320 particle-size analyzer exports
  derived/               all script outputs
```

Existing sub-directory names are kept as-is (`ChemResults/` is read directly by
other projects on the server); `spectralpredictr/`, `field_data/`,
`particle_size/`, and `derived/` were added.

Each script sets its own data location near the top:

```r
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
```

and builds paths with `file.path(data_root, ...)`. Point at a different copy of
the data by setting the `MILL24_DATA_ROOT` environment variable before starting
R. Script outputs are written under `<data_root>/derived/`, never into the repo.

**Files not yet staged on the server** (needed to run the full pipeline — see
`CLAUDE.md` for the itemised list): the SpectralPredictR export CSVs, the
canonical `sample_info.csv` and its field-data inputs, and the particle-size
analyzer exports.

## External processing step — SpectralPredictR

Raw `.asd` aggregation, jump correction (detector overlaps at 1001 nm and
1801 nm), unit vector normalization, resampling to 5 nm, and PLSR trait
prediction using the coefficients of Wang et al. (2020b) are performed by
**SpectralPredictR** (github.com/krkovach/SpectralPredictR), not by this repo.
Its outputs (`SpectralPredictR_*_spectra.csv`, `5nmResampleSpectra_*.csv`,
`DimensionsDryTraitPredictions.csv`, `DryTraits_{NM,OM}.csv`) are **inputs**
here and are archived with the dataset deposit. The exact version of that code
used for this study is kept on the server under
`spectralpredictr/` for provenance.

## Repository layout and run order

Code is grouped by analysis stage. Within each folder scripts are listed in the
order they run.

### `Workflow_Calculations/` — spectral difference between treatments
- `code/BootstrapCode.R` — the manuscript method: for each treatment pair
  within a sample, draw one random spectral replicate per treatment, take the
  difference across all wavelengths, iterate to build a bootstrap distribution;
  writes per-pair CSVs to `BootstrappedData/`. **The downstream script that
  turns `BootstrappedData/` into the figure and cross-treatment summary table
  is not yet in this repo** (see *Repository status*).
- `code/BiasCalc.R`, `code/BiasFunctionExecution.R`,
  `code/BiasSummaryCalculation.R` — the **original** difference-spectrum
  approach, which *averaged* the six replicates before differencing. Superseded
  by the bootstrap above and slated for `archive/` once confirmed. `BiasCalc.R`
  produced `data/AllSamplesBIAS.csv` / `AllSamplesBIASNormalized.csv`.

### `Workflow_Visualization/`
- `DataJoin.R` — joins the SpectralPredictR exports to `sample_info.csv`,
  writing the `*Edit.csv` tables the trait/figure scripts read.
- `BiasFigures.R` — difference-spectrum figure (mill-pair × growth form
  facets); built on the superseded `BiasCalc.R` output, so it moves to
  `archive/` with that pipeline unless it is re-pointed at the bootstrap data.
- `Spectral_Visualization.R` — treatment spectra by species.
- `Map_Visualization.R` — sample collection-location map.

### `Workflow_Traits/`
Nothing maintained here — everything moved to `archive/` (superseded PCA and
exploratory scripts, not run for the manuscript; see `archive/README.md`).

### `Workflow_Analysis/`
- `ChemistryAnalysis.R` — observed vs. predicted N and Ca by treatment
  (linear models, RMSE / NRMSE) and a variance-partitioning analysis.
- `Predicted_Trait_Analysis.R` — Bayesian ANOVA (`brms`) of predicted N and Ca
  as a function of milling × drying, with nested species / species:measurement
  random intercepts; 4 chains × 20,000 iterations (5,000 warmup),
  Student-t(3, 0, 2.5) priors on the treatment coefficients. Writes model
  objects, posterior summaries, trace and coefficient plots to `derived/anova/`.
- `ParticleStat.R` — particle-size distribution moments (mean, variance, skew,
  kurtosis) averaged by growth form × milling treatment.
- `archive/` — chlorophyll/lignin/starch model fragments removed from
  `Predicted_Trait_Analysis.R` (non-functional; not manuscript scope).

## Environment

- **R 4.4.1** (recorded in `renv.lock`; 4.4.x expected to work).
- Dependencies are locked with [renv](https://rstudio.github.io/renv/). Run
  `renv::restore()` from the repo root — or just open R there, `.Rprofile`
  auto-activates renv — to install the recorded package versions into a
  project-local library. `brms` pulls in a Stan toolchain and needs a working
  C++ compiler.
- `Map_Visualization.R` additionally needs `sf` + `mapview` (a system GDAL
  stack); these are intentionally excluded from `renv.lock` pending a rewrite
  of that figure with `ggplot2`.

## Repository status

This repo was migrated out of a private student repo and is being cleaned up
for public release alongside manuscript submission: hard-coded machine paths
replaced with a `data_root` convention, superseded scripts moved to `archive/`,
and a script-by-script correctness review is in progress. Open items and review
findings are tracked in `CLAUDE.md` (not published).
