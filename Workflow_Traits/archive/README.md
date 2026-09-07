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

All three still contain hard-coded paths to the original authors' machines and
are not wired to `R/paths.R`.
