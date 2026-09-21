# Step2_MakeCorrelations_V4.R — EGJL "Excess Default Correlations"
# Author: Lucie Lu <lucie.lu@unimelb.edu.au>
# Date:   2026-06-21
#
# Industry-pair TOTAL and EXCESS correlations in default risk and equity moments,
# with stationary-block-bootstrap standard errors. Outputs feed the exhibits in
# main_empirics.Rmd (Table 3 and Online Appendix Tables OA.4-OA.9).
#
#   0. Initialization and data import
#   1. Compute residuals (first-pass regressions) and per-pair total correlations
#   2. Bootstrap total and excess correlations
#   3. Excess correlations by size and book-leverage terciles
#
# Sample 1987Q2-2023Q4. Block bootstrap: block length 4, B = 1000, seed = 123.

# 0. Initialization and data import -------------------------------------------

library(tidyverse)
library (fixest)
library(kableExtra)
library(viridis)
library(stringi)
library(psych)
library(ggforce) # for 'geom_arc_bar'
library(ggrepel)
library(ggplot2)
library(cowplot)
library(knitr)
library(pander)
library(broom)
library(purrr)
panderOptions('digits', 3)
library(gt)
library(modelsummary)
library(rhdf5)
library(parallel)
library(zoo)
#define not in operator
"%ni%"<-Negate("%in%")
## 0.A Paths and configuration ---------------------------------------------
source("config.R")              # path, data_dir, est_dir, table_dir, fig_dir
source("code/r/functions_V4.1.R")

start_date<-as.Date("1987-06-30") # sample start date

end_date=as.Date("2023-12-31") # sample end date

quarter_ends <- seq(
  from = as.Date("1987-06-30"),
  to   = as.Date("2023-12-31"),
  by   = "quarter"
)

quarter_GFC <- seq(
  from = as.Date("2007-12-31"),
  to   = as.Date("2008-12-31"),
  by   = "quarter"
)

quarter_covid <- seq(
  from = as.Date("2020-03-31"),
  to   = as.Date("2020-12-31"),
  by   = "quarter"
)

NBER_peak_trough <- tribble(
  ~peak_q, ~trough_q,
  "1857 Q2","1858 Q4",
  "1860 Q3","1861 Q3",
  "1865 Q1","1868 Q1",
  "1869 Q2","1870 Q4",
  "1873 Q3","1879 Q1",
  "1882 Q1","1885 Q2",
  "1887 Q2","1888 Q1",
  "1890 Q3","1891 Q2",
  "1893 Q1","1894 Q2",
  "1895 Q4","1897 Q2",
  "1899 Q3","1900 Q4",
  "1902 Q4","1904 Q3",
  "1907 Q2","1908 Q2",
  "1910 Q1","1911 Q4",
  "1913 Q1","1914 Q4",
  "1918 Q3","1919 Q1",
  "1920 Q1","1921 Q3",
  "1923 Q2","1924 Q3",
  "1926 Q3","1927 Q4",
  "1929 Q3","1933 Q1",
  "1937 Q2","1938 Q2",
  "1945 Q1","1945 Q4",
  "1948 Q4","1949 Q4",
  "1953 Q2","1954 Q2",
  "1957 Q3","1958 Q2",
  "1960 Q2","1961 Q1",
  "1969 Q4","1970 Q4",
  "1973 Q4","1975 Q1",
  "1980 Q1","1980 Q3",
  "1981 Q3","1982 Q4",
  "1990 Q3","1991 Q1",
  "2001 Q1","2001 Q4",
  "2007 Q4","2009 Q2",
  "2019 Q4","2020 Q2"
)

quarter_recessions <- NBER_peak_trough %>%
  rowwise() %>%
  mutate(qseq = list(seq(from = as.yearqtr(peak_q),
                         to   = as.yearqtr(trough_q),
                         by   = 0.25))) %>%
  unnest(qseq) %>%
  transmute(
    peak_q, trough_q,
    q_end = as.Date(qseq, frac = 1)   # quarter-end date
  ) %>%
  arrange(q_end)%>%pull(q_end)


pre_GFC<-as.Date("2007-09-30")

sum(quarter_ends<=pre_GFC) #81 quarters before GFC

post_GFC<-as.Date("2008-12-31")

sum(quarter_ends>post_GFC) #60 quarters after GFC

pre_Covid<-as.Date("2019-12-31")

post_Covid<-as.Date("2020-12-31")

library(openxlsx)    

# Variable lists

y_vars=c('PROB','CS5y', 'MKTLEV', 'BOOKLEV' ,'EXRET','SIGMA')

agg_vars=c('IP', 'CFNAI', 'EPU', 'UNRATE', 'DeltaLiq' , 'MacroU', 'RealU', 'NGDP', 'FEDFUNDS',"DeltaICR")

funda_vars=c('EBITDA','NIMTA','CASHMTA','ASSETS','PROFIT','SALES')

def_vars<-c('PROB', 'CS5y','MKTLEV','BOOKLEV')

equity_vars<-c('EXRET','SIGMA')

for_vars=c('EARN1Q')

#Bootstrapping parameters

seed<-123

set.seed(seed) 

B<-1000

block_length=4

# Fixed worker count — REQUIRED for identical numerical results. clusterSetRNGStream
# assigns one RNG stream per worker, so the count must be held at 15 to reproduce the
# published SEs on any machine (the published estimates were generated where
# detectCores()-1 = 15; works on machines with fewer cores too, just slower).
num_cores <- 15

# Specify the subfolder to create

length_folder <- file.path(est_dir, paste0("length", block_length))

# Check if the folder exists; if not, create it
if (!dir.exists(length_folder)) {
  dir.create(length_folder, recursive = TRUE)
  cat("Folder created:", length_folder, "\n")
} else {
  cat("Folder already exists:", length_folder, "\n")
}

## 0.B Load data -----------------------------------------------------------

FF48<-read_csv(paste0(data_dir, 'FF48_industry.csv'))

#Check 1q as Round1
ind_sorts<-read_csv(paste0(data_dir,'industry_sorts.csv'))

ind_sorts<-ind_sorts%>%inner_join(FF48, by=c("ffi48"="Code"))

#Exclude financials and utilities
ind_sorts<-ind_sorts%>%filter(!grepl("Banks|Insur|RlEst|Fin|Other|Util", Name, ignore.case = TRUE))%>%
  filter(date<=end_date) #filter for sample end date

ind_sorts_long<-ind_sorts%>%
  pivot_longer(cols=-c(date, ffi48, Name), names_to = "variable", values_to = "value")%>%
  mutate(# Extract horizon: last piece after last "_"
    horizon = str_extract(variable, "[^_]+$"),
    # Remove _pct_* or _diff_* at the end to get variable
    variable = str_remove(variable, "_(pct|diff)_[^_]+$"),
    variable = str_remove(variable, "_(1q|1y)$"))%>%
  mutate(
    variable = case_when(
      variable == "cdr" ~ "PROB",
      variable == "book_leverage" ~ "BOOKLEV",
      variable == "market_leverage" ~ "MKTLEV",
      variable == "sales_at" ~ "SALES",
      variable == "gp_at" ~ "PROFIT",
      variable == "ret_exc"~"EXRET",
      TRUE ~ variable
    ),
    horizon=ifelse(horizon%in%c('1q','1y'), horizon, '0')   # only 1q (quarterly) and 1y (annual) are used
  )

# horizons <- setdiff(unique(ind_sorts_long$horizon), '0')   # unused

# Sanity check on variable date ranges (run manually if needed).
# CS available from 2002-09-30 to the sample end; all others available throughout.
# ind_date_range<-ind_sorts_long%>%
#   filter(!is.na(value)) %>%
#   group_by(variable, horizon) %>%
#   summarise(start_date = min(date), end_date = max(date)) %>%
#   ungroup()

## 0.C Industry pairs ------------------------------------------------------

industry_pairs <- ind_sorts %>% fctFormPairs()

#Check whether pairwise correlation changes with horizon

#Unrelated pairs
unrelated_pairs<-industry_pairs%>%filter(pairname%in%unrelated_pairnames)

all_variables <- c(y_vars,funda_vars, for_vars)

#Compute industry-level avarage for industry sorts
ind_vars <- ind_sorts %>%
  select(ffi48, Name, date, MSHARE=mktcap_share,ESHARE=ebitda_share,ASHARE=assets_share, BOOKLEV=book_leverage)%>%
  group_by(ffi48, Name) %>%
  summarise(across(
    c(MSHARE, ESHARE, ASHARE, BOOKLEV),
    function(x) mean(x, na.rm = TRUE)
  ))%>%
  ungroup()


# Import aggregate shocks

AggShocks<-read_csv(paste0(data_dir, 'AggShocks/Agg_shocks.csv'))%>%
  filter(date>=start_date)%>%
  select("date",
         "IP_pct_1q","IP_pct_1y",
         "DeltaLiq_1q","DeltaLiq_1y",
         "CFNAI_diff_1q","CFNAI_diff_1y",
         "EPU_pct_1q","EPU_pct_1y",
         "UNRATE_diff_1q","UNRATE_diff_1y",
         "MacroU_diff_1q","MacroU_diff_1y",
         "RealU_diff_1q","RealU_diff_1y",
         "FinU_diff_1q","FinU_diff_1y",
         "NGDP_1q","NGDP_1y",
         "FEDFUNDS_diff_1q","FEDFUNDS_diff_1y",
         "DeltaICR_1q","DeltaICR_1y")%>%
  pivot_longer(cols=-c(date), names_to = "variable", values_to = "value")%>%
  mutate(# Extract horizon: last piece after last "_"
    horizon = str_extract(variable, "[^_]+$"),
    # Remove _pct_* or _diff_* at the end to get variable
    variable = str_remove(variable, "_(pct|diff)_[^_]+$"),
    variable = str_remove(variable, "_(1q|1y)$"))

#Availability of variables: Aggregate shocks are available till 2024-12-30, except for HKM Intermediary shock which is available until 2024-06-30
aggshock_date_range<-AggShocks%>%
  filter(!is.na(value)&horizon=='1q') %>%  
  group_by(variable) %>%
  summarise(start_date = min(date), end_date = max(date)) %>%
  ungroup()
  
  

# 1. Compute residuals and per-pair total correlations ------------------------
# Builds the per-pair total correlations (unconCorr) and the first-pass regression
# residuals that Section 2 bootstraps. Residuals are estimated within each sub-sample.

## 1.A Total correlations, pairwise ----------------------------------------

all_variables <- c(y_vars, funda_vars, for_vars)

#Full sample

unconCorrF1q <- fctPairCorr(ind_sorts_long%>%filter(variable%in%all_variables&horizon=='1q'))

unconCorrF1q$subsample='Full Sample'

#Pre-GFC
unconCorrPreGFC <- fctPairCorr(ind_sorts_long%>%filter((date<=pre_GFC)&(variable%in%all_variables)&horizon=='1q'))

unconCorrPreGFC$subsample='Pre-GFC'

#Post-GFC
unconCorrPostGFC <- fctPairCorr(ind_sorts_long%>%filter((date>post_GFC)&(variable%in%all_variables)&horizon=='1q'))

unconCorrPostGFC$subsample='Post-GFC'

#Ex-Recession
unconCorrExRec <- fctPairCorr(ind_sorts_long%>%filter((date%ni%quarter_recessions)&(variable%in%all_variables)&horizon=='1q'))

unconCorrExRec$subsample='Ex-Recessions'

#Annual frequency

unconCorrF1y <- fctPairCorr(ind_sorts_long%>%filter(month(date)==12&(variable%in%all_variables)&horizon=='1y'))

unconCorrF1y$subsample='Annual'

unconCorr<-bind_rows(unconCorrF1q, unconCorrPreGFC, unconCorrPostGFC, 
                          unconCorrExRec, unconCorrF1y)

save(unconCorr, file = paste0(est_dir, 'unconCorr.RData'))


## 1.B Calculate residuals for excess correlation --------------------------


#For sub-sample analyses I estimate first-pass within each sub-sample

# Default risk on equity moments

#Naming: yvarResControlsFrequency:

#defResEqF1q: residual of default vars on equity vars using 1q frequency and different horizons

# Do this after specifying the horizon

tmp_agg<-AggShocks%>%filter(horizon=='1q')%>%pivot_wider(id_cols=date , names_from=variable, values_from=value)

data_F1q<-ind_sorts_long%>%filter(horizon=='1q')%>%
  inner_join(tmp_agg, by='date')%>%
  pivot_wider(id_cols=all_of(c('date', 'ffi48','horizon', agg_vars)), 
              names_from = variable, 
              values_from = value)  # Pivot to wide format

#Quarterly frequency full sample
defResEqF1q<-fctTSRes(
  data_F1q,
  yvars = def_vars,
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqF1q$subsample='Full Sample'

#Pre-GFC
defResEqPreGFC<-fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars = setdiff(def_vars, 'CS5y'),  # CS5y is not available before 2002-9-30),
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqPreGFC$subsample='Pre-GFC'

#Post-GFC
defResEqPostGFC <-fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = def_vars,
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqPostGFC$subsample='Post-GFC'

#ExRec
defResEqExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = def_vars,
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqExRec$subsample='Ex-Recessions'

#Annual Frequency

#Matched annual industry data and agg shocks.

tmp_agg<-AggShocks%>%filter(horizon=='1y')%>%pivot_wider(id_cols=date , names_from=variable, values_from=value)

data_F1y<-ind_sorts_long%>%
  filter(month(date)==12&horizon=='1y')%>%
  inner_join(tmp_agg, by='date')%>%
  pivot_wider(id_cols=all_of(c('date', 'ffi48', agg_vars)), 
              names_from = variable, 
              values_from = value)  # Pivot to wide format


defResEqF1y <- fctTSRes(
  data_F1y,
  yvars = def_vars,
  ctrlVars = equity_vars
)

defResEqF1y$subsample='Annual'

defResEq<-bind_rows(defResEqF1q, defResEqPreGFC, 
                    defResEqPostGFC, defResEqExRec, defResEqF1y)



# All variables on fundamentals + aggregate shocks (+ expected earnings)


#EARN1Q

#Quarterly
allResFdAgEx1qF1q <- fctTSRes(
  data_F1q,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
) 

allResFdAgEx1qF1q$subsample='Full Sample'

#Pre-GFC
allResFdAgEx1qPreGFC <- fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars = setdiff(y_vars, 'CS5y'),
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qPreGFC$subsample='Pre-GFC'

#Post-GFC
allResFdAgEx1qPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qPostGFC$subsample='Post-GFC'

#ExRecessions
allResFdAgEx1qExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qExRec$subsample='Ex-Recessions'

#Annual

allResFdAgEx1qF1y <- fctTSRes(
  data_F1y,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qF1y$subsample='Annual'

allResFdAgEx1q <- bind_rows(allResFdAgEx1qF1q, allResFdAgEx1qPreGFC, 
                            allResFdAgEx1qPostGFC, allResFdAgEx1qExRec, allResFdAgEx1qF1y)


# Default risk on equity + fundamentals + aggregate shocks (+ expected earnings)

#Quarterly
defResEqFdAgEx1qF1q <- fctTSRes(
  data_F1q,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qF1q$subsample='Full Sample'


#Pre-GFC
defResEqFdAgEx1qPreGFC <- fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars =  setdiff(def_vars, 'CS5y'),
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qPreGFC$subsample='Pre-GFC'

#Post-GFC
defResEqFdAgEx1qPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qPostGFC$subsample='Post-GFC'

#Ex-Recessions
defResEqFdAgEx1qExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qExRec$subsample='Ex-Recessions'

#Annual
defResEqFdAgEx1qF1y <- fctTSRes(
  data_F1y,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qF1y$subsample='Annual'


defResEqFdAgEx1q <- bind_rows(defResEqFdAgEx1qF1q, defResEqFdAgEx1qPreGFC, 
                              defResEqFdAgEx1qPostGFC, defResEqFdAgEx1qExRec, defResEqFdAgEx1qF1y)




## Sub-samples used by the bootstrap below.
subsamples<- c("Full Sample", "Pre-GFC", "Post-GFC", "Ex-Recessions", "Annual")

# 2. Bootstrap total and excess correlations ----------------------------------
#Remove CS5y from pre-GFC calculations

## 2.A Total correlations --------------------------------------------------
# I cannot really put default orthogonalized to equity total correlation here, as the residual is computed over each subsample. Moreover, the sub-samples do not overlap with each other.

# Variables to calculate unconditional corr SE
variables <- c("SIGMA", "PROB", "CS5y", "MKTLEV", "BOOKLEV", "EXRET", "ASSETS", "CASHMTA", "EBITDA", "NIMTA", "PROFIT", "SALES", "EARN1Q")

# Unrelated industry pairs

data_F1q<-ind_sorts_long%>%
  filter(horizon=='1q')%>%select(-horizon)

#Full sample
unconCorrBstrap18F1q <-data_F1q%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18F1q <-unconCorrBstrap18F1q %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18F1q$subsample<-"Full Sample"


#Pre-GFC
unconCorrBstrap18PreGFC <-data_F1q%>%
  filter(date<=pre_GFC)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18PreGFC <-unconCorrBstrap18PreGFC %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18PreGFC$subsample<-"Pre-GFC"

#Post-GFC
unconCorrBstrap18PostGFC <-data_F1q%>%
  filter(date>post_GFC)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18PostGFC <-unconCorrBstrap18PostGFC %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18PostGFC$subsample<-"Post-GFC"

#Ex-Recessions
unconCorrBstrap18ExRec <-data_F1q%>%
  filter(date%ni%quarter_recessions)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18ExRec <-unconCorrBstrap18ExRec %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18ExRec$subsample<-"Ex-Recessions"

#Annual frequency

unconCorrBstrap18F1y <-ind_sorts_long%>%
  filter(month(date)==12&horizon=='1y')%>%select(-horizon)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18F1y <-unconCorrBstrap18F1y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18F1y$subsample<-"Annual"


#Combine all subsamples
unconCorrBstrap18 <- bind_rows(
  unconCorrBstrap18F1q,
  unconCorrBstrap18PreGFC,
  unconCorrBstrap18PostGFC,
  unconCorrBstrap18ExRec,
  unconCorrBstrap18F1y
)


save(unconCorrBstrap18, file = paste0(est_dir, "length", block_length, "/unconCorrBstrap18.RData"))


# All industry pairs

#Full sample
unconCorrBstrapF1q <-data_F1q%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapF1q <-unconCorrBstrapF1q %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapF1q$subsample<-"Full Sample"

#Pre-GFC
unconCorrBstrapPreGFC <-data_F1q%>%
  filter(date<=pre_GFC)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapPreGFC <-unconCorrBstrapPreGFC %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapPreGFC$subsample<-"Pre-GFC"

#Post-GFC
unconCorrBstrapPostGFC <-data_F1q%>%
  filter(date>post_GFC)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapPostGFC <-unconCorrBstrapPostGFC %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapPostGFC$subsample<-"Post-GFC"

#Ex-Recessions
unconCorrBstrapExRec <-data_F1q%>%
  filter(date%ni%quarter_recessions)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapExRec <-unconCorrBstrapExRec %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapExRec$subsample<-"Ex-Recessions"

#Annual frequency

unconCorrBstrapF1y <-ind_sorts_long%>%
  filter(horizon=='1y'&month(date)==12)%>%select(-horizon)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapF1y <-unconCorrBstrapF1y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapF1y$subsample<-"Annual"

#Combine all subsamples
unconCorrBstrap <- bind_rows(
  unconCorrBstrapF1q,
  unconCorrBstrapPreGFC,
  unconCorrBstrapPostGFC,
  unconCorrBstrapExRec,
  unconCorrBstrapF1y
)

save(unconCorrBstrap, file = paste0(est_dir, "length", block_length, "/unconCorrBstrap.RData"))

## 2.B Excess correlations -------------------------------------------------

# Default probability orthogonalized to equity moments (PROB|Eq)

# Unrelated industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEq%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs , B, block_length, num_cores)
  
   tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
   
   tmp$subsample <- sub
   

   CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqBstrap18<-CorrBstrapTbl

saveRDS(defCorrEqBstrap18, file = paste0(est_dir, "length", block_length, "/defCorrEqBstrap18.rds"))

# All industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEq%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars,  NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)

}

defCorrEqBstrap<-CorrBstrapTbl

saveRDS(defCorrEqBstrap, file = paste0(est_dir, "length", block_length, "/defCorrEqBstrap.rds"))


# All variables on fundamentals + aggregate shocks + expected earnings



## Unrelated industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1qBstrap18<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1qBstrap18.rds"))

## All industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1qBstrap<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1qBstrap.rds"))



# Default risk on equity + fundamentals + aggregate shocks + expected earnings


## Unrelated industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars,  unrelated_pairs , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1qBstrap18<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1qBstrap18.rds"))

## All industry pairs

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1qBstrap<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1qBstrap.rds"))


# 3. Excess correlations by size and book-leverage terciles -------------------

## 3.A Size terciles, market-capitalization share (top vs. bottom) ---------

MSHARE3Bin<-fctSort(ind_vars,MSHARE, 3)

pairsT3<-MSHARE3Bin%>%filter(bin==3)

pairsT1<-MSHARE3Bin%>%filter(bin==1)

# All variables


CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1qBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1qBstrapMV3.rds"))

# Default risk


CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1qBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1qBstrapMV3.rds"))


## 3.B Book-leverage terciles (top vs. bottom) -----------------------------
BOOKLEV3Bin<-fctSort(ind_vars,BOOKLEV, 3)

pairsT3<-BOOKLEV3Bin%>%filter(bin==3)

pairsT1<-BOOKLEV3Bin%>%filter(bin==1)

# All variables


CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1qBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1qBstrapBOOKLEV3.rds"))

# Default risk


CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1q%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1qBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1qBstrapBOOKLEV3.rds"))


