# Replication Package — EGJL "Excess Default Correlations" (Empirical Component)

This package reproduces all empirical exhibits in the paper (Management Science, R2):
industry-pair **total** and **excess** correlations of default risk and equity moments
(Table 3 and Online Appendix Tables OA.4–OA.9) and the default-probability (PROB)
goodness-of-fit figure (Figure OA.4).

## 1. Requirements
- **R 4.5.1** with the packages pinned in `renv.lock` (tidyverse, fixest, kableExtra, rhdf5, zoo,
  psych, broom, modelsummary, viridis, ggforce, ggrepel, cowplot, knitr, pander, gt). Installed via
  `renv` in §2.
- **Python 3.11** with pandas, numpy, scipy, pyreadstat, duckdb, wrds, pandas-datareader, tqdm —
  pinned in `pyproject.toml` / `uv.lock`. Only needed for the full WRDS rebuild (Path B).
- **Pandoc ≥ 1.12.3** (we used 3.10) — a system tool `rmarkdown` needs to knit the exhibits.
- A **WRDS account** with CRSP, Compustat, IBES, and TRACE access — only for the full rebuild.

## 2. Environment setup — do this first
A fresh clone ships the **lockfiles, not the packages**, so build the environment before running anything.

**R packages** (exact versions from `renv.lock`), from the package root:

    Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv"); renv::restore()'

`renv::restore()` installs every package at its locked version into a project-local library, and warns
if your R version differs from the lock. (Quick alternative, *not* version-pinned: `Rscript install_R_packages.R`.)

**Pandoc** (required to knit the exhibits — command-line `Rscript` has no bundled pandoc):

    brew install pandoc          # macOS   (Linux: sudo apt-get install pandoc;  conda: conda install -c conda-forge pandoc)

Verify with `pandoc --version`. If R is already open, restart it (or
`Sys.setenv(RSTUDIO_PANDOC = dirname(Sys.which("pandoc")))`).

**Python** (only for Path B — the full WRDS rebuild):

    uv sync                                  # from pyproject.toml + uv.lock (exact versions)
    # or:  pip install -r requirements.txt
    # or:  conda env create -f environment.yml && conda activate egjl-replication

## 3. Set the package root
Paths are centralized in `config.py` and `config.R`, which auto-detect the package root.
No editing is needed if you keep `config.py` / `config.R` at the package root. If R
auto-detection fails, set `ROOT` on the marked line in `config.R`.

## 4. Two ways to reproduce

### Path A — From the shipped derived data (no WRDS needed)
The package ships the derived inputs, so you can regenerate **every exhibit** without WRDS:

    Rscript master.R

This knits `code/r/main_empirics.Rmd`, writing the tables to `output/tables/`, Figure OA.4 to
`output/figures/`, and an HTML report to `output/main_empirics.html`. It reads the shipped
`Data/Estimates/` directly. To recompute those bootstrap estimates first (from
`Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv`; stationary block bootstrap,
~55 min, see §6), set `RUN_STEP2 <- TRUE` near the top of `master.R`.

### Path B — Full rebuild from WRDS
1. Ensure WRDS credentials are configured; obtain the third-party files listed in
   `DATA_AVAILABILITY.md` and place them in `Data/`.
2. `python code/python/iclink.py` then `python code/python/Step1_PrepareAllData.py`
   (builds the firm/industry panels; ~1 h 25 min, see §6).
3. Continue with Path A (`Rscript master.R`, optionally with `RUN_STEP2 <- TRUE`).

## 5. Exhibit → producing script
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

## 6. Sample, key settings, and runtime
Sample 1987-06-30 → 2023-12-31. Block bootstrap: block length 4 quarters, B = 1000, seed = 123.

**Approximate runtime** (development machine: macOS, 16 logical cores; the bootstrap uses 15):

| Stage | Script | Runtime |
|---|---|---|
| Path B — full WRDS rebuild | `Step1_PrepareAllData.py` | ~1 h 25 min |
| Step 2 — block bootstrap (B = 1000) | `Step2_MakeCorrelations_V4.R` | ~55 min |
| Path A — knit exhibits | `master.R` (`main_empirics.Rmd`) | a few seconds |

Path A alone (the default, reading the shipped `Data/Estimates/`) completes in seconds. Step 2 and
the full Python rebuild are only needed to regenerate the estimates or the firm/industry panels from
scratch; both are WRDS- and CPU-bound, so wall-clock time scales with core count and WRDS load.

## 7. Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- See `DATA_AVAILABILITY.md` for data sources and the files that must be obtained from WRDS.
- Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
