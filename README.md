# Replication Package — EGJL "Excess Default Correlations" (Empirical Component)

This package reproduces all empirical exhibits in the paper (Management Science, R2):
industry-pair **total** and **excess** correlations of default risk and equity moments
(Table 3 and Online Appendix Tables OA.4–OA.9) and the default-probability (PROB)
goodness-of-fit figure (Figure OA.4).

## 1. Requirements
- **Python 3** with: pandas, numpy, scipy, pyreadstat, duckdb, wrds, pandas-datareader, tqdm.
  (Only needed for the full build from WRDS — Step 1.)
- **R** with: tidyverse, fixest, kableExtra, psych, broom, modelsummary, rhdf5, zoo, ggrepel,
  ggforce, cowplot, viridis, knitr, pander, gt. (Run `Rscript install_R_packages.R` to install.)
- **Pandoc ≥ 1.12.3** (we used 3.10) — a system tool required by `rmarkdown` to knit the
  exhibits (`main_empirics.Rmd` → tables/figures). RStudio bundles its own pandoc, but command-line `Rscript`
  does not, so install it system-wide:
  - macOS: `brew install pandoc`   ·   conda: `conda install -c conda-forge pandoc`
  - Linux: `apt-get install pandoc` (or your distro's package)   ·   or download from pandoc.org
  - Verify with `pandoc --version`. If R was already running when you installed it, restart R,
    or point R at it via `Sys.setenv(RSTUDIO_PANDOC = dirname(Sys.which("pandoc")))`.
- A **WRDS account** with CRSP, Compustat, IBES, and TRACE access — only for the full rebuild.

## 2. Set the package root
Paths are centralized in `config.py` and `config.R`, which auto-detect the package root.
No editing is needed if you keep `config.py` / `config.R` at the package root. If R
auto-detection fails, set `ROOT` on the marked line in `config.R`.

## 3. Two ways to reproduce

### Path A — From the shipped derived data (no WRDS needed) — recommended for referees
The package ships the derived inputs, so you can regenerate **every exhibit** without WRDS:

    Rscript master.R

This knits `code/r/main_empirics.Rmd`, writing the tables to `output/tables/`, Figure OA.4 to
`output/figures/`, and an HTML report to `output/main_empirics.html`. It reads the shipped
`Data/Estimates/` directly. To recompute those bootstrap estimates first (from
`Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv`; stationary block bootstrap, ~hours),
set `RUN_STEP2 <- TRUE` near the top of `master.R`.

### Path B — Full rebuild from WRDS
1. Ensure WRDS credentials are configured; obtain the third-party files listed in
   `DATA_AVAILABILITY.md` and place them in `Data/`.
2. `python code/python/iclink.py` then `python code/python/Step1_PrepareAllData.py`
   (builds the firm/industry panels; hours).
3. Continue with Path A (`Rscript master.R`, optionally with `RUN_STEP2 <- TRUE`).

## 4. Exhibit → producing script
All empirical exhibits are produced by `code/r/main_empirics.Rmd` (run via `master.R`).

| Paper exhibit | Output file |
|---|---|
| Table 3 — excess correlations across industries | `output/tables/Table3_Excess_Corr_Industries.tex` |
| Table OA.4 — firm fundamentals (unrelated pairs) | `output/tables/TableOA4_Funda_Corr_Unrelated.tex` |
| Table OA.5 — default risk & equity moments (unrelated pairs) | `output/tables/TableOA5_DefRisk_Equity_Corr_Unrelated.tex` |
| Table OA.6 — firm fundamentals robustness | `output/tables/TableOA6_Funda_Corr_Unrelated_Robustness.tex` |
| Table OA.7 — total & excess corr, unrelated, robustness | `output/tables/TableOA7_Total_Excess_Corr_Unrelated_Robustness.tex` |
| Table OA.8 — total & excess corr, all industries, robustness | `output/tables/TableOA8_Total_Excess_Corr_All_Robustness.tex` |
| Table OA.9 — size & book-leverage terciles | `output/tables/TableOA9_Excess_Corr_Size_BookLev_Terciles.tex` |
| Figure OA.4 — PROB vs. fitted value | `output/figures/FigureOA4_PROB_fit.png` |

## 5. Sample & key settings
Sample 1987-06-30 → 2023-12-31. Block bootstrap: block length 4 quarters, B = 1000, seed = 123.

## 6. Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- See `DATA_AVAILABILITY.md` for data sources and the files that must be obtained from WRDS.
- Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
