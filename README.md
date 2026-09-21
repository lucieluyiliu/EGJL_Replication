# README

**Manuscript title:** Excess Co-movement in Default Risk

**Manuscript ID:** MS-FIN-2025-00698

**Author(s):** Jan Ericsson, Kristoffer Glover, Alexandre Jeanneret, Lucie Yiliu Lu

## 1. Overview
This is the replication package for the paper (Management Science). It has two self-contained
components:

- **Theory (MATLAB)**: the calibrated two-tree model. Produces Tables 1–2, OA.1–OA.2, and OA.10, and
  Figures 2–6 and OA.1–OA.4. Code in `code/matlab/`.
- **Empirics (Python + R)**: industry-pair **total** and **excess** correlations of default risk and
  equity moments. Produces Table 3, Online Appendix Tables OA.4–OA.9, and the default-probability
  (PROB) goodness-of-fit Figure OA.5. Code in `code/python/` and `code/r/`.

Contents of the package:

| Path | Content |
|---|---|
| `README.md` | This file |
| `DATA_DICTIONARY.md` | Variable dictionaries for the datasets in `Data/` (see Section 3) |
| `config.py`, `config.R` | Central paths; they detect the package root, so no path needs editing |
| `master.R` | Master script for the empirical exhibits |
| `code/matlab/` | Theory code: `main.m` plus its functions (documented in `code/matlab/readme.txt`) |
| `code/python/` | Data build from WRDS (`iclink.py`, then `Step1_PrepareAllData.py`, which runs the `Make*.py` scripts) |
| `code/r/` | Correlations and block bootstrap (`Step2_MakeCorrelations_V4.R`, `functions_V4.1.R`) and the exhibits (`main_empirics.Rmd`) |
| `Data/` | All data read and written by the code (see Section 2) |
| `output/tables/`, `output/figures/` | The tables (`.tex`) and figures of the paper, as produced by the code |
| `output/main_empirics.html` | Report knitted by `main_empirics.Rmd` |
| `output/log/` | Log files of our runs: `matlab_run.log` (theory), `step1_build.log` (Python data build), `master_R.log` (bootstrap and exhibits) |
| `renv.lock`, `renv/`, `install_R_packages.R` | R environment |
| `pyproject.toml`, `uv.lock`, `requirements.txt`, `environment.yml` | Python environment |

How to proceed from beginning to end:

1. Set up the software environment (Section 4).
2. Theory exhibits: run `code/matlab/main.m` (Section 5). By default it reads the precomputed model
   solutions in `Data/DataFile.mat` and finishes in minutes.
3. Empirical exhibits: run `Rscript master.R` from the package root (Section 5). It reads the data
   shipped in `Data/` and needs no WRDS access.
4. Optional, with WRDS access: rebuild the empirical data from WRDS with the Python code (Path B in
   Section 5), then repeat step 3.

## 2. Data availability and provenance
This paper relies on data, and all data necessary to reproduce the results of the paper are
included in the replication package provided to the journal's code and data editor. This
section describes every dataset used, where it comes from, and how it can be obtained or rebuilt.

The theory component uses no external data. The empirical analysis uses data from **WRDS**
(CRSP, Compustat, IBES), corporate bond data from the **Open Source Bond Asset Pricing** project
(Dickerson, Robotti, and Rossetti), and public sources (FRED and authors' websites).

### Data vintage
WRDS revises its databases continuously, so a fresh download does not return exactly the data
behind the paper. The WRDS extracts in `Data/` are frozen as of the build run of 25 June 2026
that produced the results in the paper. The package therefore ships this vintage, together with
the code that rebuilds every extract from WRDS (`code/python/`, Path B in Section 5).
Researchers with WRDS access can rerun that code; results from a later vintage can differ slightly
from the published ones.

### Included in this package (`Data/`)

#### Raw data
| File | Description | Source and how to obtain |
|---|---|---|
| `comp_quarter.hdf`, `comp_annual.h5` | Compustat quarterly and annual fundamentals | WRDS Compustat. Downloaded by `MakeMainDataFile_V1.py` |
| `raw_data.hdf` | Merged CRSP, Compustat, and IBES firm-month panel | WRDS. Built by `MakeMainDataFile_V1.py` |
| `iclink.pkl` | CRSP to IBES link table | WRDS (CRSP, IBES). Built by `iclink.py` |
| `trace_29_04_2025.parquet` | Corporate bond prices, credit spreads, and maturities (snapshot of 29 April 2025) | Dickerson, Robotti, and Rossetti TRACE dataset, Open Source Bond Asset Pricing (openbondassetpricing.com). This snapshot was shared directly by Alex Dickerson ahead of its public release |
| `WRDS_MMN_Corrected_Data_2024_July.csv` | MMN-corrected bond data, July 2024 version. Used only for its bond to firm link (`date`, `cusip`, `permno`) in `MakeCreditSpread.py` | Downloaded from Open Source Bond Asset Pricing (openbondassetpricing.com) |
| `drcoefficients2021.xlsx` | Default-risk (CDR) logit coefficients applied by `MakePROB.py` to compute the default probability | Originally from Jens Hilscher, shared by Kevin Aretz |
| `Moodys_NB_QTRLy_US_Defaults_US_21072020.xlsx` | Quarterly number of U.S. corporate defaults by industry, 1970 onwards (extract dated 21 July 2020). The total across industries (column `ALL`) is used in Figure OA.5 (`main_empirics.Rmd`) | Moody's (proprietary) |
| `FF48_Stocks.h5` | Firm-month Fama–French 48 industry tags, January 1960 to December 2022 (input to `MakePortfolios_v2.py`). `code/python/MakeFF48.py` documents its construction and rebuilds it from WRDS: CRSP stock-months (`crsp.msf_v2`) with each stock's SIC code as of end-2022 (`crsp.stocknames`), mapped with Kenneth French's SIC ranges. The rebuild matches the shared table for 99.76% of stock-months; the pipeline reads the shared table | CRSP. Shared by Alex Dickerson |

Some scripts query WRDS directly and keep only the processed result (for example the CRSP daily
returns behind `sigma.h5`). Those raw tables are not stored; the scripts listed below rebuild
the derived files from WRDS.

#### Derived data (constructed by the code in this package)
| File | Description | Built by | Underlying source |
|---|---|---|---|
| `sigma.h5` | Equity return volatility | `MakeSIGMA.py` | CRSP daily |
| `PROB.h5`, `PROB_agg.csv` | Default probability, computed in-house from the coefficients in `drcoefficients2021.xlsx` | `MakePROB.py` | CRSP, Compustat |
| `CS.h5` | Firm-level 5-year and 10-year credit spreads | `MakeCreditSpread.py` | `trace_29_04_2025.parquet`, `WRDS_MMN_Corrected_Data_2024_July.csv` |
| `_main_data_2.h5`, `_ret_quarterly_2.h5` | Firm-quarter panel and quarterly returns | `MakePortfolios_v2.py` | CRSP, Compustat |
| `industry_sorts.csv` | Value-weighted Fama–French 48 industry panel (the input to the correlation step) | `MakeSorts.py` | CRSP, Compustat |
| `AggShocks/Agg_shocks.csv` | Quarterly aggregate macro and financial shocks | `MakeAggShocks_v1.py` | Public macro sources (below) |
| `Estimates/`, `Estimates/length4/` | Correlation and block-bootstrap estimates that feed the tables | `Step2_MakeCorrelations_V4.R` | `industry_sorts.csv`, `Agg_shocks.csv` |
| `DataFile.mat` | Precomputed solutions of the calibrated two-tree model (equity and debt values, default boundaries, default probabilities, simulated paths, counterfactual values), ~2 GB. Read by `code/matlab/main.m` when `RECOMPUTE = false`; rebuilt from scratch when `RECOMPUTE = true` | `code/matlab/main.m` | None (model output; no external data) |

#### Public data
| File(s) | Source |
|---|---|
| `BAA10Y.csv`, `BAMLC0A0CM.csv` | FRED (Federal Reserve) |
| `Siccodes48.txt` (SIC ranges defining the Fama–French 48 industries; read by `MakeFF48.py`) | Kenneth French's data library |
| `FF48_industry.csv` (Fama–French 48 industry codes and short names; lookup table read by `Step2_MakeCorrelations_V4.R`) | Kenneth French's data library |
| `Market_CMDI.xlsx` | Published aggregate credit series (Corporate Bond Market Distress Index) |
| `AggShocks/` source files (INDPRO, UNRATE, FEDFUNDS from FRED; CFNAI real-time from the Chicago Fed; US Economic Policy Uncertainty; HKM intermediary factors; the liquidity series `liq_data_1962_2024.csv`; Jurado–Ludvigson–Ng macro/financial/real uncertainty; SPF mean GDP growth) | FRED and the respective authors' websites |

#### Comparison-only file
| File | Note |
|---|---|
| `campbelldefrisk_2021.sas7bdat` | Default-risk (CDR) series precomputed by Kevin Aretz, shared through Alex Dickerson. Used **only** in the validation block of `MakePROB.py` that cross-checks the in-house PROB against it (~97% match). Not an input to any result in the paper. |

### Access and licensing
CRSP, Compustat, IBES, TRACE, and Moody's data are subject to their license agreements. The files built
from them are provided to the journal's code and data editor for the purpose of verifying the
results. They are not for public redistribution, and a public release of this package would
exclude them. Researchers with the relevant WRDS subscriptions can rebuild them with the code in
`code/python/`. The bond data of Dickerson, Robotti, and Rossetti are distributed through
openbondassetpricing.com. Public series (FRED and authors' websites) are included under their terms.

## 3. Variable dictionaries
The data dictionaries are in `DATA_DICTIONARY.md`. For every dataset in `Data/` it lists the
variables used in the paper, with the names used in the code and the files and a one-line
description. It has three parts:

1. **Analysis data**, read by the code that produces the exhibits: `industry_sorts.csv`,
   `AggShocks/Agg_shocks.csv`, `PROB_agg.csv`, the public series behind Figure OA.5, the estimate
   files in `Estimates/`, and the model solutions in `DataFile.mat`.
2. **Intermediate firm-level files** built by the Python code: `raw_data.hdf`, `sigma.h5`,
   `PROB.h5`, `CS.h5`, `_ret_quarterly_2.h5`, `_main_data_2.h5`, and `iclink.pkl`.
3. **Third-party input files**: Compustat, the bond data, the industry tags, the default
   probability coefficients, and the macroeconomic source files.

The definitions of the firm variables follow Table OA.3 of the Online Appendix.

## 4. Computational requirements

### Software
- **MATLAB R2026a** for the theory exhibits, with the **Statistics and Machine Learning Toolbox**
  (`normrnd`, `unifrnd`, `prctile`) and the **Parallel Computing Toolbox** (`parfor`; the code still
  runs without it, just serially).
- **R 4.5.1** with the packages pinned in `renv.lock` (tidyverse, fixest, kableExtra, rhdf5, zoo,
  psych, broom, modelsummary, viridis, ggforce, ggrepel, cowplot, knitr, pander, gt). Installed via
  `renv` (see Environment setup below).
- **Python 3.11** with pandas, numpy, scipy, pyreadstat, duckdb, wrds, pandas-datareader, tqdm —
  pinned in `pyproject.toml` / `uv.lock`. Only needed for the full WRDS rebuild (Path B).
- **Pandoc ≥ 1.12.3** (we used 3.10) — a system tool `rmarkdown` needs to knit the exhibits.
- A **WRDS account** with CRSP, Compustat, IBES, and TRACE access — only for the full rebuild.

### Environment setup (do this first)
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

### Random seeds
The theory code fixes MATLAB's random number generator at the top of `main.m` with
`rng(0,'twister')`; the simulation block (`Simulation.m`) is its only source of randomness. The
block bootstrap in `Step2_MakeCorrelations_V4.R` uses seed = 123.

### Sample, key settings, and runtime
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

## 5. Programs/Code

### Package root and paths
Paths are centralized in `config.py` and `config.R`, which auto-detect the package root.
No editing is needed if you keep `config.py` / `config.R` at the package root. If R
auto-detection fails, set `ROOT` on the marked line in `config.R`.

### Theory component (MATLAB)
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
  and re-runs the simulation (~10 h, see Section 4), saves a fresh `Data/DataFile.mat`, then produces the
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

### Empirics: two ways to reproduce

#### Path A — From the shipped derived data (no WRDS needed)
The package ships the derived inputs, so you can regenerate **every empirical exhibit** without WRDS:

    Rscript master.R

This knits `code/r/main_empirics.Rmd`, writing the tables to `output/tables/`, Figure OA.5 to
`output/figures/`, and an HTML report to `output/main_empirics.html`. It reads the shipped
`Data/Estimates/` directly. To recompute those bootstrap estimates first (from
`Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv`; stationary block bootstrap,
~55 min, see Section 4), set `RUN_STEP2 <- TRUE` near the top of `master.R`.

#### Path B — Full rebuild from WRDS
1. Ensure WRDS credentials are configured. The third-party input files (bond data and industry
   tags, see Section 2) are already in `Data/`.
2. `python code/python/iclink.py` then `python code/python/Step1_PrepareAllData.py`
   (builds the firm/industry panels; ~1 h 25 min, see Section 4).
3. Continue with Path A (`Rscript master.R`, optionally with `RUN_STEP2 <- TRUE`).

`code/python/MakeFF48.py` is documentation only and is not run by `Step1_PrepareAllData.py`. It shows
how the shared industry table `Data/FF48_Stocks.h5` is constructed, rebuilds it from WRDS into
`Data/FF48_Stocks_WRDS.h5`, and prints a comparison (99.76% of stock-months agree). The pipeline reads
the shared table.

### Empirics: exhibit and output file
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

### Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- The log files in `output/log/` record our full runs: `matlab_run.log` was produced with
  `RECOMPUTE = true` and `master_R.log` with `RUN_STEP2 <- TRUE`. The package ships with both flags
  off, so the default run reads the saved model solutions and bootstrap estimates and reproduces the
  same exhibits.
- Contact: Kristoffer Glover (Kristoffer.Glover@uts.edu.au), Lucie Lu (lucie.lu@unimelb.edu.au).
