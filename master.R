## ============================================================================
## MASTER SCRIPT (analysis) — EGJL "Excess Co-movement in Default Risk" replication
##
## Path A (no WRDS): regenerate every empirical exhibit from the shipped derived
## data in Data/. Run from the package ROOT:
##
##     Rscript master.R
##
## Produces in output/:  Table 3, Tables OA.4-OA.9 (output/tables/),
##                       Figure OA.5 (output/figures/), and main_empirics.html.
## (Full rebuild from WRDS is Path B — see README.md / code/python/Step1_PrepareAllData.py.)
## ============================================================================

## Must be run from the package root (relative paths, MNSC item 13).
if (!file.exists("config.R"))
  stop("Run this from the package root: setwd('<package root>'); source('master.R').")

root <- normalizePath(".")

## --- Logging: console + messages to output/log/master_R.log (self-contained) -
## If a run ever comes out truncated, rerun with redirection instead:
##     Rscript master.R 2>&1 | tee output/log/master_R.log
log_dir <- file.path("output", "log")
dir.create(log_dir, showWarnings = FALSE, recursive = TRUE)
.logcon <- file(file.path(log_dir, "master_R.log"), open = "wt")
sink(.logcon, split = TRUE)        # stdout -> console and log file
sink(.logcon, type = "message")    # messages / warnings / errors -> log file

## --- Optional: regenerate the bootstrap estimates in Data/Estimates/ ---------
## The package ships these (read directly by the exhibits). Set TRUE to recompute
## them from Data/industry_sorts.csv (stationary block bootstrap; ~55 min).
RUN_STEP2 <- FALSE
if (RUN_STEP2) {
  message(">> Step 2: correlations + block bootstrap ...")
  .t0 <- Sys.time()
  source("code/r/Step2_MakeCorrelations_V4.R", chdir = FALSE)
  .nfiles <- length(list.files(file.path("Data", "Estimates", "length4"),
                               pattern = "\\.(rds|RData)$"))
  message(sprintf(">> Step 2 done in %.1f min: bootstrap B=%d, block_length=%d, seed=%d, num_cores=%d; %d estimate files in Data/Estimates/length4/",
                  as.numeric(difftime(Sys.time(), .t0, units = "mins")),
                  B, block_length, seed, num_cores, .nfiles))
}

## --- Empirical exhibits: Table 3, Tables OA.4-OA.9, Figure OA.5 --------------
message(">> Building empirical exhibits (main_empirics.Rmd) ...")
rmarkdown::render("code/r/main_empirics.Rmd",
                  knit_root_dir = root, output_dir = "output")

message("Done. Tables -> output/tables/ , figures -> output/figures/ , report -> output/main_empirics.html")

## --- Close the log sinks -----------------------------------------------------
sink(type = "message"); sink(); close(.logcon)
