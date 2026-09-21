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
| `.Rprofile` | Hidden file that activates the `renv` environment when R starts in the package folder |
| `pyproject.toml`, `uv.lock`, `requirements.txt`, `environment.yml` | Python environment |
| `.python-version` | Hidden file that pins Python 3.11 for `uv` |

How to proceed from beginning to end:

1. Set up the software environment (Section 4).
2. Theory exhibits: run `code/matlab/main.m` (Section 5). By default it reads the precomputed model
   solutions in `Data/DataFile.mat` and takes about 25 to 30 minutes.
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

The Python scripts obtain the WRDS data by querying the WRDS server directly, for January 1986 to
December 2024. They need a WRDS subscription that covers CRSP, Compustat, and I/B/E/S, and the
queries themselves are in the scripts (`MakeMainDataFile_V1.py`, `MakeSIGMA.py`, `MakePROB.py`, and
`iclink.py`).

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
| `Moodys_NB_QTRLy_US_Defaults_US_21072020.xlsx` | Quarterly number of U.S. corporate defaults by industry, 1970 onwards (extract dated 21 July 2020). The total across industries (column `ALL`) is used in Figure OA.5 (`main_empirics.Rmd`) | Moody's (proprietary). Provided by Alexandre Jeanneret |
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
These files were downloaded by hand from the websites below; no code is needed to obtain them.
"Retrieved" is the date of the file in `Data/`. Files in `AggShocks/` are read by
`MakeAggShocks_v1.py`.

| File | Content | Source | Retrieved | Coverage |
|---|---|---|---|---|
| `BAA10Y.csv` | Moody's Baa corporate bond yield minus the 10-year Treasury yield, daily | FRED, https://fred.stlouisfed.org/series/BAA10Y | 21 Oct 2025 | Jan 1986 to Oct 2025 |
| `BAMLC0A0CM.csv` | ICE BofA U.S. corporate index option-adjusted spread, daily | FRED, https://fred.stlouisfed.org/series/BAMLC0A0CM | 30 Sep 2025 | Dec 1996 to Sep 2025 |
| `Market_CMDI.xlsx` | Corporate Bond Market Distress Index, weekly | Federal Reserve Bank of New York, https://www.newyorkfed.org/research/policy/cmdi | 30 Sep 2025 | Jan 2005 to Sep 2025 |
| `AggShocks/INDPRO.csv`, `AggShocks/UNRATE.csv`, `AggShocks/FEDFUNDS.csv` | Industrial production index, unemployment rate, effective federal funds rate, monthly | FRED, https://fred.stlouisfed.org/series/INDPRO (and `/UNRATE`, `/FEDFUNDS`) | 2 Jul 2025 | Start of each series to mid-2025 |
| `AggShocks/liq_data_1962_2024.csv` | Aggregate liquidity series of Pastor and Stambaugh (2003), monthly | Lubos Pastor's website, https://faculty.chicagobooth.edu/lubos-pastor/data | 2 Jul 2025 | Aug 1962 to Dec 2024 |
| `AggShocks/cfnai-realtime-3-xlsx.xlsx` | Chicago Fed National Activity Index, real-time vintages, monthly | Federal Reserve Bank of Chicago, https://www.chicagofed.org/research/data/cfnai/current-data | 2 Jul 2025 | Mar 1967 to Dec 2024 (vintage of December 2024) |
| `AggShocks/US_Policy_Uncertainty_Data.xlsx` | News-based U.S. economic policy uncertainty index of Baker, Bloom, and Davis, monthly | https://www.policyuncertainty.com/us_monthly.html | 2 Jul 2025 | Jan 1900 to Jun 2025 |
| `AggShocks/MacroFinanceUncertainty_202506Update/` (three files) | Macroeconomic, real, and financial uncertainty indexes of Jurado, Ludvigson, and Ng, monthly | Sydney Ludvigson's website, https://www.sydneyludvigson.com/macro-and-financial-uncertainty-indexes | June 2025 update | Jul 1960 to Apr 2025 |
| `AggShocks/meanGrowth.xlsx` | Survey of Professional Forecasters, mean forecasts of growth rates, quarterly | Federal Reserve Bank of Philadelphia, https://www.philadelphiafed.org/surveys-and-data/real-time-data-research/mean-forecasts | 2 Jul 2025 | 1968Q4 to 2025Q2 |
| `AggShocks/HKM_Factors.csv` | Intermediary capital ratio and risk factor of He, Kelly, and Manela (2017), quarterly | Zhiguo He's website, https://zhiguohe.net/data-and-empirical-patterns/intermediary-capital-ratio-and-risk-factor/ | 3 Nov 2024 | 1970Q1 to 2024Q2 |
| `Siccodes48.txt` | SIC ranges that define the Fama–French 48 industries; read by `MakeFF48.py` | Kenneth French's data library, https://mba.tuck.dartmouth.edu/pages/faculty/ken.french/data_library.html | 21 Sep 2026 | not dated |
| `FF48_industry.csv` | Fama–French 48 industry codes and short names; lookup table read by `Step2_MakeCorrelations_V4.R` | Kenneth French's data library (same page) | Feb 2024 | not dated |

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
The runs reported in the paper and in `output/log/` were made on **macOS 26.5** (Tahoe, build 25F71)
on an Apple M5 Pro (arm64).

- **MATLAB R2026a** (version 26.1, Update 3) for the theory exhibits, with the **Statistics and
  Machine Learning Toolbox** 26.1 (`normrnd`, `unifrnd`, `prctile`) and the **Parallel Computing
  Toolbox** 26.1 (`parfor`; the code still runs without it, just serially). The code was developed
  and tested on R2026a. It uses the figure `theme` function, which older MATLAB releases do not have.
- **R 4.5.1**. The packages loaded by the code, with the versions we used:

  | Package | Version | Package | Version |
  |---|---|---|---|
  | tidyverse (dplyr 1.1.4, tidyr 1.3.2, purrr 1.2.0, ggplot2 4.0.1) | 2.0.0 | psych | 2.5.6 |
  | fixest | 0.13.2 | broom | 1.0.9 |
  | kableExtra | 1.4.0 | modelsummary | 2.5.0 |
  | rhdf5 (Bioconductor) | 2.52.1 | viridis | 0.6.5 |
  | zoo | 1.8-15 | ggforce | 0.5.0 |
  | readxl | 1.4.5 | ggrepel | 0.9.6 |
  | openxlsx | 4.2.8 | cowplot | 1.2.0 |
  | stringi | 1.8.7 | gt | 1.0.0 |
  | knitr | 1.50 | pander | 0.6.6 |
  | rmarkdown | 2.29 | renv | 1.2.3 |

  The block bootstrap also uses the `parallel` package, which is part of R. `renv.lock` records
  these versions together with the versions of all their dependencies (161 packages in total), and
  `renv::restore()` installs exactly those versions (see Environment setup below).
- **Python 3.11** (we used 3.11.15), only needed for the full WRDS rebuild (Path B). The packages
  used by the code, with the versions we used:

  | Package | Version | Used for |
  |---|---|---|
  | pandas | 2.2.2 | data handling |
  | numpy | 1.26.4 | numerical routines |
  | scipy | 1.12.0 | statistics |
  | wrds | 3.2.0 | WRDS connection (CRSP, Compustat, IBES) |
  | tables | 3.10.1 | reading and writing the `.h5` / `.hdf` files |
  | duckdb | 1.3.2 | reading the TRACE parquet file |
  | pyarrow | 19.0.0 | parquet support |
  | pyreadstat | 1.2.7 | reading the `.sas7bdat` file |
  | openpyxl | 3.1.2 | reading the `.xlsx` files |
  | pandas-datareader | 0.10.0 | loaded by the build scripts |
  | fuzzywuzzy | 0.18.0 | company name matching in `iclink.py` |
  | python-dateutil | 2.8.2 | date arithmetic |
  | tqdm | 4.66.4 | progress bars |
  | matplotlib | 3.9.0 | loaded by `MakeCreditSpread.py` |

  The same versions are pinned in `pyproject.toml`, `uv.lock`, and `requirements.txt`, and the
  setup commands below install exactly those versions.
- **Pandoc ≥ 1.12.3** (we used 3.10), a system tool `rmarkdown` needs to knit the exhibits.
- A **WRDS account** with CRSP, Compustat, and I/B/E/S access, only for the full rebuild. The bond
  data are not pulled from WRDS; they ship in `Data/` (see Section 2).

### Environment setup (do this first)
A fresh clone ships the **lockfiles, not the packages**, so build the environment before running anything.

**R packages** (exact versions from `renv.lock`), from the package root:

    Rscript -e 'if (!requireNamespace("renv", quietly=TRUE)) install.packages("renv"); renv::restore()'

`renv::restore()` installs every package at its locked version into a project-local library, and warns
if your R version differs from the lock. When R starts in the package folder it may print
"The project is out-of-sync -- use `renv::status()` for details." This is expected and harmless:
`renv.lock` also records a few packages that the code does not load, and `renv` reports them. All
packages that the code loads are installed at their locked versions. (Quick alternative, *not* version-pinned: `Rscript install_R_packages.R`.)

**Pandoc** (required to knit the exhibits; command-line `Rscript` has no bundled pandoc):

    brew install pandoc          # macOS   (Linux: sudo apt-get install pandoc;  conda: conda install -c conda-forge pandoc)

Verify with `pandoc --version`. If R is already open, restart it (or
`Sys.setenv(RSTUDIO_PANDOC = dirname(Sys.which("pandoc")))`).

**Python** (only for Path B, the full WRDS rebuild):

    uv sync                                  # from pyproject.toml + uv.lock (exact versions)
    # or:  pip install -r requirements.txt
    # or:  conda env create -f environment.yml && conda activate egjl-replication

### Random seeds
The theory code fixes MATLAB's random number generator at the top of `main.m` with
`rng(0,'twister')`; the simulation block (`Simulation.m`) is its only source of randomness. The
block bootstrap in `Step2_MakeCorrelations_V4.R` uses seed = 123.

### Sample, key settings, and runtime
Sample: 1987-06-30 to 2023-12-31. Block bootstrap: block length 4 quarters, B = 1000, seed = 123.

**Approximate runtime** (MacBook Pro, Apple M5 Pro, 18 cores, 64 GB). The times are taken from the
log files in `output/log/`.

| Stage | Script | Runtime |
|---|---|---|
| Theory, default (`RECOMPUTE=false`): tables and figures from the saved solutions | `code/matlab/main.m` | ~25 to 30 min |
| Theory: full solve + simulation (`RECOMPUTE=true`) | `code/matlab/main.m` | ~10 h (10 h 3 min); 18 cores for the PDE solves, the simulation phase is single-threaded |
| Empirics Path A, default: knit exhibits | `master.R` (`main_empirics.Rmd`) | under a minute |
| Empirics Step 2: block bootstrap (B = 1000), `RUN_STEP2 <- TRUE` | `Step2_MakeCorrelations_V4.R` | ~55 min (capped at 15 cores, hardcoded for reproducibility) |
| Empirics Path B: full WRDS rebuild | `Step1_PrepareAllData.py` | ~55 min, of which `MakeSIGMA.py` (CRSP daily returns) ~37 min and `MakeMainDataFile_V1.py` ~14 min; the other scripts take under 2 min each |
| Documentation of the industry table | `MakeFF48.py` | ~2 min |

The theory `RECOMPUTE=false` path loads `Data/DataFile.mat` (~2 GB) instead of re-solving, which skips
the multi-hour solve and simulation. It still computes the statistics of the tables from the
simulated economies and draws all figures; in our full run this stage took 26 minutes.

Step 2 and the full Python rebuild are only needed to regenerate the estimates or the
firm/industry panels from scratch. Both depend on the number of cores and on the load of the WRDS
server, so the time can differ across machines and days.

## 5. Programs/Code

### Package root and paths
All code uses relative paths that point to files inside the package, so no path needs editing.
The paths are centralized in `config.py` and `config.R`, which must stay at the package root.

- **Python:** `config.py` derives the package root from its own location, so the scripts work from
  any working directory.
- **R:** `config.R` defines the paths relative to the package root, so R must be started from the
  package root. `master.R` checks this and stops with a message otherwise. `main_empirics.Rmd` also
  knits correctly when opened from `code/r/`.
- **MATLAB:** `main.m` finds its own folder and reads and writes relative to it, so it runs from any
  working directory.

### Theory component (MATLAB)
The model exhibits are produced by the MATLAB code in `code/matlab/` (author: Kristoffer Glover).
Per-function documentation is in `code/matlab/readme.txt`.

**Run:** open `code/matlab/main.m` in MATLAB and run it (it sets its own working directory, so the
helper functions resolve from any starting folder). Alternatively, run it from a terminal without
opening the MATLAB desktop:

    cd code/matlab
    matlab -batch "main"

(On macOS the `matlab` command is inside the application, for example
`/Applications/MATLAB_R2026a.app/bin/matlab`.) The script writes Tables 1–2, OA.1–OA.2, and OA.10
as `.tex` files to `output/tables/`, writes Figures 2–6 and OA.1–OA.4 (`.pdf`/`.eps`) to
`output/figures/`, and prints the asset-pricing moment values reported in Sections 2.1 and 3.3.
The console output is saved to `output/log/matlab_run.log`. Calibration parameters are those in
Sections 2.1, 3.3, and 2.6.

Two ways to run, set by the `RECOMPUTE` flag at the top of `main.m`:

- **Path A: read the precomputed solutions (fast, the default).** With `RECOMPUTE = false` (the
  default), `main.m` loads the model solutions from `Data/DataFile.mat` and produces all theory
  exhibits without re-solving (~25 to 30 min instead of ~10 h). Requires `Data/DataFile.mat` (~2 GB),
  shipped with the package.
- **Path B: recompute from scratch (slow).** Set `RECOMPUTE = true`: `main.m` re-solves the model
  and re-runs the simulation (~10 h, see Section 4), saves a fresh `Data/DataFile.mat`, then produces the
  exhibits.

All theory exhibits are produced by `code/matlab/main.m`.

| Paper exhibit | Output file |
|---|---|
| Table 1: default risk correlation and rollover risk | `output/tables/Table1_corr_by_maturity.tex` |
| Table 2: co-movement in default risk and equity moments from simulated economies | `output/tables/Table2_histograms.tex` |
| Figure 2: equilibrium asset pricing quantities | `output/figures/Fig2.eps` |
| Figure 3: optimal default policy in a two-tree economy | `output/figures/Fig3.eps` |
| Figure 4: excess default risk correlation by level of fundamental correlation | `output/figures/Fig4.pdf` |
| Figure 5: co-movement in default probabilities and in credit spreads | `output/figures/Fig5.pdf` |
| Figure 6: co-movement in equity volatility and in equity risk premium | `output/figures/Fig6.pdf` |
| Table OA.1: default risk correlation by borrower characteristics | `output/tables/TableOA1_by_characteristics.tex` |
| Table OA.2: co-movement in simulated economies, excluding defaults | `output/tables/TableOA2_histograms_nodefault.tex` |
| Table OA.10: sovereign debt spillover, case study | `output/tables/TableOA10_CPE_spillover.tex` |
| Figure OA.1: equilibrium asset pricing quantities, counterfactual | `output/figures/FigOA1.eps` |
| Figure OA.2: distribution of asset pricing moments across simulations | `output/figures/FigOA2.pdf` |
| Figure OA.3: distribution of default risk correlations, model vs. counterfactual case | `output/figures/FigOA3.pdf` |
| Figure OA.4: distribution of the correlations in asset pricing moments | `output/figures/FigOA4.pdf` |

The asset-pricing moment values reported in Sections 2.1 and 3.3 are printed to the MATLAB console
and recorded in `output/log/matlab_run.log`.

In the paper, Panel A of Figure 3 carries two arrows and the label "Distance-to-default". They are an
illustration added by hand and are not drawn by the code. `Fig3.eps` contains all plotted data of the
figure.

Key functions (full list in `code/matlab/readme.txt`): `TWOTREEY.m` (debt and equity value with the
optimal default boundary, via the PSOR finite-difference method), `CorrEst.m` (distance-to-default
correlation, Equation 11), `Simulation.m` and `DefaultTimes.m` (simulated economies and default
rates), `PROBDEF.m` (default probabilities under P and Q), and `CSpread.m` / `CPE1D.m` (equilibrium
credit spreads, Table OA.10).

### Empirics: two ways to reproduce

#### Path A: from the shipped derived data (no WRDS needed)
The package ships the derived inputs, so you can regenerate **every empirical exhibit** without WRDS:

    Rscript master.R

This knits `code/r/main_empirics.Rmd`, writing the tables to `output/tables/`, Figure OA.5 to
`output/figures/`, and an HTML report to `output/main_empirics.html`. It reads the shipped
`Data/Estimates/` directly. To recompute those bootstrap estimates first (from
`Data/industry_sorts.csv` + `Data/AggShocks/Agg_shocks.csv`; stationary block bootstrap,
~55 min, see Section 4), set `RUN_STEP2 <- TRUE` near the top of `master.R`.

#### Path B: full rebuild from WRDS
1. Set up WRDS access. Open `config.py` and set `wrds_username` to your own WRDS username (it
   ships with the authors' username). Store your WRDS password in `~/.pgpass` so that the scripts can
   connect without a prompt; the `wrds` package creates this file for you when you run, once,

       python -c "import wrds; wrds.Connection(wrds_username='your_username').create_pgpass_file()"

   The build runs the scripts non-interactively, so it stops at the first WRDS call if the password
   is not stored. The third-party input files (bond data and industry tags, see Section 2) are
   already in `Data/`.
2. Activate the Python environment of Section 4, then run the driver from the package root:

       python code/python/Step1_PrepareAllData.py

   The driver starts each script with the command `python`, so that command must point to the
   environment that has the packages installed. With `uv` this is done in one step by
   `uv run python code/python/Step1_PrepareAllData.py`; with a virtual environment or conda,
   activate it first (`source .venv/bin/activate` or `conda activate egjl-replication`). The driver
   runs, in order, `iclink.py`, `MakeMainDataFile_V1.py`, `MakeSIGMA.py`, `MakePROB.py`,
   `MakeCreditSpread.py`, `MakePortfolios_v2.py`, `MakeSorts.py`, and `MakeAggShocks_v1.py`, stops
   if one of them fails, and saves the console output to `output/log/step1_build.log`
   (~55 min, see Section 4).
3. Continue with Path A (`Rscript master.R`, optionally with `RUN_STEP2 <- TRUE`).

`code/python/MakeFF48.py` is documentation only and is not run by `Step1_PrepareAllData.py`. It shows
how the shared industry table `Data/FF48_Stocks.h5` is constructed, rebuilds it from WRDS into
`Data/FF48_Stocks_WRDS.h5`, and prints a comparison (99.76% of stock-months agree). The pipeline reads
the shared table.

### Empirics: exhibit and output file
All empirical exhibits are produced by `code/r/main_empirics.Rmd` (run via `master.R`).

| Paper exhibit | Output file |
|---|---|
| Table 3: excess correlations across industries | `output/tables/Table3_Excess_Corr_Industries.tex` |
| Table OA.4: firm fundamentals (unrelated pairs) | `output/tables/TableOA4_Funda_Corr_Unrelated.tex` |
| Table OA.5: default risk & equity moments (unrelated pairs) | `output/tables/TableOA5_DefRisk_Equity_Corr_Unrelated.tex` |
| Table OA.6: firm fundamentals robustness | `output/tables/TableOA6_Funda_Corr_Unrelated_Robustness.tex` |
| Table OA.7: total & excess corr, unrelated, robustness | `output/tables/TableOA7_Total_Excess_Corr_Unrelated_Robustness.tex` |
| Table OA.8: total & excess corr, all industries, robustness | `output/tables/TableOA8_Total_Excess_Corr_All_Robustness.tex` |
| Table OA.9: size & book-leverage terciles | `output/tables/TableOA9_Excess_Corr_Size_BookLev_Terciles.tex` |
| Figure OA.5: PROB vs. fitted value | `output/figures/FigureOA5_PROB_fit.png` |

### Notes
- The pre-shipped `output/tables` and `output/figures` are the paper's exact exhibits; reproduction
  should overwrite them with identical content.
- The log files in `output/log/` record our full runs: `matlab_run.log` was produced with
  `RECOMPUTE = true` and `master_R.log` with `RUN_STEP2 <- TRUE`. The package ships with both flags
  off, so the default run reads the saved model solutions and bootstrap estimates and reproduces the
  same exhibits.
- **Running the code overwrites these log files.** `main.m` replaces `matlab_run.log`, `master.R`
  replaces `master_R.log`, and `Step1_PrepareAllData.py` replaces `step1_build.log`, each with the
  log of the new run. To keep our logs for comparison, copy the folder `output/log/` before running.
- Contact: Kristoffer Glover (Kristoffer.Glover@uts.edu.au), Lucie Lu (lucie.lu@unimelb.edu.au).
