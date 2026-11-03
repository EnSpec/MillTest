# Repository notes

Internal/administrative documentation for this repository: where the data
actually lives, what got archived and why, and how this codebase got to its
current state. Split out of `README.md` so that file can stay focused on
what a reader outside the lab (a reviewer, a reuser of the deposit) needs.
This file is committed and public, but it documents lab-internal plumbing,
not the study itself — see `README.md` for that.

## Internal data paths

Nothing under this section is stored in the repo. All of it lives on the
EnSpec lab's internal server, mounted at `/Volumes/Enspec/projects/Mill24/`.
Every script sets `data_root` near the top the same way:

```r
data_root <- Sys.getenv("MILL24_DATA_ROOT",
                        unset = "/Volumes/Enspec/projects/Mill24")
```

and builds paths with `file.path(data_root, ...)`. Point at a different copy
of the data by setting `MILL24_DATA_ROOT` before starting R. Script outputs
are written under `<data_root>/derived/`, never into the repo.

Current layout (verified against the live server 2026-09-25 — this section
drifts as the project progresses; if it looks behind what a script actually
reads, trust the script and fix this file):

```
Mill24/
  Mill24_RawSpec.csv        merged/parsed ASD spectra (already jump-corrected
                             despite the filename — see README.md)
  DrySpec/                  raw per-session .asd files (FreezeDried/, OvenDried/)
  ChemResults/               Brookside.csv, TPC/Ankom/13C15N workbooks — several
                             of these are shared, multi-project lab logs, not
                             Mill-Test-only; the extract scripts below filter
                             to this study's rows
  field_data/                sample_info.csv (canonical per-individual metadata),
                             mill_test_inventory_data_log.xlsx, Mill24_LMA.xlsx
  particle_size/data/        LS 13320 particle-size analyzer exports, one file
                             per sample x mill treatment
  spectralpredictr/          SpectralPredictR.R's own output CSVs (raw spectra,
                             jump-corrected, 5nm-resampled, trait predictions)
  ReplicatePairDifferences/           output of ReplicatePairDifferences.R
  LeafScans/, LMA_Processing_Training/
  manuscript/                 the manuscript draft itself (not part of the
                             code or data release)
  derived/                    everything every script in this repo writes;
                             one subdirectory per script/purpose (ankom/,
                             isotope/, tpc/, fat_assay/, brookside/,
                             leaf_area/, particle_size/, spectral_metadata/,
                             ecosis/, taxonomy/, qc/, anova/, chemistry/,
                             replicate_pair_differences/, data_join/, maps/, trait_comparisons/)
```

Existing top-level directory names are kept as-is where other projects on
the server read them directly (`ChemResults/` in particular — see
`IsotopeExtract.R`'s header comment); `spectralpredictr/`, `field_data/`,
`particle_size/`, and `derived/` were added during the 2026 cleanup.

**Nothing is "not yet staged" any more.** An earlier version of this note
(formerly in `README.md`) listed the SpectralPredictR export CSVs,
`sample_info.csv`, and the particle-size exports as blocked on Zach. All
three have been on the server and read by the pipeline since 2026-09-11 —
that line was stale by the time it was last read closely (caught
2026-09-25). If a future gap shows up here, name the specific missing
file(s), not a general "waiting on X" note that can go stale silently.

## Archived code

Four `archive/` directories, one per `Workflow_*/` folder, each with its own
`README.md` giving full detail. Summary:

- **`Workflow_Calculations/archive/`** — `BiasCalc.R`, `BiasFunctionExecution.R`,
  `BiasSummaryCalculation.R`: the original difference-spectrum approach
  (averages the 6 replicates, then differences), superseded by the
  replicate-pair difference pipeline (`code/ReplicatePairDifferences.R` / `code/ReplicatePairDifferenceFigure.R`),
  which is what the manuscript describes and reports. Known parse/logic bugs
  in the archived scripts are preserved in that folder's README in case this
  chain is ever revisited.
- **`Workflow_Visualization/archive/`** — `Spectral_Visualization.R`
  (read the abandoned "Old Mill" equipment-comparison pilot, not the
  study's reported mill) and `BiasFigures.R` (figures for the superseded
  averaging-based difference approach above).
- **`Workflow_Traits/archive/`** — `PCA_Processing.R`/`NEW_PCA.R` (PCA/
  ordination, not carried into the manuscript) and `Mill_Test_Analysis.R`
  (early exploratory joins; its lasting product is `sample_info.csv`,
  which several maintained scripts still read — kept as the record of how
  that file was built). `Mill24_Trait_Comparisons.R` (early per-species
  trait plots by A. Majerus; debugged before archiving, still runnable).
  Nothing in this folder is part of the maintained pipeline.
- **`Workflow_Analysis/archive/`** — `Predicted_Trait_Analysis_other_traits.R`,
  non-functional chlorophyll/lignin/starch model fragments pasted in from a
  different project's data; the manuscript's Bayesian ANOVA covers nitrogen
  and calcium only.

## Repository status / history

This repo was migrated out of [Zach Breuer's private repository](https://github.com/zbreuer?tab=repositories)
into a single shared repo under EnSpec for public release alongside
manuscript submission — the initial commit here is literally titled "Clone
Private Repository". Three people (Zach Breuer, Annabelle Majerus, and
Henry Frye — the code's `CITATION.cff` authors) had been working directly
on their own machines, none of which still exist. Original state at
migration: a one-line README, no license, no dependency lock, hard-coded
per-machine paths throughout, and two independent difference-spectrum
pipelines (the averaging approach and the bootstrap approach) with no
record of which one was current.

**Cleanup phases** (see git log for the full commit-by-commit record —
this is the summary):
- **Phase 0** — scaffolding: GPL-3 license, `.gitignore`, `renv.lock`,
  README rewrite, archived the PCA/exploratory scripts.
- **Phase 1–2** — every script repointed off hard-coded paths onto the
  `data_root` convention; correctness pass on each script against real
  server data (bugs found and fixed are listed in each script's own header
  comment, not repeated here); Bias* chain confirmed superseded and
  archived; bootstrap procedure redesigned from random resampling to
  exhaustive enumeration of all 36 replicate-pair combinations per sample
  (only 6 spectral replicates exist per sample x treatment, so random
  resampling at any iteration count just redraws the same finite pool with
  gaps); git history rewritten once (with the maintainer's sign-off) to
  drop two accidentally-committed ~44MB CSVs.
- **Phase 3** — merged to `main` via PR #1; a bad manual conflict
  resolution on that merge silently reverted 4 files to pre-cleanup
  versions, caught and fixed same day via PR #2 (all 4 re-verified against
  real server data before merging).
- **EcoSIS deposit build-out** (2026-09) — six new chemistry-extraction
  scripts (`AnkomExtract.R`, `IsotopeExtract.R`, `TPCExtract.R`,
  `FatAssayExtract.R`, `BrooksideExtract.R`, `LeafAreaExtract.R`), each
  pulling this study's rows out of a shared/multi-project lab file and
  converting to consistent units; `EcoSISMetadataSidecar.R` joining
  everything into one per-spectrum table; a shared QC pass
  (`TraitSpectralQC.R` + `qc_config_milltest.R`, using the shared
  `enspec-qc` library — see README's Environment section) added via PR #3;
  an ANKOM spreadsheet-formula bug found and fixed via PR #4 (two cells in
  one workbook had a shifted relative row reference — fixed by recomputing
  every reported fraction from the raw weights instead of trusting the
  workbook's own formulas, with a QC check added so a future formula slip
  like this can't ship silently); taxonomic harmonization against the World
  Flora Online backbone added via PR #5.

**Known open issue, not yet fixed:** `ReplicatePairDifferences.R`, `DataJoin.R`, and
`ChemistryAnalysis.R` each extract the drying/milling codes from
`sample_name` using fixed-offset `substring()`/`substr()` calls (e.g.
`substring(sample_name, 13, 14)` for the drying code, `substring(sample_name,
16, 19)` for the milling code) rather than splitting on the `_` delimiters.
This only works because every sample name in this dataset follows the exact
same fixed-width template — `MILL24_<4-digit id>_<2-char drying>_<4-char
milling>_<5-digit replicate>` — so the character positions never shift. It
is fragile, not broken: a future sample ID past 4 digits, a differently-sized
drying/milling code, or an extra inserted field would shift every downstream
offset and pull the wrong substring silently (no error, no crash — same
class of risk as the ANKOM formula-slip bug, just in the code instead of a
spreadsheet). Not something to fix under this release's deadline; worth a
cheap regex/`stringr`-based rewrite (split on `_`, don't count characters)
before this pipeline is reused for a project with a different naming scheme.

**Reused across the file naming/duplicate-scan/dedup logic**: 7 sample x
treatment combinations were scanned twice, about a month apart, under two
different session-date folders (confirmed via file hash — genuinely
different spectra, not re-copies). The later-dated scan is treated as final
throughout (confirmed against the field measurement log for all 7 cases,
not just assumed).

**renv/setup gotcha, not documented anywhere else:** `Table1_SpectralDifferenceRegions.R`'s
Word-table export (`flextable`/`officer`) needs a working `gdtools` build,
which on macOS needs Homebrew's `pkg-config` installed and
`LDFLAGS`/`CPPFLAGS` pointing at Homebrew's keg-only `gettext` added to
`~/.R/Makevars` — without this, `gdtools` fails to link
(`ld: library 'intl' not found`). Neither the brew install nor the Makevars
edit is captured by `renv.lock`. A fresh `renv::restore()` from a clean
clone and empty cache was tested on 2026-11-03 (macOS, R 4.4.1) and restored
all 227 packages with `renv::status()` consistent. The one failure was `xfun`
failing to link against a malformed macOS 27.0 SDK; setting `SDKROOT` to the
26.5 SDK fixed it (see README, Environment).
