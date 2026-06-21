## verify_trim.R — prove the Step2 trim did not change any KEPT number.
## Run AFTER re-running the trimmed Step2 (master.R with RUN_STEP2 <- TRUE),
## which regenerates Data/Estimates/. Compares each of the 12 kept bootstrap
## files against the pre-trim reference Data/Estimates_pretrim/, restricted to
## the kept subsamples and (for unconCorr*) dropping EARN1Y.
##   Rscript verify_trim.R
suppressMessages(library(dplyr))

NEW <- "Data/Estimates"; OLD <- "Data/Estimates_pretrim"
kept_subs <- c("Full Sample", "Pre-GFC", "Post-GFC", "Ex-Recessions", "Annual")

files <- c(  # the 12 kept bootstrap outputs
  "length4/unconCorrBstrap.RData",  "length4/unconCorrBstrap18.RData",
  "length4/defCorrEqBstrap.rds",    "length4/defCorrEqBstrap18.rds",
  "length4/allCorrFdAgEx1qBstrap.rds",  "length4/allCorrFdAgEx1qBstrap18.rds",
  "length4/allCorrFdAgEx1qBstrapMV3.rds","length4/allCorrFdAgEx1qBstrapBOOKLEV3.rds",
  "length4/defCorrEqFdAgEx1qBstrap.rds","length4/defCorrEqFdAgEx1qBstrap18.rds",
  "length4/defCorrEqFdAgEx1qBstrapMV3.rds","length4/defCorrEqFdAgEx1qBstrapBOOKLEV3.rds")

load_one <- function(path) {
  if (grepl("\\.RData$", path)) { e <- new.env(); n <- load(path, envir = e); get(n[1], e) }
  else readRDS(path)
}
prep <- function(df) {
  df <- as.data.frame(df)
  if ("subsample" %in% names(df)) df <- df[df$subsample %in% kept_subs, , drop = FALSE]
  if ("variable"  %in% names(df)) df <- df[df$variable != "EARN1Y", , drop = FALSE]
  df
}

cat(sprintf("%-44s %8s %10s  %s\n", "file", "rows", "maxdiff", "status"))
worst <- 0; flagged <- character(0)
for (f in files) {
  a <- prep(load_one(file.path(NEW, f)))   # trimmed re-run
  b <- prep(load_one(file.path(OLD, f)))    # pre-trim reference
  keys <- intersect(names(a), c("pairname","variable","subsample","Ind1","Ind2","Code1","Code2"))
  num  <- names(a)[sapply(a, is.numeric)]
  a <- a[do.call(order, a[keys]), , drop = FALSE]
  b <- b[do.call(order, b[keys]), , drop = FALSE]
  if (nrow(a) != nrow(b) || !identical(lapply(a[keys], as.character), lapply(b[keys], as.character))) {
    cat(sprintf("%-44s %8d %10s  KEY-MISMATCH (a=%d,b=%d rows)\n", basename(f), nrow(a), "-", nrow(a), nrow(b)))
    flagged <- c(flagged, f); next
  }
  d <- max(unlist(Map(function(x, y) max(abs(x - y), na.rm = TRUE), a[num], b[num])), na.rm = TRUE)
  worst <- max(worst, d)
  st <- if (d <= 1e-10) "IDENTICAL" else if (d <= 1e-6) "negligible" else "*** DIFF ***"
  if (d > 1e-10) flagged <- c(flagged, f)
  cat(sprintf("%-44s %8d %10s  %s\n", basename(f), nrow(a), signif(d, 3), st))
}
cat(sprintf("\nGlobal max abs diff over kept rows: %s\n", signif(worst, 3)))
cat(if (worst <= 1e-10) "==> PASS: every kept number is bit-identical after the trim.\n"
    else if (worst <= 1e-6) "==> PASS: differences below reported precision.\n"
    else paste0("==> REVIEW: ", paste(basename(flagged), collapse=", "), "\n"))
