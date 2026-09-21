# CLAUDE.md — EGJL "Excess Default Correlations" Replication Package

This is the cleaned replication package for the empirical component of the paper
(Management Science, R2). It was assembled by copying the canonical scripts from the
working repo and keeping only the latest version of each pipeline step.

## Layout
```
config.py / config.R     central paths (auto-detect package root; no hard-coded user paths)
code/python/             data build (iclink → Step1 driver → 7 Make*.py)
code/r/                  correlations + exhibits (functions, Step2 V4, Step3 V7, PROB V2.1)
Data/                    flat data folder the scripts read/write (mirrors the original layout)
  Estimates/ + length4/  R correlation + bootstrap outputs that feed the tables
  AggShocks/             macro shock sources + Agg_shocks.csv
output/tables/           final .tex tables
output/figures/          final .png figures
README.md                follows the MNSC readme template: overview, data availability and provenance,
                         variable dictionaries, computational requirements, programs/code
```

## Pipeline (canonical versions only)
1. **Build — Python** `code/python/Step1_PrepareAllData.py` runs, in order:
   `MakeMainDataFile_V1 → MakeSIGMA → MakePROB → MakeCreditSpread → MakePortfolios_v2 →
   MakeSorts → MakeAggShocks`. Needs WRDS (CRSP/Compustat/IBES) + FINRA TRACE; `iclink.py`
   must run first to create `Data/iclink.pkl`. PROB is computed in-house by `MakePROB.py`
   (predictors × `drcoefficients2021.xlsx` coefficients → logit; coefficients originally from
   Jens Hilscher, shared by Kevin Aretz).
2. **Correlations — R** `code/r/Step2_MakeCorrelations_V4.R` (sources `functions_V4.1.R`)
   reads `Data/industry_sorts.csv`, `Data/FF48_industry.csv`, `Data/AggShocks/Agg_shocks.csv`
   → estimates in `Data/Estimates/` and `Data/Estimates/length4/`.
3. **Exhibits — R Markdown** `code/r/Step3_Industry_correlation_V7.Rmd` → tables + the leverage
   figure; `code/r/PROB_Goodness_of_Fit_V2.1.Rmd` → the 8 PROB-fit figures.

## Two ways to reproduce (see README for commands)
- **Full (needs WRDS + TRACE):** config → Step 1 → Step 2 → Step 3.
- **From shipped derived data (no WRDS):** Step 2 → Step 3 + PROB Rmd regenerate every table and
  figure from `Data/` as shipped.

## Notes
- Paths come from `config.py` / `config.R` — do not re-introduce hard-coded absolute paths.
- `campbelldefrisk_2021.sas7bdat` is shipped only for the PROB-vs-Kevin comparison block in
  `MakePROB.py`; it is not an input to the final PROB.
- Everything in `Data/` ships to the journal's data editor, including the raw WRDS/TRACE files
  (`raw_data.hdf`, `comp_*`, `trace_*`, `WRDS_MMN_*`, `FF48_Stocks.h5`), frozen at the 25 June 2026
  build. A public release would exclude the licensed files. See README Section 2.
