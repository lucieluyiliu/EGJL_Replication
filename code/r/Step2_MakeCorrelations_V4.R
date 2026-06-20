# Calculate correlations as correlations between residuals from time-series regressions
# Control for macro not fundamentals

# 2025-01-22, simplify macro variable to only control for all of them
# Simplify first-pass regression to use only panel regression

# 2025-01-31 Add Logit without equity price return and volatility
# Environment--------

# 2025-07-03 first attempt to incorporate different horizons

# 2025-07-11: V3 introduces excess correlation controlling for expected earnings.
# To reduce the number of combinations, focus on 1q different forecasting horizons
# Or 1y frequency and forecast horizon.

#2025-09-30: V4 simplifies to only do sub-sample for quarterly, do 1yr and 2yr frequency matching horizon.
#Keep only 1-year forecasted earnings.

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
## --- Paths (MNSC item 13: relative paths; run from the package root) ---------
source("config.R")              # path, data_dir, est_dir, table_dir, fig_dir
est_dir0 <- paste0(data_dir, 'Estimates_2025Aug/')   # legacy dir; not shipped in package
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

for_vars=c('EARN1Q','EARN1Y')

#Bootstrapping parameters

seed<-123

set.seed(seed) 

B<-1000

block_length=4

# Specify the subfolder to create

length_folder <- file.path(est_dir, paste0("length", block_length))

# Check if the folder exists; if not, create it
if (!dir.exists(length_folder)) {
  dir.create(length_folder, recursive = TRUE)
  cat("Folder created:", length_folder, "\n")
} else {
  cat("Folder already exists:", length_folder, "\n")
}

# Fixed worker count for bootstrap reproducibility (MNSC item 13/17).
# The published estimates were generated on the university M3 Mac, where
# detectCores()-1 = 16-1 = 15. clusterSetRNGStream assigns one RNG stream per
# worker, so the worker count must be held at 15 to reproduce the exact SEs on
# any machine (works on machines with fewer cores too — just slower).
num_cores <- 15

ifUpdateCorr<-T

ifCreateWorkBook<-T

# Load data --------------------------------------------------------
# (Note that here I use variables from the Campbell paper, from Alex)

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
    variable = str_remove(variable, "_(1q|1y|2y|5y)$"))%>%
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
    horizon=ifelse(horizon%in%c('1q','1y','2y','5y'), horizon, '0')
  )

horizons <- setdiff(unique(ind_sorts_long$horizon), '0') # Exclude '0' horizon

#Industry-level variable range: CS available 2002-12-31 to 2022-09-30, all others available througout.
ind_date_range<-ind_sorts_long%>%
  filter(!is.na(value)) %>%  
  group_by(variable, horizon) %>%
  summarise(start_date = min(date), end_date = max(date)) %>%
  ungroup()

## Industry pairs---------------

industry_pairs <- ind_sorts %>% fctFormPairs()

#Check whether pairwise correlation changes with horizon

#Unrelated pairs
unrelated_pairs<-industry_pairs%>%filter(pairname%in%unrelated_pairnames)

all_variables <- c(y_vars,funda_vars, for_vars)

#Compute industry-level avarage for industry sorts
ind_vars <- ind_sorts %>%
  select(ffi48, Name, date, DEBTST=debtST, MSHARE=mktcap_share,ESHARE=ebitda_share,ASHARE=assets_share,MAT=avgmat, BOOKLEV=book_leverage)%>%
  group_by(ffi48, Name) %>%
  summarise(across(
    c(DEBTST , MSHARE, ESHARE, ASHARE, MAT, BOOKLEV),
    function(x) mean(x, na.rm = TRUE)
  ))%>%
  ungroup()


# Import aggregate shocks

AggShocks<-read_csv(paste0(data_dir, 'AggShocks/Agg_shocks.csv'))%>%
  filter(date>=start_date)%>%
  select("date","IP_pct_1q","IP_pct_1y","IP_pct_2y",
         "DeltaLiq_1q","DeltaLiq_1y","DeltaLiq_2y",      
         "CFNAI_diff_1q", "CFNAI_diff_1y" ,"CFNAI_diff_2y",
         "EPU_pct_1q","EPU_pct_1y","EPU_pct_2y",     
         "UNRATE_diff_1q", "UNRATE_diff_1y", "UNRATE_diff_2y", 
         "MacroU_diff_1q" ,"MacroU_diff_1y", "MacroU_diff_2y",
         "RealU_diff_1q", "RealU_diff_1y", "RealU_diff_2y",
         "FinU_diff_1q", "FinU_diff_1y","FinU_diff_2y",    
          "NGDP_1q" ,"NGDP_1y" ,"NGDP_2y", 
          "FEDFUNDS_diff_1q", "FEDFUNDS_diff_1y", "FEDFUNDS_diff_2y",
          "DeltaICR_1q", "DeltaICR_1y","DeltaICR_2y" )%>%
  pivot_longer(cols=-c(date), names_to = "variable", values_to = "value")%>%
  mutate(# Extract horizon: last piece after last "_"
    horizon = str_extract(variable, "[^_]+$"),
    # Remove _pct_* or _diff_* at the end to get variable
    variable = str_remove(variable, "_(pct|diff)_[^_]+$"),
    variable = str_remove(variable, "_(1q|1y|2y|5y)$"))

#Availability of variables: Aggregate shocks are available till 2024-12-30, except for HKM Intermediary shock which is avaialiable until 2024-06-30
aggshock_date_range<-AggShocks%>%
  filter(!is.na(value)&horizon=='1q') %>%  
  group_by(variable) %>%
  summarise(start_date = min(date), end_date = max(date)) %>%
  ungroup()
  
  

if (ifUpdateCorr){

# Unconditional correlations and standard errors for quarterly frequency various horizons----------

all_variables <- c(y_vars, funda_vars, for_vars)

#Full sample

unconCorrF1q <- fctPairCorr(ind_sorts_long%>%filter(variable%in%all_variables&horizon=='1q'))

unconCorrF1q$subsample='Full Sample'

#Old sample (to 2020Q4)

unconCorrPre2021 <- fctPairCorr(ind_sorts_long%>%filter((date<=as.Date('2020-12-31'))&(variable%in%all_variables)&horizon=='1q'))

unconCorrPre2021$subsample='Till 2020Q4'

#Pre-GFC
unconCorrPreGFC <- fctPairCorr(ind_sorts_long%>%filter((date<=pre_GFC)&(variable%in%all_variables)&horizon=='1q'))

unconCorrPreGFC$subsample='Pre-GFC'

#Post-GFC
unconCorrPostGFC <- fctPairCorr(ind_sorts_long%>%filter((date>post_GFC)&(variable%in%all_variables)&horizon=='1q'))

unconCorrPostGFC$subsample='Post-GFC'

#Ex-Recession
unconCorrExRec <- fctPairCorr(ind_sorts_long%>%filter((date%ni%quarter_recessions)&(variable%in%all_variables)&horizon=='1q'))

unconCorrExRec$subsample='Ex-Recessions'

#ExCovid
unconCorrExCovid <- fctPairCorr(ind_sorts_long%>%filter((date>post_GFC)&(date %ni% quarter_covid)&(variable%in%all_variables)&horizon=='1q'))

unconCorrExCovid$subsample='Ex-Covid'

#Annual frequency

unconCorrF1y <- fctPairCorr(ind_sorts_long%>%filter(month(date)==12&(variable%in%all_variables)&horizon=='1y'))

unconCorrF1y$subsample='Annual'

#Biennial (1987, 1989, 1991, ..., 2023)

unconCorrF2y <- fctPairCorr(ind_sorts_long%>%filter(horizon=='2y'&month(date)==12&year(date)%%2==1&(variable%in%all_variables)))

unconCorrF2y$subsample='Biennial'

unconCorr<-bind_rows(unconCorrF1q, unconCorrPre2021, unconCorrPreGFC, unconCorrPostGFC, 
                          unconCorrExRec, unconCorrExCovid, unconCorrF1y, unconCorrF2y)

save(unconCorr, file = paste0(est_dir, 'unconCorr.RData'))


# Excess correlation based on time series residuals--------------

## Calculate residuals------

#For sub-sample analyses I estimate first-pass within each sub-sample

### 1.  First orthogonalize default vars w.r.t. equity vars only-------

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

#Quarterly frequency old sample
defResEqPre2021<-fctTSRes(
  data_F1q%>%filter(date<=as.Date("2020-12-31")),
  yvars = def_vars,
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqPre2021$subsample='Till 2020Q4'

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

#ExCovid
defResEqExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC) &(date %ni% quarter_covid)),
  yvars = def_vars,
  ctrlVars = equity_vars,
  aggVars = "None"
)

defResEqExCovid$subsample='Ex-Covid'

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

#Biennial Frequency

tmp_agg<-AggShocks%>%filter(horizon=='2y')%>%pivot_wider(id_cols=date , names_from=variable, values_from=value)

data_F2y<-ind_sorts_long%>%
  filter(horizon=='2y'&month(date)==12&year(date)%%2==1)%>%
  inner_join(tmp_agg, by='date')%>%
  pivot_wider(id_cols=all_of(c('date', 'ffi48', agg_vars)), 
              names_from = variable, 
              values_from = value)  # Pivot to wide format


defResEqF2y <- fctTSRes(
  data_F2y,
  yvars = def_vars,
  ctrlVars = equity_vars
)

defResEqF2y$subsample='Biennial'

defResEq<-bind_rows(defResEqF1q, defResEqPre2021, defResEqPreGFC, 
                    defResEqPostGFC, defResEqExRec, defResEqExCovid, defResEqF1y, defResEqF2y)


save(defResEq, file=paste0(est_dir, "defResEq.RData"))

### 2. All vars control for funda and agg------

#### Without earnings forecast---------- 

#quarterly
allResFdAgF1q <- fctTSRes(
  data_F1q,
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgF1q$subsample='Full Sample'

#Oldsample
allResFdAgPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date('2020-12-31')),
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgPre2021$subsample='Till 2020Q4'

#pre-GFC
allResFdAgPreGFC <-  fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars = setdiff(y_vars, 'CS5y'),
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgPreGFC$subsample='Pre-GFC'

#PostGFC
allResFdAgPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgPostGFC$subsample='Post-GFC'

#ExRecessions
allResFdAgExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgExRec$subsample='Ex-Recessions'

#ExCovid
allResFdAgExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC)&(date%ni%quarter_covid)),
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgExCovid$subsample='Ex-Covid'

#Annual
allResFdAgF1y <- fctTSRes(
  data_F1y,
  yvars = y_vars,
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgF1y$subsample='Annual'

#Biennial 
allResFdAgF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = funda_vars,
  aggVars = agg_vars
)

allResFdAgF2y$subsample='Biennial'



allResFdAg<-bind_rows(allResFdAgF1q, allResFdAgPre2021, allResFdAgPreGFC, 
                          allResFdAgPostGFC, allResFdAgExRec, allResFdAgExCovid, allResFdAgF1y, allResFdAgF2y)

save(allResFdAg, file=paste0(est_dir, "allResFdAg.RData"))


#### Forecasted earnings-------

#EARN1Q

#Quarterly
allResFdAgEx1qF1q <- fctTSRes(
  data_F1q,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
) 

allResFdAgEx1qF1q$subsample='Full Sample'

#Old sample
allResFdAgEx1qPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date('2020-12-31')),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)  

allResFdAgEx1qPre2021$subsample='Till 2020Q4'

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

#ExCovid
allResFdAgEx1qExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC) & (date %ni% quarter_covid)),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qExCovid$subsample='Ex-Covid'

#Annual

allResFdAgEx1qF1y <- fctTSRes(
  data_F1y,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qF1y$subsample='Annual'

#Biennial

allResFdAgEx1qF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = c(funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

allResFdAgEx1qF2y$subsample='Biennial'

allResFdAgEx1q <- bind_rows(allResFdAgEx1qF1q, allResFdAgEx1qPre2021, allResFdAgEx1qPreGFC, 
                            allResFdAgEx1qPostGFC, allResFdAgEx1qExRec, allResFdAgEx1qExCovid, allResFdAgEx1qF1y, allResFdAgEx1qF2y)

save(allResFdAgEx1q , file=paste0(est_dir, "allResFdAgEx1q.RData"))

#EARN1Y

#Quarterly
allResFdAgEx1yF1q <- fctTSRes(
  data_F1q,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
) 

allResFdAgEx1yF1q$subsample='Full Sample'

#Old sample
allResFdAgEx1yPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date('2020-12-31')),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)  

allResFdAgEx1yPre2021$subsample='Till 2020Q4'

#Pre-GFC
allResFdAgEx1yPreGFC <- fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars = setdiff(y_vars, 'CS5y'),
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yPreGFC$subsample='Pre-GFC'

#Post-GFC
allResFdAgEx1yPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yPostGFC$subsample='Post-GFC'

#ExRecessions
allResFdAgEx1yExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yExRec$subsample='Ex-Recessions'

#ExCovid
allResFdAgEx1yExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC) & (date %ni% quarter_covid)),
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yExCovid$subsample='Ex-Covid'

#Annual

allResFdAgEx1yF1y <- fctTSRes(
  data_F1y,
  yvars = y_vars,
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yF1y$subsample='Annual'

#Biennial

allResFdAgEx1yF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = c(funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

allResFdAgEx1yF2y$subsample='Biennial'

allResFdAgEx1y <- bind_rows(allResFdAgEx1yF1q, allResFdAgEx1yPre2021, allResFdAgEx1yPreGFC, 
                          allResFdAgEx1yPostGFC, allResFdAgEx1yExRec, allResFdAgEx1yExCovid, allResFdAgEx1yF1y, allResFdAgEx1yF2y)

save(allResFdAgEx1y , file=paste0(est_dir, "allResFdAgEx1y.RData"))


### 3. Default residuals controlling for everything-------

#### Without expectations ------

#Quarterly

defResEqFdAgF1q <- fctTSRes(
  data_F1q,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgF1q$subsample='Full Sample'

#Old sample

defResEqFdAgPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date("2020-12-31")),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgPre2021$subsample='Till 2020Q4'


#Pre-GFC
defResEqFdAgPreGFC <- fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars =  setdiff(def_vars, 'CS5y'),
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgPreGFC$subsample='Pre-GFC'

#Post-GFC
defResEqFdAgPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgPostGFC$subsample='Post-GFC'

#ExRec
defResEqFdAgExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgExRec$subsample='Ex-Recessions'

#ExCovid
defResEqFdAgExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC) & (date%ni%quarter_covid)),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgExCovid$subsample='Ex-Covid'


#Annual
defResEqFdAgF1y <- fctTSRes(
  data_F1y,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgF1y$subsample='Annual'

#Biennial

defResEqFdAgF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = c(equity_vars, funda_vars),
  aggVars = agg_vars
)

defResEqFdAgF2y$subsample='Biennial'

defResEqFdAg <- bind_rows(defResEqFdAgF1q, defResEqFdAgPre2021, defResEqFdAgPreGFC, 
                          defResEqFdAgPostGFC, defResEqFdAgExRec, defResEqFdAgExCovid, defResEqFdAgF1y, defResEqFdAgF2y)

save(defResEqFdAg, file=paste0(est_dir, "defResEqFdAg.RData"))

#### With expected earnings--------

#EARN1Q

#Quarterly
defResEqFdAgEx1qF1q <- fctTSRes(
  data_F1q,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qF1q$subsample='Full Sample'


#Old sample
defResEqFdAgEx1qPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date('2020-12-31')),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qPre2021$subsample='Till 2020Q4'

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

#Ex-Covid
defResEqFdAgEx1qExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC )& (date %ni% quarter_covid)),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qExCovid$subsample='Ex-Covid'

#Annual
defResEqFdAgEx1qF1y <- fctTSRes(
  data_F1y,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qF1y$subsample='Annual'

#Biennial

defResEqFdAgEx1qF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Q'),
  aggVars = agg_vars
)

defResEqFdAgEx1qF2y$subsample='Biennial'



defResEqFdAgEx1q <- bind_rows(defResEqFdAgEx1qF1q, defResEqFdAgEx1qPre2021, defResEqFdAgEx1qPreGFC, 
                              defResEqFdAgEx1qPostGFC, defResEqFdAgEx1qExRec, defResEqFdAgEx1qExCovid, defResEqFdAgEx1qF1y, defResEqFdAgEx1qF2y)

save(defResEqFdAgEx1q , file=paste0(est_dir, "defResEqFdAgEx1q.RData"))



#EARN1Y

#Quarterly
defResEqFdAgEx1yF1q <- fctTSRes(
  data_F1q,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yF1q$subsample='Full Sample'


#Old sample
defResEqFdAgEx1yPre2021 <- fctTSRes(
  data_F1q%>%filter(date<=as.Date('2020-12-31')),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yPre2021$subsample='Till 2020Q4'

#Pre-GFC
defResEqFdAgEx1yPreGFC <- fctTSRes(
  data_F1q%>%filter(date<=pre_GFC),
  yvars =  setdiff(def_vars, 'CS5y'),
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yPreGFC$subsample='Pre-GFC'

#Post-GFC
defResEqFdAgEx1yPostGFC <- fctTSRes(
  data_F1q%>%filter(date>post_GFC),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yPostGFC$subsample='Post-GFC'

#Ex-Recessions
defResEqFdAgEx1yExRec <- fctTSRes(
  data_F1q%>%filter(date%ni%quarter_recessions),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yExRec$subsample='Ex-Recessions'

#Ex-Covid
defResEqFdAgEx1yExCovid <- fctTSRes(
  data_F1q%>%filter((date>post_GFC )& (date %ni% quarter_covid)),
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yExCovid$subsample='Ex-Covid'

#Annual
defResEqFdAgEx1yF1y <- fctTSRes(
  data_F1y,
  yvars = def_vars,
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yF1y$subsample='Annual'

#Biennial

defResEqFdAgEx1yF2y <- fctTSRes(
  data_F2y,
  yvars = setdiff(y_vars, 'CS5y'), #CS5y only start in 2002-12-31, don't have sufficient length for biennial
  ctrlVars = c(equity_vars, funda_vars, 'EARN1Y'),
  aggVars = agg_vars
)

defResEqFdAgEx1yF2y$subsample='Biennial'

defResEqFdAgEx1y <- bind_rows(defResEqFdAgEx1yF1q, defResEqFdAgEx1yPre2021, defResEqFdAgEx1yPreGFC, 
                          defResEqFdAgEx1yPostGFC, defResEqFdAgEx1yExRec, defResEqFdAgEx1yExCovid, defResEqFdAgEx1yF1y, defResEqFdAgEx1yF2y)

save(defResEqFdAgEx1y , file=paste0(est_dir, "defResEqFdAgEx1y.RData"))


##  Conditional Correlation of time-series residuals-------

subsamples<- c("Full Sample", "Till 2020Q4", "Pre-GFC", "Post-GFC", "Ex-Recessions", "Ex-Covid", "Annual","Biennial")


### 1. Correlation in default var conditional on equity------

CorrTbl<-defResEq%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample")  )

saveRDS(CorrTbl, file = paste0(est_dir, "defCorrEq.rds"))


### 2-A. Conditional corr of all variables controlling fundamentals -------

CorrTbl<-allResFdAg%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample")  )

#check avgExcessCorr<-CorrTbl%>%group_by(subsample, variable)%>%summarise(meanCorr=mean(corr))

saveRDS(CorrTbl, file = paste0(est_dir, "allCorrFdAg.rds"))

### 2-B. Conditional corr of all variables controlling fundamentals and expectations -------

#Ex1q

CorrTbl<-allResFdAgEx1q%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample"))

saveRDS(CorrTbl, file = paste0(est_dir, "allCorrFdAgEx1q.rds"))

#Ex1y


CorrTbl<-allResFdAgEx1y%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample"))

saveRDS(CorrTbl, file = paste0(est_dir, "allCorrFdAgEx1y.rds"))


### 3-A. Conditional Correlation of default vars controlling for funda and agg----------

CorrTbl<-defResEqFdAg%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample"))

saveRDS(CorrTbl, file = paste0(est_dir, "defCorrEqFdAg.rds"))

### 3-B. Conditional Correlation of default vars controlling for funda agg and expectations----------

#Ex1q

CorrTbl<-defResEqFdAgEx1q%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample"))

saveRDS(CorrTbl, file = paste0(est_dir, "defCorrEqFdAgEx1q.rds"))

#Ex1y

CorrTbl<-defResEqFdAgEx1y%>%rename(value=res)%>%fctPairCorr(., group_vars=c("subsample"))

saveRDS(CorrTbl, file = paste0(est_dir, "defCorrEqFdAgEx1y.rds"))

}

# Cleared up to this stage

# Bootstrapping---------
#Remove CS5y from pre-GFC calculations

## Total Correlation--------
# I cannot really put default orthogonalized to equity total correlation here, as the residual is computed over each subsample. Moreover, the sub-samples do not overlap with each other.

# Variables to calculate unconditional corr SE
variables <- c("SIGMA", "PROB", "CS5y", "MKTLEV", "BOOKLEV", "EXRET", "ASSETS", "CASHMTA", "EBITDA", "NIMTA", "PROFIT", "SALES", "EARN1Q", "EARN1Y")

### Unrelated pairs---------

data_F1q<-ind_sorts_long%>%
  filter(horizon=='1q')%>%select(-horizon)

#Full sample
unconCorrBstrap18F1q <-data_F1q%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18F1q <-unconCorrBstrap18F1q %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18F1q$subsample<-"Full Sample"


#Old sample
unconCorrBstrap18Pre2021 <-data_F1q%>%
  filter(date<=as.Date('2020-12-31'))%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18Pre2021 <-unconCorrBstrap18Pre2021 %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18Pre2021$subsample<-"Till 2020Q4"

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

#Ex-Covid
unconCorrBstrap18ExCovid <-data_F1q%>%
  filter((date>post_GFC)&(date %ni% quarter_covid))%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18ExCovid <-unconCorrBstrap18ExCovid %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18ExCovid$subsample<-"Ex-Covid"

#Annual frequency

unconCorrBstrap18F1y <-ind_sorts_long%>%
  filter(month(date)==12&horizon=='1y')%>%select(-horizon)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18F1y <-unconCorrBstrap18F1y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18F1y$subsample<-"Annual"

#Biennial frequency

unconCorrBstrap18F2y <-ind_sorts_long%>%
  filter(horizon=='2y'&month(date)==12&year(date)%%2==1)%>%select(-horizon)%>%
  fctBstrapAll(., variables, unrelated_pairs, B, block_length, num_cores)

unconCorrBstrap18F2y <-unconCorrBstrap18F2y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrap18F2y$subsample<-"Biennial"


#Combine all subsamples
unconCorrBstrap18 <- bind_rows(
  unconCorrBstrap18F1q,
  unconCorrBstrap18Pre2021,
  unconCorrBstrap18PreGFC,
  unconCorrBstrap18PostGFC,
  unconCorrBstrap18ExRec,
  unconCorrBstrap18ExCovid,
  unconCorrBstrap18F1y,
  unconCorrBstrap18F2y
)


save(unconCorrBstrap18, file = paste0(est_dir, "length", block_length, "/unconCorrBstrap18.RData"))


### Correlated pairs------

#Full sample
unconCorrBstrapF1q <-data_F1q%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapF1q <-unconCorrBstrapF1q %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapF1q$subsample<-"Full Sample"

#Old sample
unconCorrBstrapPre2021 <-data_F1q%>%
  filter(date<=as.Date('2020-12-31'))%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapPre2021 <-unconCorrBstrapPre2021 %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapPre2021$subsample<-"Till 2020Q4"

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

#Ex-Covid
unconCorrBstrapExCovid <-data_F1q%>%
  filter( (date>post_GFC) & (date %ni% quarter_covid) )%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapExCovid <-unconCorrBstrapExCovid %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapExCovid$subsample<-"Ex-Covid"

#Annual frequency

unconCorrBstrapF1y <-ind_sorts_long%>%
  filter(horizon=='1y'&month(date)==12)%>%select(-horizon)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapF1y <-unconCorrBstrapF1y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapF1y$subsample<-"Annual"

#Biennial frequency
unconCorrBstrapF2y <-ind_sorts_long%>%
  filter(horizon=='2y'&month(date)==12&year(date)%%2==1)%>%select(-horizon)%>%
  fctBstrapAll(., variables, NULL, B, block_length, num_cores)

unconCorrBstrapF2y <-unconCorrBstrapF2y %>%mutate(p=1-pnorm(corr/se))

unconCorrBstrapF2y$subsample<-"Biennial"

#Combine all subsamples
unconCorrBstrap <- bind_rows(
  unconCorrBstrapF1q,
  unconCorrBstrapPre2021,
  unconCorrBstrapPreGFC,
  unconCorrBstrapPostGFC,
  unconCorrBstrapExRec,
  unconCorrBstrapExCovid,
  unconCorrBstrapF1y,
  unconCorrBstrapF2y
)

save(unconCorrBstrap, file = paste0(est_dir, "length", block_length, "/unconCorrBstrap.RData"))

## Excess correlation-----------

### 1.  Default controlling for equity------

#### Unrelated pairs------

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

#### Correlated pairs ------------

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


### 2-A. All variables control for fundamentals and aggregate shocks------

#### Unrelated pairs------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgBstrap18<-CorrBstrapTbl

saveRDS(allCorrFdAgBstrap18, file = paste0(est_dir, "length", block_length, "/allCorrFdAgBstrap18.rds"))

#### Correlated pairs ------------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgBstrap<-CorrBstrapTbl

saveRDS(allCorrFdAgBstrap, file = paste0(est_dir, "length", block_length, "/allCorrFdAgBstrap.rds"))


### 2-B. All variables control for fundamentals and aggregate shocks plus expectations------


#### EARN1Q----

##### Unrelated pairs------

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

##### Correlated pairs ------------

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



#### EARN1Y----

##### Unrelated pairs------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  
  data<-allResFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs,  B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
  allCorrFdAgEx1yBstrap18<-CorrBstrapTbl
  
}

allCorrFdAgEx1yBstrap18<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1yBstrap18.rds"))

##### Correlated pairs ------------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1yBstrap<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1yBstrap.rds"))

### 3-A. Default controlling for equity, fundamental, and agg variables------

#### Unrelated pairs------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgBstrap18<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgBstrap18.rds"))

#### Correlated pairs ------------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgBstrap<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgBstrap.rds"))

### 3-B. Default controlling for equity, fundamental, and agg variables and expectation------

#### EARN1Q--------

##### Unrelated pairs------

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

##### Correlated pairs ------------

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


#### EARN1Y--------

##### Unrelated pairs------

CorrBstrapTbl<-tibble()

for (sub in subsamples){

  data<-defResEqFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars, unrelated_pairs , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  
  CorrBstrapTbl <- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1yBstrap18<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1yBstrap18.rds"))

##### Correlated pairs ------------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll(., vars,  NULL , B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(corr/se))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1yBstrap<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1yBstrap.rds"))


# Excess corr by MKTCAP share terciles-----

MSHARE3Bin<-fctSort(ind_vars,MSHARE, 3)

pairsT3<-MSHARE3Bin%>%filter(bin==3)

pairsT1<-MSHARE3Bin%>%filter(bin==1)

## 1-A.  Excess correlation control for fundamentals ------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgBstrapMV3.rds"))

## 1-B.  Excess correlation control for fundamentals and expected earnings------

### EARN1Q---------

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

### EARN1Y-----------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1yBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1yBstrapMV3.rds"))


## 1-A.  Default correlation controlling for equity, agg, funda -------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgBstrapMV3.rds"))


## 1-B.  Default correlation controlling for equity, agg, funda and expected earnings-------

### EARN1Q-------

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


### EARN1Y-------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1yBstrapMV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1yBstrapMV3.rds"))



# Excess corr by BOOKLEV terciles-----
BOOKLEV3Bin<-fctSort(ind_vars,BOOKLEV, 3)

pairsT3<-BOOKLEV3Bin%>%filter(bin==3)

pairsT1<-BOOKLEV3Bin%>%filter(bin==1)

## 1-A.  Excess correlation control for fundamentals ------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgBstrapBOOKLEV3.rds"))

## 1-B.  Excess correlation control for fundamentals and expected earnings------

### EARN1Q---------

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

### EARN1Y-----------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1yBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1yBstrapBOOKLEV3.rds"))

## 1-A.  Default correlation controlling for equity, agg, funda -------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgBstrapBOOKLEV3.rds"))


## 1-B.  Default correlation controlling for equity, agg, funda and expected earnings-------

### EARN1Q-------

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


### EARN1Y-------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1yBstrapBOOKLEV3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1yBstrapBOOKLEV3.rds"))


# Excess corr by DEBTST terciles-----
DEBTST3Bin<-fctSort(ind_vars,DEBTST, 3)

pairsT3<-DEBTST3Bin%>%filter(bin==3)

pairsT1<-DEBTST3Bin%>%filter(bin==1)

## 1-A.  Excess correlation control for fundamentals ------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgBstrapDEBTST3.rds"))

## 1-B.  Excess correlation control for fundamentals and expected earnings------

### EARN1Q---------

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

allCorrFdAgEx1qBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1qBstrapDEBTST3.rds"))

### EARN1Y-----------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-allResFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

allCorrFdAgEx1yBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/allCorrFdAgEx1yBstrapDEBTST3.rds"))

## 1-A.  Default correlation controlling for equity, agg, funda -------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAg%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgBstrapDEBTST3.rds"))


## 1-B.  Default correlation controlling for equity, agg, funda and expected earnings-------

### EARN1Q-------

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

defCorrEqFdAgEx1qBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1qBstrapDEBTST3.rds"))


### EARN1Y-------

CorrBstrapTbl<-tibble()

for (sub in subsamples){
  data<-defResEqFdAgEx1y%>%
    filter(subsample==sub)
  
  vars<-data$variable%>%unique()
  
  tmp<-data%>%
    rename(value=res)%>%
    fctBstrapAll2(., vars, pairsT3, pairsT1, B, block_length, num_cores)
  
  tmp<-tmp%>%mutate(p=1-pnorm(diff/sediff))
  
  tmp$subsample <- sub
  
  CorrBstrapTbl<- bind_rows(CorrBstrapTbl, tmp)
  
}

defCorrEqFdAgEx1yBstrapDEBTST3<-CorrBstrapTbl

saveRDS(CorrBstrapTbl, file = paste0(est_dir, "length", block_length, "/defCorrEqFdAgEx1yBstrapDEBTST3.rds"))


