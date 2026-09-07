# archive/

Superseded scripts, kept for provenance. **Not part of the maintained
pipeline** and not run for the manuscript.

- **`PCA_Processing.R`**, **`NEW_PCA.R`** — exploratory PCA/ordination of the
  resampled spectra. The PCA analysis was not carried forward into the
  manuscript. `NEW_PCA.R` was a partial rewrite of `PCA_Processing.R`.
- **`Mill_Test_Analysis.R`** — early exploratory joins and box plots of the
  field/leaf-trait data (chlorophyll, LMA, water content by growth form). Its
  one lasting product is `sample_info.csv` (built from `LMA_data.csv`,
  `Chlorophyll.csv`, `Spp_Checklist.csv`, `Field_Sample_Inventory.csv`), which
  several maintained scripts still read. Kept here as the record of how that
  file was generated.
- **`Mill24_Trait_Comparisons.R`** — early per-species line plots of predicted
  traits across milling treatments, by growth form and drying method (A.
  Majerus). Exploratory; the manuscript reports calcium and nitrogen only.
  Before archiving it was de-bugged (a broken duplicate call block, a stray
  auto-print, deprecated `size=` aesthetics), given the proper δ¹⁵N axis
  label, wired to `data_root` (writes to `derived/trait_comparisons/`), and
  ~300 lines of dead/commented code were removed. It still runs against
  `spectralpredictr/DryTraits_NM.csv`.

`PCA_Processing.R`, `NEW_PCA.R` and `Mill_Test_Analysis.R` still contain
hard-coded paths to the original authors' machines.
