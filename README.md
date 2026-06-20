# Replication Package — EGJL "Excess Default Correlations" (Empirical Component)

This package reproduces all empirical exhibits in the paper (Management Science, R2):
industry-pair **total** and **excess** correlations of default-related variables, the
excess-correlation-by-leverage figure, and the default-probability (PROB) goodness-of-fit figures.

## 1. Requirements
- **Python 3** with: pandas, numpy, scipy, pyreadstat, duckdb, wrds, pandas-datareader, tqdm.
  (Only needed for the full build from WRDS — Step 1.)
- **R** with: tidyverse, fixest, kableExtra, psych, broom, modelsummary, rhdf5, zoo, ggrepel,
  ggforce, cowplot, viridis, knitr, pander, gt. (Run `Rscript install_R_packages.R` to install.)
- **Pandoc ≥ 1.12.3** (we used 3.10) — a system tool required by `rmarkdown` to knit the Step 3
  exhibits (`.Rmd` → tables/figures). RStudio bundles its own pandoc, but command-line `Rscript`
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
The package ships the derived inputs, so you can regenerate **every table and figure** without WRDS:
1. `Rscript code/r/Step2_MakeCorrelations_V4.R` — rebuilds `Data/Estimates/` from
   `Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv` (block bootstrap; minutes).
2. Knit `code/r/Step3_Industry_correlation_V7.Rmd` — writes the tables to `output/tables/`
   and `output/figures/fig_Excess_Default_Corr_vs_BookLeverage.png`.
3. Knit `code/r/PROB_Goodness_of_Fit_V2.1.Rmd` — writes the 8 PROB-fit figures to `output/figures/`.

(You can skip step 1 and go straight to knitting if you trust the shipped `Data/Estimates/`.)

### Path B — Full rebuild from WRDS
1. Ensure WRDS credentials are configured; obtain the third-party files listed in
   `DATA_AVAILABILITY.md` and place them in `Data/`.
2. `python code/python/iclink.py` then `python code/python/Step1_PrepareAllData.py`
   (builds the firm/industry panels; hours).
3. Continue with Path A steps 1–3.

## 4. Exhibit → producing script
| Paper exhibit | Output file | Produced by |
|---|---|---|
| Table 1 — total & excess correlations | `output/tables/Table1_Total_and_Excess_Corr_main.tex` | Step3 V7 |
| Table 1 robustness (subsamples) | `output/tables/Table1_..._Subsample_{Unrelated,All}.tex` | Step3 V7 |
| Table 2 — by size / book leverage | `output/tables/Table2_Excess_Corr_{BySize,ByBOOKLEV}.tex` | Step3 V7 |
| Table A2 / A3 — unrelated pairs total corr | `output/tables/TableA2_*`, `TableA3_*` | Step3 V7 |
| Table IA7 / IA8 — robustness | `output/tables/TableIA7_*`, `TableIA8_*` | Step3 V7 |
| Excess default corr vs. book leverage | `output/figures/fig_Excess_Default_Corr_vs_BookLeverage.png` | Step3 V7 |
| PROB goodness of fit (8 figures) | `output/figures/fig_PROB_fit_*.png` | PROB_Goodness_of_Fit_V2.1 |

## 5. Sample & key settings
Sample 1987-06-30 → 2023-12-31. Block bootstrap: block length 4 quarters, B = 1000, seed = 123.

## 6. Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- See `DATA_AVAILABILITY.md` for data sources and the files that must be obtained from WRDS.
- Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
