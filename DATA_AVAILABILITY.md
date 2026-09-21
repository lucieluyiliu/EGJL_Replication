# Data Availability Statement

This paper relies on data, and all data necessary to reproduce the results of the paper are
included in the replication package provided to the journal's code and data editor. This
statement describes every dataset used, where it comes from, and how it can be obtained or rebuilt.

The theory component uses no external data. The empirical analysis uses data from **WRDS**
(CRSP, Compustat, IBES), corporate bond data from the **Open Source Bond Asset Pricing** project
(Dickerson, Robotti, and Rossetti), and public sources (FRED and authors' websites).

## Data vintage
WRDS revises its databases continuously, so a fresh download does not return exactly the data
behind the paper. The WRDS extracts in `Data/` are frozen as of the build run of 25 June 2026
that produced the results in the paper. The package therefore ships this vintage, together with
the code that rebuilds every extract from WRDS (`code/python/`, Path B in `README.md`).
Researchers with WRDS access can rerun that code; results from a later vintage can differ slightly
from the published ones.

## Included in this package (`Data/`)

### Raw data
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

### Derived data (constructed by the code in this package)
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

### Public data
| File(s) | Source |
|---|---|
| `BAA.csv`, `BAA10Y.csv`, `BAMLC0A0CM.csv`, `USREC.csv`, `USRECP.csv` | FRED (Federal Reserve) |
| `Siccodes48.txt` (SIC ranges defining the Fama–French 48 industries; read by `MakeFF48.py`) | Kenneth French's data library |
| `FF48_industry.csv` (Fama–French 48 industry codes and short names; lookup table read by `Step2_MakeCorrelations_V4.R`) | Kenneth French's data library |
| `Market_CMDI.xlsx` | Published aggregate credit series (Corporate Bond Market Distress Index) |
| `AggShocks/` source files (INDPRO, UNRATE, FEDFUNDS from FRED; CFNAI real-time from the Chicago Fed; US Economic Policy Uncertainty; HKM intermediary factors; the liquidity series `liq_data_1962_2024.csv`; Jurado–Ludvigson–Ng macro/financial/real uncertainty; SPF mean GDP growth) | FRED and the respective authors' websites |

### Comparison-only file
| File | Note |
|---|---|
| `campbelldefrisk_2021.sas7bdat` | Default-risk (CDR) series precomputed by Kevin Aretz, shared through Alex Dickerson. Used **only** in the validation block of `MakePROB.py` that cross-checks the in-house PROB against it (~97% match). Not an input to any result in the paper. |

## Access and licensing
CRSP, Compustat, IBES, TRACE, and Moody's data are subject to their license agreements. The files built
from them are provided to the journal's code and data editor for the purpose of verifying the
results. They are not for public redistribution, and a public release of this package would
exclude them. Researchers with the relevant WRDS subscriptions can rebuild them with the code in
`code/python/`. The bond data of Dickerson, Robotti, and Rossetti are distributed through
openbondassetpricing.com. Public series (FRED and authors' websites) are included under their terms.

Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
