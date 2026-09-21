# Data Availability Statement

The empirical analysis uses data from **WRDS** (CRSP, Compustat, IBES), **FINRA TRACE**
(corporate bond transactions, via the Dickerson–Robotti–Rossetti WRDS dataset), and public
sources (FRED and authors' websites). WRDS, CRSP, Compustat, and TRACE data are licensed and
**cannot be redistributed**; researchers with the relevant subscriptions can regenerate them.

This package ships the **derived/constructed data** needed to reproduce every table and figure
without WRDS (Path A in `README.md`), plus the public source files. The large raw WRDS/TRACE
pulls are not shipped (Path B rebuilds them from WRDS).

## Included in this package (`Data/`)

### Derived data (constructed by the code in this package)
| File | Description | Underlying source |
|---|---|---|
| `industry_sorts.csv` | Value-weighted FF48 industry panel (the Step 2 input) | CRSP + Compustat |
| `_main_data_2.h5`, `_ret_quarterly_2.h5` | Firm-quarter panel and quarterly returns | CRSP + Compustat |
| `PROB.h5`, `PROB_agg.csv` | Default probability (computed in-house by `MakePROB.py`) | CRSP/Compustat + published coefficients |
| `sigma.h5` | Equity return volatility | CRSP daily |
| `CS.h5` | Firm-level 5Y/10Y credit spreads | FINRA TRACE |
| `iclink.pkl` | CRSP–IBES link table | CRSP + IBES |
| `FF48_Stocks.h5` | Firm-month Fama–French 48 industry tags, January 1960 to December 2022 (input to `MakePortfolios_v2.py`). Shared by A. Dickerson. `code/python/MakeFF48.py` documents its construction and rebuilds it from WRDS: CRSP stock-months (`crsp.msf_v2`) with each stock's SIC code as of end-2022 (`crsp.stocknames`), mapped with Kenneth French's SIC ranges. The rebuild matches the shared table for 99.76% of stock-months; the pipeline reads the shared table | CRSP |
| `Estimates/`, `Estimates/length4/` | Correlation + block-bootstrap outputs feeding the tables | (this package's R code) |
| `AggShocks/Agg_shocks.csv` | Quarterly aggregate macro/financial shocks | public macro sources (below) |
| `DataFile.mat` | Precomputed solutions of the calibrated two-tree model (equity and debt values, default boundaries, default probabilities, simulated paths, counterfactual values), ~2 GB. Read by `code/matlab/main.m` when `RECOMPUTE = false`; rebuilt from scratch when `RECOMPUTE = true` | None (model output of this package's MATLAB code; no external data) |

### Public data (redistributable; included for convenience)
| File(s) | Source |
|---|---|
| `BAA.csv`, `BAA10Y.csv`, `BAMLC0A0CM.csv`, `USREC.csv`, `USRECP.csv` | FRED (Federal Reserve) |
| `drcoefficients2021.xlsx` | Published default-risk (CDR) logit coefficients |
| `Siccodes48.txt` (SIC ranges defining the Fama–French 48 industries; read by `MakeFF48.py`) | Kenneth French's data library |
| `FF48_industry.csv` (Fama–French 48 industry codes and short names; lookup table read by `Step2_MakeCorrelations_V4.R`) | Kenneth French's data library |
| `Market_CMDI.xlsx`, `Moodys_NB_QTRLy_US_Defaults_US_21072020.xlsx` | Published aggregate default / credit series |
| `AggShocks/` source files (INDPRO, UNRATE, FEDFUNDS from FRED; CFNAI real-time from the Chicago Fed; US Economic Policy Uncertainty; HKM intermediary factors; the liquidity series `liq_data_1962_2024.csv`; Jurado–Ludvigson–Ng macro/financial/real uncertainty; SPF mean GDP growth) | FRED and the respective authors' websites |

### Comparison-only file
| File | Note |
|---|---|
| `campbelldefrisk_2021.sas7bdat` | Pre-computed CDR (shared by A. Dickerson). Used **only** in the "Compare with Kevin" validation block of `MakePROB.py` to cross-check the in-house PROB (~97% match). Not an input to the final results. Confirm redistribution rights before public posting. |

## NOT included — obtain from WRDS / source (Path B full rebuild)
| File | What it is | Where to obtain |
|---|---|---|
| `raw_data.hdf` | Merged CRSP–Compustat firm panel | Built by `MakeMainDataFile_V1.py` from WRDS |
| `comp_quarter.hdf`, `comp_annual.h5` | Compustat fundamentals | WRDS Compustat |
| `trace_29_04_2025.parquet` | Corporate bond transactions | FINRA TRACE / Dickerson–Robotti–Rossetti WRDS dataset. This snapshot was shared directly by Alex Dickerson (author of the Open Source Bond Asset Pricing data) ahead of its public release; confirm redistribution rights before posting publicly. |
| `WRDS_MMN_Corrected_Data_2024_July.csv` | MMN-corrected bond data | WRDS |

## Licensing
CRSP, Compustat, and FINRA TRACE data are subject to their respective license agreements and may
not be redistributed. Public series (FRED and authors' websites) are included under their terms.
Confirm redistribution rights for the comparison file before posting publicly.

Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
