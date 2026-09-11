# archive/

Superseded scripts, kept for provenance. **Not part of the maintained
pipeline** and not run for the manuscript.

- **`Spectral_Visualization.R`** — per-species spectra plots by milling
  treatment / drying method, hardcoded to read `5nmResampleSpectra_OM.csv`.
  "OM" = **Old Mill**, one side of an early equipment-comparison pilot
  (Wiley vs. Eberbach rotary mills — Henry, 2026-09-11) that was set up in
  the SpectralPredictR/data-join pipeline but not carried into the
  manuscript, which reports one mill type only (the "NM"/New Mill data
  `Predicted_Trait_Analysis.R` and `DataJoin.R` actually use). Confirmed the
  OM and NM trait-prediction files cover the exact same 66 Mill24 samples
  and milling treatments -- this isn't a different/older sample set, just
  the abandoned equipment axis. Archived rather than re-pointed at NM since
  the comparison itself, not just the file it reads, was dropped from
  scope.
