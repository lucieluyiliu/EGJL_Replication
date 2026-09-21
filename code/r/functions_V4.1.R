# functions_V4.1.R -- EGJL "Excess Co-movement in Default Risk"
#
# Settings and functions shared by Step2_MakeCorrelations_V4.R and main_empirics.Rmd.
# Sourced from the package root; it defines objects and functions only and produces
# no output of its own.
#
# Contents
#   Parameters          ggplot themes and colours; the 18 unrelated industry pairs
#                       (unrelated_pairnames)
#   Helper functions    fctCorrSE        Pearson correlation of two series with its standard error
#                       fctPairCorr      correlation of every industry pair, for each variable
#                       fctTSRes0        residuals of one variable from a regression on the control
#                                        variables (and aggregate shocks), estimated on the
#                                        industry-quarter panel passed to it
#                       fctTSRes         the same for a list of variables
#                       fctFormPairs     all pairs of industries in a table
#                       fctSort, fctSortTcl, fctSortHL
#                                        industry pairs within bins of a sorting variable
#                       fctCorrSEtable   table with correlations and standard errors
#   Bootstrap           fctResample      row indices of one stationary block bootstrap draw
#                       fctMeanCorr      average correlation over a set of industry pairs
#                       fctBstrapCorr    bootstrap standard error of that average
#                       fctBstrapCorr2   the same for two sets of pairs and their difference
#                       fctBstrapAll, fctBstrapAll2
#                                        the two functions above, applied to a list of variables
#                       opt_block_length_REV_dec07
#                                        optimal block length of the stationary bootstrap

# Parameters---------

#Clean ggplot theme

mytheme<-theme(
  panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_rect(fill = "transparent",colour = NA),
  panel.border = element_rect(fill = "transparent",colour = 'black'),
  plot.background = element_rect(fill = "transparent",colour = NA),
  strip.background=element_rect(fill = "transparent",colour = NA),
  legend.background=element_rect(fill = "transparent",colour = NA),
  legend.key = element_rect(fill = "transparent",colour=NA),
  strip.text = element_text(size = 22),
  legend.text = element_text(size = 22),  
  axis.title.y = element_text(size = 22),
  axis.title.x = element_text(size=22),
  axis.text.x = element_text(size = 10),
  legend.title = element_blank(),
  plot.title = element_text(size = 22)
  #panel.border=element_rect(colour='black')
)


mytheme_white<-theme(
  panel.grid.major = element_blank(), 
  panel.grid.minor = element_blank(),
  panel.background = element_rect(fill = "white",colour = NA),
  panel.border = element_rect(fill = "transparent",colour = 'black'),
  plot.background = element_rect(fill = "white",colour = NA),
  strip.background=element_rect(fill = "transparent",colour = NA),
  legend.background=element_rect(fill = "transparent",colour = NA),
  legend.key = element_rect(fill = "transparent",colour=NA),
  strip.text = element_text(size = 14),
  legend.text = element_text(size = 14),  
  #axis.title.y = element_text(size = 12),
  #axis.title.x = element_text(size=12),
  axis.text.x = element_text(size = 10),
  axis.text.y = element_text(size = 10),
  legend.title = element_blank(),
  plot.title = element_text(size = 20)
  #panel.border=element_rect(colour='black')
)

#Economists color palette

red='#E2365B'
red60='#F6423C'
blue='#475ED1'
yellow='#FBD051'
green='#228B22'
orange='#F97A1F'

LineWidth=0.75

# The 18 pairs of unrelated industries used in the paper, by Fama-French 48 short name.
# unrelated_pairnames holds each pair in both orders (for example "Smoke_MedEq" and
# "MedEq_Smoke"), so that a pair is found whichever industry comes first.
unrelated_ind <- data.frame(pairno = integer(), ind1 = character(), ind2 = character(), stringsAsFactors = FALSE)

unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=1, ind1="Smoke",ind2="MedEq"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=2, ind1="Smoke",ind2="BusSv"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=3, ind1="Gold", ind2="Coal"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=4, ind1="Smoke",ind2="Chems"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=5, ind1="Smoke",ind2="Chips"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=6, ind1="Fun",ind2="Ships"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=7, ind1="Guns",ind2="Gold"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=8, ind1="FabPr",ind2="Gold"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=9, ind1="Hlth",ind2="Gold"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=10,ind1="Gold",ind2="PerSv"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=11,ind1="Smoke",ind2="Paper"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=12,ind1="Toys",ind2="Gold"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=13, ind1="Smoke",ind2="Trans"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=14, ind1="Food",ind2="Smoke"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=15, ind1="Txtls",ind2="Ships"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=16, ind1="Cnstr",ind2="Gold"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=17, ind1="Gold",ind2="Mines"))
unrelated_ind<-rbind(unrelated_ind, data.frame(pairno=18, ind1="Smoke",ind2="Whlsl"))

unrelated_ind<-unrelated_ind%>%mutate(pairname12=paste0(ind1,'_',ind2), pairname21=paste0(ind2,'_',ind1))

unrelated_pairnames<-c(unrelated_ind$pairname12%>%unique(), unrelated_ind$pairname21%>%unique())

# Functions------

## Helper functions ------

#Pearson correlation with standard error

fctCorrSE <- function(x, y) {
  valid_data <- na.omit(data.frame(x, y))
  n <- nrow(valid_data)
  
  if (n < 3) {
    # Not enough data to calculate correlation or SE
    return(c(corr = NA, se = NA))
  }
  
  cor_test <- cor.test(valid_data$x, valid_data$y)
  cor_value <- as.numeric(cor_test$estimate)
  se_value <- sqrt((1 - cor_value^2) / (n - 2))
  
  return(c(corr = cor_value, se = se_value))
  
}

# Correlation, with its standard error, between the two industries of every pair in
# industry_pairs (an object of the calling script), separately for each variable and,
# if given, for each value of group_vars.
fctPairCorr <- function(data, group_vars = character()) {
  #This is a versatile function that computes the pairwise correlation for each yvar, groupped by group_vars 
  out<-industry_pairs %>%
    rowwise() %>%
    mutate(
      correlations = list({
        # Subset and reshape
        data_subset <- data %>%
          filter(ffi48 %in% c(Code1, Code2)) %>%
          select(date, ffi48, value, variable, all_of(group_vars))
        
        wide_data <- data_subset %>%
          pivot_wider(names_from = ffi48, values_from = value) %>%
          select(-date)
        
        # Handle missing columns
        if (ncol(wide_data) < 2) {
          dummy_names <- c("variable", group_vars, "corr", "se")
          dummy_values <- rep(NA, length(dummy_names))
          return(as_tibble(setNames(as.list(dummy_values), dummy_names)))
        }
        
        # Rename residuals
        wide_data <- wide_data %>%
          rename(
            X1 = all_of(as.character(Code1)),
            X2 = all_of(as.character(Code2))
          )
        
        # Conditional summarise
        result <- 
          wide_data %>%
            group_by(across(all_of(c("variable", group_vars)))) %>%
            summarise(
              corr = fctCorrSE(X1, X2)[["corr"]],
              se = fctCorrSE(X1, X2)[["se"]],
              .groups = "drop"
            )
       
        
        result
      })
    ) %>%
    ungroup() %>%
    unnest(correlations)
  
}


# First pass time seires regression on agg shocks and fundamental innovations
# Control for one agg risk at a time loop over y variables and agg shocks
# Add fundamental shocks

fctTSRes0<-function(data, yvar, ctrlVars, aggVars="None"){
  # Function that takes yvar and aggvar as given, returns residuals from time series regression.
  # Only runs for a given data
  
  if ("None"%in%aggVars){
    formula_str <- paste(yvar, "~", paste(ctrlVars, collapse = " + "))
    #Modified 2024-12-19 drop only na of variables needed
    data<-data %>% filter(if_all(all_of(c(yvar, ctrlVars)), ~ !is.na(.)))
  } else {
    formula_str <- paste(yvar, "~", paste(c(ctrlVars, aggVars), collapse = " + "))
    #Modified 2024-12-19 drop only na of variables needed
    data<-data %>% filter(if_all(all_of(c(yvar, ctrlVars, aggVars)), ~ !is.na(.)))
  
    }

  formula <- as.formula(formula_str)
  
  reg <- feols(formula, data = data) 
  
  #Label which aggregate shock is controlled for
  whichAgg <- if (length(aggVars) == 1) {
    aggVars
  } else if (length(aggVars) == 10) {
    "All"
  } 
  
  residuals<- tibble(
    date=data$date,
    res=resid(reg),
    variable=yvar,
    aggvar=whichAgg
  )
  
  if("ffi48"%in%colnames(data)){
    residuals$ffi48=data$ffi48
  }
  
  return(residuals)
}

#wrapper that computes fctTSRes for all y variables. Might simplify if horizon is not relevant.
fctTSRes <- function(data, yvars, ctrlVars, aggVars="None") {
      map_dfr(
        yvars,
        function(yvar) {
          fctTSRes0(
            data = data,
            yvar,
            ctrlVars,
            aggVars
          )
        }
      )
}


#Find all pairs formed within a table
fctFormPairs <- function(data) {
  data %>%
    distinct(ffi48) %>%
    arrange(ffi48) %>%
    mutate(dummy = 1) %>%
    full_join(., ., by = "dummy", relationship = "many-to-many") %>%
    filter(ffi48.x < ffi48.y) %>%
    select(Code1 = ffi48.x, Code2 = ffi48.y) %>%
    left_join(FF48, by = c("Code1" = "Code")) %>%
    rename(Ind1 = Name) %>%
    left_join(FF48, by = c("Code2" = "Code")) %>%
    rename(Ind2 = Name) %>%
    mutate(pairname = paste0(Ind1, '_', Ind2))
}



fctSortTcl<-function(data, sortvar){
# Takes sorting variable, find industries within each tercile 
# Form pairs
  
  data_tcl<-data%>%select(ffi48, {{sortvar}})%>%
    arrange({{sortvar}})%>%
    mutate(bin=ntile({{sortvar}}, 3))
  
  sortvar_bytcl<-data_tcl%>%
    group_by(bin)%>%
    summarize(sortvar=mean({{sortvar}}))
  
  TclPairs<-data_tcl %>%
    group_by(bin)%>%
    nest()%>%
    mutate(pairs=map(data, fctFormPairs))%>%
    unnest(pairs)%>%
    select(-data)
  
  return(TclPairs)
}


#Sort into high-low not tercile
fctSortHL<-function(data, sortvar){
  # Takes sorting variable, find industries within each tercile 
  # Form pairs
  
  data_HL<-data%>%select(ffi48, {{sortvar}})%>%
    arrange({{sortvar}})%>%
    mutate(bin=ntile({{sortvar}}, 2))
  
  sortvar_byHL<-data_HL%>%
    group_by(bin)%>%
    summarize(sortvar=mean({{sortvar}}))
  
  HLPairs<-data_HL %>%
    group_by(bin)%>%
    nest()%>%
    mutate(pairs=map(data, fctFormPairs))%>%
    unnest(pairs)%>%
    select(-data)
  
  return(HLPairs)
}

fctSort<-function(data, sortvar, bins){
  # Takes sorting variable, find industries within each tercile 
  # Form pairs
  
  data_sorted<-data%>%select(ffi48, {{sortvar}})%>%
    arrange({{sortvar}})%>%
    mutate(bin=ntile({{sortvar}}, bins))
  
  sortvar_by_bin<-data_sorted%>%
    group_by(bin)%>%
    summarize(sortvar=mean({{sortvar}}))
  
  SortedPairs<-data_sorted %>%
    group_by(bin)%>%
    nest()%>%
    mutate(pairs=map(data, fctFormPairs))%>%
    unnest(pairs)%>%
    select(-data)
  
  return(SortedPairs)
}


# Table with both corr and se

fctCorrSEtable<-function(table){
  table_long<-table %>%
    pivot_longer(                           # Reshape into long format for processing
      cols = c(corr, se),
      names_to = "metric",
      values_to = "value"
    ) %>%
    mutate(
      row_type = ifelse(metric == "corr", "Correlation", "Standard Error")  # Label rows
    ) %>%
    select(pairname, row_type, variable, value)
  
  avg_corr<-table_long%>%filter(row_type=='Correlation')%>%
    group_by(variable)%>%
    summarize(avg_corr=mean(value), .groups='drop')%>%
    pivot_wider(names_from= variable, values_from=avg_corr)
  
  avg_corr$pairname<-'Average'
  
  avg_corr$row_type<-'Correlation'
  
  final_table <- table_long %>%
    pivot_wider(
      names_from = variable,
      values_from = value
    ) %>%
    arrange(pairname, row_type)
  
  final_table<-bind_rows(final_table, avg_corr)
}




# One draw of the stationary block bootstrap: returns T row indices. A block continues with
# the next observation with probability 1 - 1/block_length (wrapping around at the end of the
# sample) and otherwise restarts at a random date, so blocks have average length block_length.
fctResample <- function(T, block_length) {
  # Arguments:
  # T: Number of rows in the data matrix (time series length)
  # block_length: Average length of blocks to preserve continuity
  
  # Initialize an output vector to store indices
  indices <- numeric(T)
  
  # Start with a random index
  temp <- sample(1:T, 1)
  indices[1] <- temp
  
  for (t in 2:T) {
    # Decide whether to continue the block or start a new block
    if (runif(1) > 1 / block_length) {
      # Continue with the next observation (loop back to the start if necessary)
      temp <- ifelse(temp == T, 1, temp + 1)
    } else {
      # Start a new block at a random position
      temp <- sample(1:T, 1)
    }
    indices[t] <- temp
  }
  
  return(indices)
}


## Bootstrap functions-----

# Bootstrapping function for a single subset of pairs


#Function to calculate mean correlation for a subset of pairs, for a given data_matrix 42*42 of correlation across industries
fctMeanCorr <- function(data_matrix, pairs = NULL) {
  # It is easier to compute the full correlation matrix then compute average of a subset of pairs.
  # Calculate the correlation matrix
  cor_matrix <- cor(data_matrix, use = "pairwise.complete.obs")
  
  #Calculate the mean acorss pairs
  if (is.null(pairs)) {
    # If pairnames is NULL, calculate mean correlation across all pairs
    cor_pairs <- cor_matrix[upper.tri(cor_matrix)]
    mean_corr <- mean(cor_pairs, na.rm = TRUE)
    
  } else {
    # Ensure pairnames columns are character type
    pairs <- pairs %>%
      mutate(across(everything(), as.character))
    
    # Initialize a vector to store correlations for specified pairs
    pair_correlations <- numeric(nrow(pairs))
    
    # Iterate over each pair in pairnames
    for (i in seq_len(nrow(pairs))) {
      code1 <- pairs$Code1[i]
      code2 <- pairs$Code2[i]
      
      # Check if both industry codes exist in the correlation matrix
      if (code1 %in% colnames(cor_matrix) && code2 %in% colnames(cor_matrix)) {
        # Extract the correlation for the specific pair
        pair_correlations[i] <- cor_matrix[code1, code2]
      } else {
        # Assign NA if either industry code is not found
        pair_correlations[i] <- NA
      }
      
    }
    
    # Calculate mean correlation for specified pairs, excluding NA values
    mean_corr <- mean(pair_correlations, na.rm = TRUE)
  }
  
  return(mean_corr)
}


fctBstrapCorr <- function(data, pairs=NULL, B = 1000, block_length=4 ,num_cores = NULL) {
  # 2025-07-18: modify this function to work with long rather than wide data table
  # Filter data to include only the relevant columns
  # Pairs contain information about industry pairs
  data_filtered <- data%>%
    select(date, ffi48, value)%>%filter(!is.na(value)) #Add non-NA filter
  # Pivot to wide format: rows are dates, columns are industries (ffi48)
  data_wide <-data_filtered%>% pivot_wider(names_from=ffi48, values_from=value)%>%select(-date)
  
  data_matrix <- as.matrix(data_wide) # Exclude the "date" column
  
  # Calculate observed mean correlation for specific pairs
  
  observed_mean <- fctMeanCorr(data_matrix, pairs)
  
  # Set up parallel processing
  if (is.null(num_cores)) {
    num_cores <- 15   # fixed for bootstrap reproducibility (univ. M3: detectCores()-1 = 15)
  }
  cl <- makeCluster(num_cores, setup_strategy = "sequential", setup_timeout = 600)  # sequential launch is robust to per-worker renv startup; does NOT affect RNG/results
  # Export all necessary objects and functions to the cluster
  clusterExport(cl, varlist = c("data_matrix", "fctMeanCorr", "pairs", "block_length","fctResample"), envir = environment())
  
  clusterEvalQ(cl, {
    library(dplyr)
    library(tidyr)
  })
  
  # Set RNG streams for reproducibility
  clusterSetRNGStream(cl, seed)  # Set the seed for all workers
  
  NT<-nrow(data_matrix)
  # Perform bootstrapping
  bootstrap_means <- parSapply(cl, 1:B, function(b) {
    
    #Stationary bootstrap
    bootstrap_indices <- fctResample(NT, block_length)
    
    bootstrap_sample <- data_matrix[bootstrap_indices, ]
    
    fctMeanCorr(bootstrap_sample, pairs)
    
  })
  
  # Stop the cluster
  suppressWarnings(stopCluster(cl))
  
  # Calculate bootstrap SE
  bootstrap_se <- sd(bootstrap_means)
  
  list(
    corr = observed_mean,
    se = bootstrap_se
  )
}

# Bootstrapping function for two groups calculate the SE of the average of each group and the difference

fctBstrapCorr2 <- function(data, pairs1, pairs2, B = 1000, block_length=4, num_cores = NULL) {
  # 2025-07-24: modify this function to work with long rather than wide data table
  # Filter data to include only the relevant columns
  # Pairs contain information about industry pairs
  data_filtered <- data%>%
    select(date, ffi48, value)%>%filter(!is.na(value)) #Add non-NA filter
  # Pivot to wide format: rows are dates, columns are industries (ffi48)
  data_wide <-data_filtered%>% pivot_wider(names_from=ffi48, values_from=value)%>%select(-date)
  
  data_matrix <- as.matrix(data_wide) # Exclude the "date" column
  
  # Calculate observed mean correlation for specific pairs
  
  observed_mean1 <- fctMeanCorr(data_matrix, pairs1)
  observed_mean2 <- fctMeanCorr(data_matrix, pairs2)
  observed_diff <- observed_mean1 - observed_mean2
  
  # Set up parallel processing
  if (is.null(num_cores)) {
    num_cores <- 15   # fixed for bootstrap reproducibility (univ. M3: detectCores()-1 = 15)
  }
  
  cl <- makeCluster(num_cores, setup_strategy = "sequential", setup_timeout = 600)  # sequential launch is robust to per-worker renv startup; does NOT affect RNG/results
  # Export all necessary objects and functions to the cluster
  clusterExport(cl, varlist = c("data_matrix", "fctMeanCorr", "pairs1", "pairs2","block_length","fctResample"), envir = environment())
  
  clusterEvalQ(cl, {
    library(dplyr)
    library(tidyr)
  })
  
  # Set RNG streams for reproducibility
  clusterSetRNGStream(cl, seed)  # Set the seed for all workers
  
  NT<-nrow(data_matrix)
  # Perform bootstrapping
  bootstrap_results <- parSapply(cl, 1:B, function(b) {
    # Resample rows of the data matrix
    
    #Stationary bootstrapping
    bootstrap_indices <- fctResample(NT, block_length)
    
    bootstrap_sample <- data_matrix[bootstrap_indices, ]
    
    # Calculate mean correlations for the two groups in the bootstrap sample
    mean1 <- fctMeanCorr(bootstrap_sample, pairs1)
    mean2 <- fctMeanCorr(bootstrap_sample, pairs2)
    diff <- mean1 - mean2
    
    c(mean1 = mean1, mean2 = mean2, diff = diff)
  })
  
  
  # Stop the cluster
  suppressWarnings(stopCluster(cl))
  
  bootstrap_means1 <- bootstrap_results["mean1", ]
  bootstrap_means2 <- bootstrap_results["mean2", ]
  bootstrap_diffs <- bootstrap_results["diff", ]
  
  # Calculate bootstrap SE
  se_mean1 <- sd(bootstrap_means1, na.rm = TRUE)
  se_mean2 <- sd(bootstrap_means2, na.rm = TRUE)
  se_diff <- sd(bootstrap_diffs, na.rm = TRUE)
  
  list(
    #variable = variable,
    corr1 = observed_mean1,
    corr2 = observed_mean2,
    diff = observed_diff,
    se1 = se_mean1,
    se2 = se_mean2,
    sediff = se_diff
  )
}


# Applies fctBstrapCorr to each variable in `variables` and stacks the results: the average
# correlation across `pairs` (all pairs if NULL) and its bootstrap standard error.
fctBstrapAll <- function(data, variables, pairs, B = 1000, block_length=4, num_cores = NULL) {
  # Loop over all varaibles
  out<-map_dfr(variables, function(var) {
    
    data_subset <- filter(data, variable == var)
    
    # Guard: no rows for this variable
    if (nrow(data_subset) == 0L) {
      return(tibble(
        variable = var, pair = NA_character_,
        corr = NA_real_, se = NA_real_, n = 0L,
        note = "no rows for this variable"
      ))
    }
    
    # Run bootstrap on all horizons present for this variable
    res <- fctBstrapCorr(data_subset, pairs, B, block_length, num_cores)
    
    res_df <- as.data.frame(res)
    res_df$variable <- var
    
    res_df
  })
  
}


# Applies fctBstrapCorr2 to each variable in `variables` and stacks the results: the average
# correlation in `pairs1` and in `pairs2`, their difference, and the bootstrap standard errors.
fctBstrapAll2 <- function(data, variables, pairs1, pairs2, B = 1000, block_length=4, num_cores = NULL) {
  # Wrapper to loop over all variables
   out<-map_dfr(variables, function(var) {
    data_subset <- filter(data, variable == var)
    
    # Guard: no rows for this variable
    if (nrow(data_subset) == 0L) {
      return(tibble::tibble(
        variable = var, pair = NA_character_,
        corr = NA_real_, se = NA_real_, n = 0L,
        note = "no rows for this variable"
      ))
    }
    
    # Let fctBstrapCorr2 handle horizons internally (if needed)
    res <- fctBstrapCorr2(data_subset, pairs1, pairs2, B, block_length, num_cores)
    
    res_df <- as.data.frame(res)
    res_df$variable <- var
    res_df
  })
  
}


opt_block_length_REV_dec07 <- function(data) {
  # Function to calculate optimal block length for stationary or circular bootstrap
  # Arguments:
  # - data: A matrix with n rows (observations) and k columns (variables)
  #
  # Returns:
  # - Bstar: A 2xk matrix of optimal block lengths for stationary and circular bootstrap
  
  library(dplyr)
  
  n <- nrow(data)
  k <- ncol(data)
  
  # Fixed parameters
  KN <- max(5, sqrt(log10(n)))
  mmax <- ceiling(sqrt(n)) + KN
  Bmax <- ceiling(min(3 * sqrt(n), n / 3))
  c <- 2
  
  # Helper function for flattop kernel weights
  lam <- function(kk) {
    (abs(kk) >= 0) * (abs(kk) < 0.5) + 2 * (1 - abs(kk)) * (abs(kk) >= 0.5) * (abs(kk) <= 1)
  }
  
  # Initialize result matrix
  Bstar_final <- matrix(NA, nrow = 2, ncol = k)
  
  # Loop over each column (variable) in data
  for (i in 1:k) {
    column_data <- data[, i]
    
    # Step 1: Find mhat (largest significant lag)
    autocorr <- function(x, lag) {
      cor(x[1:(length(x) - lag)], x[(lag + 1):length(x)])
    }
    
    acf_values <- sapply(1:mmax, function(lag) autocorr(column_data, lag))
    acf_matrix <- do.call(cbind, lapply(1:KN, function(x) acf_values[x:(length(acf_values) - KN + x)]))
    significance <- abs(acf_matrix) < (c * sqrt(log10(n) / n))
    num_insignificant <- rowSums(significance)
    
    if (all(num_insignificant < KN)) {
      mhat <- max(which(abs(acf_values) > (c * sqrt(log10(n) / n))))
    } else {
      mhat <- which(num_insignificant == KN)[1]
    }
    
    M <- if (2 * mhat > mmax) mmax else 2 * mhat
    
    if (M > 0) {
      # Step 2: Compute Ghat, DCBhat, and DSBhat
      lags <- -M:M
      acf_full <- sapply(abs(lags), function(lag) {
        if (lag == 0) var(column_data) else cov(column_data[1:(length(column_data) - lag)], column_data[(lag + 1):length(column_data)])
      })
      Ghat <- sum(lam(lags / M) * abs(lags) * acf_full)
      DCBhat <- (4 / 3) * sum(lam(lags / M) * acf_full)^2
      DSBhat <- 2 * sum(lam(lags / M) * acf_full)^2
      
      # Step 3: Calculate optimal block lengths
      Bstar <- ((2 * Ghat^2 / DSBhat)^(1/3)) * n^(1/3)
      Bstar <- min(Bstar, Bmax)
      BstarCB <- ((2 * Ghat^2 / DCBhat)^(1/3)) * n^(1/3)
      BstarCB <- min(BstarCB, Bmax)
      
      Bstar_final[, i] <- c(Bstar, BstarCB)
    } else {
      Bstar_final[, i] <- c(1, 1)
    }
  }
  
  return(Bstar_final)
}