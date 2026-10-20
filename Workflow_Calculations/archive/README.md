# archive/

Superseded scripts, kept for provenance. **Not part of the maintained
pipeline** and not run for the manuscript.

- **`BiasCalc.R`**, **`BiasFunctionExecution.R`**, **`BiasSummaryCalculation.R`**
  — the original difference-spectrum approach: *averages* the 6 spectral
  replicates per treatment, then takes pairwise treatment differences on the
  averaged spectra. Superseded by the replicate-pair difference pipeline (`ReplicatePairDifferences.R` /
  `ReplicatePairDifferenceFigure.R` in `code/`), which draws random
  replicate-pair differences and iterates — the method the manuscript
  describes. Figures for this chain are in
  `Workflow_Visualization/archive/BiasFigures.R`. Archived 2026-09-13.
- Known issues, preserved here in case this chain is ever un-archived:
  `BiasCalc.R:23–25` has `%>%` at the *start* of continuation lines inside
  the function body, a parse error — `biascalc()` cannot be defined as
  written; `:57,69` `matrix(data =, nrow = 1, ...)` is missing its first
  argument. `BiasSummaryCalculation.R:17` has a dangling `mutate()` with no
  arguments; `:68,90` `averageallX = averagevisibleX = subset(...)` then
  immediately overwrites `averagevisibleX` on the next line.
- The 44MB `AllSamplesBIAS.csv` / `AllSamplesBIASNormalized.csv` this chain
  read/wrote were removed from the working tree in `53735bf` and from git
  history in a later rewrite (see repo history for details) — they
  were only ever consumed by this now-archived chain.
