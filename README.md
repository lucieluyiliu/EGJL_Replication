# Replication Package — EGJL "Excess Co-movement in Default Risk"

Replication package for the paper (Management Science, R2) by Ericsson, Glover, Jeanneret, and Lu.
It has two self-contained components:

- **Theory (MATLAB)**: the calibrated two-tree model. Produces Tables 1–2, OA.1–OA.2, and OA.10, and
  Figures 2–6 and OA.1–OA.4. Code in `code/matlab/` (see §4).
- **Empirics (Python + R)**: industry-pair **total** and **excess** correlations of default risk and
  equity moments. Produces Table 3, Online Appendix Tables OA.4–OA.9, and the default-probability
  (PROB) goodness-of-fit Figure OA.5. Code in `code/python/` and `code/r/`.

Following the order of the paper, §4 covers the MATLAB theory code and §5–§8 cover the empirical
reproduction.

## 1. Requirements
- **MATLAB R2026a** for the theory exhibits (§4), with the **Statistics and Machine Learning Toolbox**
  (`normrnd`, `unifrnd`, `prctile`) and the **Parallel Computing Toolbox** (`parfor`; the code still
  runs without it, just serially).
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

## 4. Theory component (MATLAB)
The model exhibits are produced by the MATLAB code in `code/matlab/` (author: Kristoffer Glover).
Per-function documentation is in `code/matlab/readme.txt`.

**Run:** open `code/matlab/main.m` in MATLAB and run it (it sets its own working directory, so the
helper functions resolve from any starting folder). It generates the data for Tables 1–2, OA.1–OA.2,
and OA.10, writes the figures for Figures 2–6 and OA.1–OA.4 (`.pdf`/`.eps`) to `output/figures/`, and
prints the asset-pricing moment values reported in Sections 2.1 and 3.3. Calibration parameters are
those in Sections 2.1, 3.3, and 2.6.

Two ways to run, set by the `RECOMPUTE` flag at the top of `main.m`:

- **Path A — read the precomputed solutions (fast, the default).** With `RECOMPUTE = false` (the
  default), `main.m` loads the model solutions from `Data/DataFile.mat` and produces all theory
  exhibits without re-solving (minutes instead of ~10 h). Requires `Data/DataFile.mat` (~2 GB),
  shipped with the package.
- **Path B — recompute from scratch (slow).** Set `RECOMPUTE = true`: `main.m` re-solves the model
  and re-runs the simulation (~10 h, see §7), saves a fresh `Data/DataFile.mat`, then produces the
  exhibits.

| Paper exhibit | Produced by |
|---|---|
| Tables 1–2, OA.1–OA.2, OA.10 | `code/matlab/main.m` |
| Figures 2–6, OA.1–OA.4 | `code/matlab/main.m` |

Key functions (full list in `code/matlab/readme.txt`): `TWOTREEY.m` (debt and equity value with the
optimal default boundary, via the PSOR finite-difference method), `CorrEst.m` (distance-to-default
correlation, Equation 11), `Simulation.m` and `DefaultTimes.m` (simulated economies and default
rates), `PROBDEF.m` (default probabilities under P and Q), and `CSpread.m` / `CPE1D.m` (equilibrium
credit spreads, Table OA.10).

## 5. Empirics: two ways to reproduce

### Path A — From the shipped derived data (no WRDS needed)
The package ships the derived inputs, so you can regenerate **every empirical exhibit** without WRDS:

    Rscript master.R

This knits `code/r/main_empirics.Rmd`, writing the tables to `output/tables/`, Figure OA.5 to
`output/figures/`, and an HTML report to `output/main_empirics.html`. It reads the shipped
`Data/Estimates/` directly. To recompute those bootstrap estimates first (from
`Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv`; stationary block bootstrap,
~55 min, see §7), set `RUN_STEP2 <- TRUE` near the top of `master.R`.

### Path B — Full rebuild from WRDS
1. Ensure WRDS credentials are configured; obtain the third-party files listed in
   `DATA_AVAILABILITY.md` and place them in `Data/`.
2. `python code/python/iclink.py` then `python code/python/Step1_PrepareAllData.py`
   (builds the firm/industry panels; ~1 h 25 min, see §7).
3. Continue with Path A (`Rscript master.R`, optionally with `RUN_STEP2 <- TRUE`).

## 6. Empirics: exhibit → producing script
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
| Figure OA.5 — PROB vs. fitted value | `output/figures/FigureOA5_PROB_fit.png` |

## 7. Sample, key settings, and runtime
Sample 1987-06-30 → 2023-12-31. Block bootstrap: block length 4 quarters, B = 1000, seed = 123.

**Approximate runtime** (MacBook Pro, Apple M5 Pro, 18 cores, 64 GB):

| Stage | Script | Runtime |
|---|---|---|
| Theory — full solve + simulation (`RECOMPUTE=true`) | `code/matlab/main.m` | ~10 h (10 h 3 min); 18 cores for the PDE solves, the simulation phase is single-threaded |
| Empirics Path B — full WRDS rebuild | `Step1_PrepareAllData.py` | ~1 h 25 min |
| Empirics Step 2 — block bootstrap (B = 1000) | `Step2_MakeCorrelations_V4.R` | ~55 min (capped at 15 cores, hardcoded for reproducibility) |
| Empirics Path A — knit exhibits | `master.R` (`main_empirics.Rmd`) | a few seconds |

The theory `RECOMPUTE=false` path loads `Data/DataFile.mat` instead of re-solving, skipping the
multi-hour solve and simulation (only the table and figure post-processing re-runs).

Path A alone (the default, reading the shipped `Data/Estimates/`) completes in seconds. Step 2 and
the full Python rebuild are only needed to regenerate the estimates or the firm/industry panels from
scratch; both are WRDS- and CPU-bound, so wall-clock time scales with core count and WRDS load.

## 8. Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- See `DATA_AVAILABILITY.md` for data sources and the files that must be obtained from WRDS.
- Contact: Kristoffer Glover (Kristoffer.Glover@uts.edu.au), Lucie Lu (lucie.lu@unimelb.edu.au).
