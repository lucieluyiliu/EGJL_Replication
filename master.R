## ============================================================================
## MASTER SCRIPT (analysis) — EGJL "Excess Default Correlations" replication
##
## Path A (no WRDS): regenerate every empirical exhibit from the shipped derived
## data in Data/. Run from the package ROOT:
##
##     Rscript master.R
##
## Produces in output/:  Table 3, Tables OA.4-OA.9 (output/tables/),
##                       Figure OA.4 (output/figures/), and main_empirics.html.
## (Full rebuild from WRDS is Path B — see README.md / code/python/Step1_PrepareAllData.py.)
## ============================================================================

## Must be run from the package root (relative paths, MNSC item 13).
if (!file.exists("config.R"))
  stop("Run this from the package root: setwd('<package root>'); source('master.R').")

root <- normalizePath(".")

## --- Optional: regenerate the bootstrap estimates in Data/Estimates/ ---------
## The package ships these (read directly by the exhibits). Set TRUE to recompute
## them from Data/industry_sorts.csv (stationary block bootstrap; ~hours).
RUN_STEP2 <- FALSE
if (RUN_STEP2) {
  message(">> Step 2: correlations + block bootstrap ...")
  source("code/r/Step2_MakeCorrelations_V4.R", chdir = FALSE)
}

## --- Empirical exhibits: Table 3, Tables OA.4-OA.9, Figure OA.4 --------------
message(">> Building empirical exhibits (main_empirics.Rmd) ...")
rmarkdown::render("code/r/main_empirics.Rmd",
                  knit_root_dir = root, output_dir = "output")

message("Done. Tables -> output/tables/ , figures -> output/figures/ , report -> output/main_empirics.html")
