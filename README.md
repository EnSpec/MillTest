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
and plant probe, and a subset was sent for elemental, isotope, fiber,
phenolic, and fat-content analysis, and particle-size analysis. See the
manuscript methods for full detail.

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

> The drying/milling codes are currently extracted with fixed-offset
> `substring()` calls into `sample_name` rather than parsing delimited
> fields. Works for every name in this dataset; noted as a fragility for
> future naming-convention changes in `REPOSITORY_NOTES.md`.

## Reproducibility note

This repository's code is public and documents the full method, but the raw
instrument output, field metadata, and shared multi-project lab files it
reads are not in the repo — they live on the EnSpec lab's internal server
and are staged into the public trait+spectra deposit above (EcoSIS) rather
than committed here directly. An external reader can follow and evaluate the
method in full from the code; literally re-running it end to end needs
either that EcoSIS deposit or lab server access.

Every script resolves its data location the same way:

```r
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
```

Point at a different copy of the data by setting `MILL24_DATA_ROOT` before
starting R. Outputs are written under `<data_root>/derived/`, never into the
repo. The full internal server layout, and what each `derived/` subfolder
holds, is documented in `REPOSITORY_NOTES.md` rather than here.

## Run order

Two tracks share a common processing stage. Numbers are continuous; where a
step's inputs come from an earlier step, that's noted explicitly.

**1. Spectral and chemistry processing** (shared by both tracks below)

1. `Workflow_Calculations/code/SpectralPredictR.R` — vendored fork of
   [krkovach/SpectralPredictR](https://github.com/krkovach/SpectralPredictR).
   Aggregates raw `.asd` files, applies an additive jump correction at the
   1000/1800 nm detector splices, resamples to 5 nm, and applies PLSR trait
   coefficients (Wang et al. 2020). Writes `spectralpredictr/*.csv` (raw
   spectra, jump-corrected spectra, 5 nm-resampled spectra, predicted
   traits). ~15 minutes against the full `DrySpec/` archive (2418 `.asd`
   files).
2. `Workflow_Calculations/code/SpectralMeasurementMetadata.R` — per-spectrum
   provenance (measurement date/time, operator, instrument serial number)
   read directly from each `.asd` file's binary header, joined to grind
   date/operator from the field inventory spreadsheet. Independent of step 1.
3. `Workflow_Analysis/ParticleStat.R` — particle-size distribution moments
   (mean/variance/skew/kurtosis) computed from the raw LS 13320
   laser-diffraction exports. Independent of steps 1–2.
4. Chemistry extraction — six independent scripts, each pulling this
   study's rows out of a shared/multi-project lab workbook and converting to
   consistent mg/g units (see each script's header comment for the
   project-mixing issue it resolves):
   `Workflow_Calculations/code/AnkomExtract.R` (fiber assay: hemicellulose/
   cellulose/lignin), `IsotopeExtract.R`, `TPCExtract.R` (total phenolic
   content), `FatAssayExtract.R`, `BrooksideExtract.R` (full elemental
   panel), `LeafAreaExtract.R`.

**2. EcoSIS deposit build** (needs steps 2–4 above)

5. `Workflow_Calculations/code/EcoSISMetadataSidecar.R` — joins the
   measurement metadata (step 2), particle size (step 3), and all six
   chemistry extracts (step 4), plus `field_data/sample_info.csv`, into one
   per-spectrum table: `derived/ecosis/spectral_metadata_sidecar.csv`.
6. `Workflow_Calculations/code/TaxonHarmonize.R` — resolves species names
   against the World Flora Online taxonomic backbone and appends the result
   onto that same sidecar file in place. Runs after step 5 and before step
   7 — taxon is a QC grouping variable.
7. `Workflow_Calculations/code/TraitSpectralQC.R` (project config:
   `Workflow_Calculations/code/qc_config_milltest.R`) — applies the shared
   trait/spectral QC checks from
   [EnSpec/enspec-qc](https://github.com/EnSpec/enspec-qc). Reads the
   harmonized sidecar (step 6), the raw spectra (step 1), and the ANKOM
   raw-weight comparison (step 4's `AnkomExtract.R` output). Writes
   `spectral_metadata_sidecar_with_qc_flags.csv` and one CSV per check under
   `derived/qc/`.

**3. Manuscript analysis** (needs step 1; independent of the deposit build)

8. `Workflow_Visualization/DataJoin.R` — joins the trait predictions
   (step 1) to `sample_info.csv`.
9. `Workflow_Analysis/ChemistryAnalysis.R` — observed (Brookside wet
   chemistry) vs. predicted nitrogen/calcium by treatment: per-treatment
   linear fits, RMSE/NRMSE, and a variance-partitioning analysis.
10. `Workflow_Analysis/Predicted_Trait_Analysis.R` — Bayesian ANOVA (`brms`)
    of predicted N and Ca as a function of milling × drying, with nested
    species / individual / measurement-replicate random intercepts; 4 chains
    × 20,000 iterations (5,000 warmup), Student-t(3, 0, 2.5) priors on the
    treatment coefficients. Reads step 1's trait predictions and step 8's
    join output. Writes model objects, posterior summaries, and trace/
    coefficient plots to `derived/anova/`.
11. `Workflow_Calculations/code/BootstrapCode.R` — the manuscript's
    difference-spectrum method: for each sample × treatment-pair, computes
    the spectral difference for all 36 replicate-pair combinations
    (exhaustive, not a random draw — see `REPOSITORY_NOTES.md` for why).
    Writes one CSV per sample × pair to `BootstrappedData/`.
12. `Workflow_Calculations/code/BootstrapFigureGeneration.R` — the
    difference-spectrum figure and cross-treatment summary table from
    step 11's output.
13. `Workflow_Calculations/code/Table1_SpectralDifferenceRegions.R` and
    `Workflow_Calculations/code/SpectralDifferenceCurves.R` — regenerate the
    manuscript's spectral-difference-by-region table and full-resolution
    difference curves, both directly from step 11's output.
14. `Workflow_Visualization/Map_Visualization.R` — sample collection-location
    map. Reads `sample_info.csv` only; independent of every other step.

Everything under `*/archive/` is superseded and not part of this run order —
see `REPOSITORY_NOTES.md` for what's there and why.

## Environment

- **R 4.4.1** (recorded in `renv.lock`; 4.4.x expected to work).
- Dependencies are locked with [renv](https://rstudio.github.io/renv/). Run
  `renv::restore()` from the repo root — or just open R there, `.Rprofile`
  auto-activates renv — to install the recorded package versions into a
  project-local library. `brms` pulls in a Stan toolchain and needs a
  working C++ compiler.
- `Table1_SpectralDifferenceRegions.R`'s Word-table export (`flextable`/
  `officer`) needs a working `gdtools` build, which on macOS needs a
  Homebrew `pkg-config` + `gettext` setup not captured by `renv.lock` — see
  `REPOSITORY_NOTES.md` if `renv::restore()` fails on `gdtools`.

## AI use disclosure

Development of this repository's code, QC/taxonomic-harmonization tooling
(shared with [EnSpec/enspec-qc](https://github.com/EnSpec/enspec-qc)), and
documentation (including this README) was assisted by Claude (Anthropic),
used via Claude Code, for code review, debugging, data-processing pipeline
design, and editorial support. All code was written, reviewed, and executed
by the authors; AI-suggested changes were accepted only after inspection and
after the analysis reproduced prior results. No text, data, figures, or
citations were included without author verification.

## Repository status

This repo was migrated out of a private student repo and cleaned up for
public release alongside manuscript submission: hard-coded machine paths
replaced with a `data_root` convention, superseded scripts moved to
`archive/`, a shared QC pass and taxonomic-harmonization step added ahead of
the EcoSIS deposit. Full internal data paths, the archived-code inventory,
and the cleanup history are in `REPOSITORY_NOTES.md`.
