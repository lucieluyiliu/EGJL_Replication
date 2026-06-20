## ============================================================================
## MASTER SCRIPT (analysis) — EGJL "Excess Default Correlations" replication
##
## Path A (no WRDS): regenerate every table and figure from the shipped derived
## data in Data/. Run from the package ROOT:
##
##     Rscript master.R
##
## (Full rebuild from WRDS is Path B — see README.md / run code/python/Step1_PrepareAllData.py.)
## ============================================================================

## Must be run from the package root (relative paths, MNSC item 13).
if (!file.exists("config.R"))
  stop("Run this from the package root: setwd('<package root>'); source('master.R').")

root <- normalizePath(".")

## --- Optional: regenerate the bootstrap estimates in Data/Estimates/ ---------
## The package already ships these (used directly by the tables). Set TRUE to
## recompute them from Data/industry_sorts.csv (block bootstrap; ~minutes-hours).
RUN_STEP2 <- TRUE
if (RUN_STEP2) {
  message(">> Step 2: correlations + bootstrap ...")
  source("code/r/Step2_MakeCorrelations_V4.R", chdir = FALSE)
}

## --- Tables + excess-corr-vs-leverage figure --------------------------------
message(">> Step 3: tables + leverage figure ...")
rmarkdown::render("code/r/Step3_Industry_correlation_V7.Rmd",
                  knit_root_dir = root, output_dir = "output")

## --- PROB goodness-of-fit figures -------------------------------------------
message(">> PROB goodness-of-fit figures ...")
rmarkdown::render("code/r/PROB_Goodness_of_Fit_V2.1.Rmd",
                  knit_root_dir = root, output_dir = "output")

message("Done. Tables -> output/tables/ , figures -> output/figures/")
