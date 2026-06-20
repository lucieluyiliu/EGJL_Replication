## ----------------------------------------------------------------------------
## R package dependencies for the EGJL "Excess Default Correlations" package.
## Run once from the package root:  Rscript install_R_packages.R
##
## NOTE: exact versions are not pinned here (no R env export was available).
## For a fully reproducible R environment, capture versions on the machine that
## produced the results (e.g. renv::snapshot(), or save sessionInfo()), and pin.
## `parallel` is part of base R (no install needed).
## ----------------------------------------------------------------------------

## --- CRAN packages ----------------------------------------------------------
cran <- c(
  "tidyverse",   # dplyr, tidyr, ggplot2, purrr, stringr, readr, ...
  "fixest", "kableExtra", "viridis", "stringi", "psych",
  "ggforce", "ggrepel", "cowplot", "knitr", "pander",
  "lmtest", "sandwich", "broom", "gt", "modelsummary",
  "zoo", "patchwork", "readxl", "openxlsx", "rmarkdown"
)
new <- cran[!cran %in% rownames(installed.packages())]
if (length(new)) {
  install.packages(new, repos = "https://cloud.r-project.org")
}

## --- Bioconductor packages (rhdf5 is NOT on CRAN) ---------------------------
if (!requireNamespace("BiocManager", quietly = TRUE)) {
  install.packages("BiocManager", repos = "https://cloud.r-project.org")
}
if (!requireNamespace("rhdf5", quietly = TRUE)) {
  BiocManager::install("rhdf5", update = FALSE, ask = FALSE)
}

## --- System dependency: pandoc (NOT an R package) ----------------------------
## rmarkdown needs pandoc >= 1.12.3 to knit the Step 3 .Rmd exhibits. R cannot
## install it; this only checks and tells you how. RStudio bundles its own pandoc,
## but command-line Rscript does not.
if (!rmarkdown::pandoc_available("1.12.3")) {
  message(
    "\n[!] pandoc >= 1.12.3 not found. Install it system-wide before knitting Step 3:\n",
    "      macOS:  brew install pandoc\n",
    "      conda:  conda install -c conda-forge pandoc   (or use environment.yml)\n",
    "      Linux:  apt-get install pandoc\n",
    "    Then restart R, or run: Sys.setenv(RSTUDIO_PANDOC = dirname(Sys.which('pandoc')))"
  )
} else {
  message("pandoc found: ", rmarkdown::pandoc_version())
}

message("R dependencies installed.")
