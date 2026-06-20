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
| `industry_sorts.csv`, `_industry_sorts_2.h5` | Value-weighted FF48 industry panels (the Step 2 input) | CRSP + Compustat |
| `_main_data_2.h5`, `_ret_quarterly_2.h5` | Firm-quarter panel and quarterly returns | CRSP + Compustat |
| `PROB.h5`, `PROB_agg.csv` | Default probability (computed in-house by `MakePROB.py`) | CRSP/Compustat + published coefficients |
| `sigma.h5` | Equity return volatility | CRSP daily |
| `CS.h5`, `firm_mat.h5` | Industry credit spreads / firm debt maturity | FINRA TRACE |
| `iclink.pkl` | CRSP–IBES link table | CRSP + IBES |
| `Estimates/`, `Estimates/length4/` | Correlation + block-bootstrap outputs feeding the tables | (this package's R code) |
| `AggShocks/Agg_shocks.csv` | Quarterly aggregate macro/financial shocks | public macro sources (below) |

### Public data (redistributable; included for convenience)
| File(s) | Source |
|---|---|
| `BAA.csv`, `BAA10Y.csv`, `BAMLC0A0CM.csv`, `USREC.csv`, `USRECP.csv` | FRED (Federal Reserve) |
| `drcoefficients2021.xlsx` | Published default-risk (CDR) logit coefficients |
| `Market_CMDI.xlsx`, `Moodys_NB_QTRLy_US_Defaults_US_21072020.xlsx` | Published aggregate default / credit series |
| `AggShocks/` source files (CFNAI, EPU, INDPRO, UNRATE, FEDFUNDS, HKM factors, Pastor–Stambaugh and other liquidity, Jurado et al. uncertainty, SPF mean growth, VXOCLS, …) | FRED and the respective authors' websites |

### Comparison-only file
| File | Note |
|---|---|
| `campbelldefrisk_2021.sas7bdat` | Pre-computed CDR (shared by A. Dickerson). Used **only** in the "Compare with Kevin" validation block of `MakePROB.py` to cross-check the in-house PROB (~97% match). Not an input to the final results. Confirm redistribution rights before public posting. |

## NOT included — obtain from WRDS / source (Path B full rebuild)
| File | What it is | Where to obtain |
|---|---|---|
| `raw_data.hdf` | Merged CRSP–Compustat firm panel | Built by `MakeMainDataFile_V1.py` from WRDS |
| `comp_quarter.hdf`, `comp_annual.h5` | Compustat fundamentals | WRDS Compustat |
| `trace_29_04_2025.parquet` | Corporate bond transactions | FINRA TRACE / Dickerson–Robotti–Rossetti WRDS dataset |
| `WRDS_MMN_Corrected_Data_2024_July.csv` | MMN-corrected bond data | WRDS |
| `FF48_Stocks.h5` | Firm-level FF48 industry tags | Shared by A. Dickerson |
| `monthly_vol.csv.gzip`, `monthly_mom.csv.gzip` | Monthly volatility / momentum factor data | Shared by A. Dickerson (WRDS-derived) |

## Licensing
CRSP, Compustat, and FINRA TRACE data are subject to their respective license agreements and may
not be redistributed. Public series (FRED and authors' websites) are included under their terms.
Confirm redistribution rights for the comparison file before posting publicly.

Contact: Lucie Lu (lucie.lu@unimelb.edu.au).
