#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created:       2025-01-29
Last modified: 2026-06-22
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Computes the firm-level default probability (cdr/PROB). Builds the Campbell-style
predictors from raw_data.hdf + sigma.h5 (winsorized 5%/95%), applies the published
logit coefficients in drcoefficients2021.xlsx, and aggregates equal- and value-
weighted PROB. The S&P 500 series (for rsize/exret) is pulled live from WRDS CRSP.
Inputs:  raw_data.hdf, sigma.h5, drcoefficients2021.xlsx, WRDS (crsp.msp500_v2)
Outputs: PROB.h5, PROB_agg.csv
Validation: campbelldefrisk_2021.sas7bdat holds Kevin Aretz's precomputed CDR; the
"Compare with Kevin Aretz" block cross-checks this script's output against it and is
not an input to the results.
"""

#* ************************************** */
#* Libraries                              */
#* ************************************** */

import pandas as pd
import numpy as np
import os
from tqdm import tqdm
from pandas.tseries.offsets import *
import pyreadstat
import wrds
tqdm.pandas()

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path, wrds_username

data_dir='Data/'

start_date='1/1/1986'

end_date='12/31/2024'

os.chdir(path)

# Read stock characteristic anomalies
dfstock=\
pd.read_hdf(path+data_dir+'raw_data.hdf',
             key = "daily")

dfstock.reset_index(inplace=True)

#Get S&P 500 monthly

conn=wrds.Connection(wrds_username=wrds_username)   # WRDS username from config.py

# Get S&P 500 constituents
sp500 = conn.raw_sql(f"""
    SELECT caldt as date, usdval, sprtrn
    FROM crsp.msp500_v2
  where caldt>='{start_date}' and caldt<='{end_date}'
""")

sp500['date']=pd.to_datetime(sp500['date'])

sp500['jdate']=sp500['date']+MonthEnd(0)

sp500.drop(columns=['date'], inplace=True)

#Check variable first start date at the stock level

dfstock_start_dic={}

for column in dfstock.columns:
    first_non_null_date=dfstock.dropna(subset=[column]).jdate.min()
    dfstock_start_dic[column]=first_non_null_date

dfstock_start=pd.DataFrame(list(dfstock_start_dic.items()), columns=['variables','start'])    


#Merge with S&P500

dfe=dfstock.merge(sp500, how='left',on='jdate')

#Merge with Sigma
sigma_df=\
pd.read_hdf(path+data_dir+'sigma.h5', 
             key = "daily")

dfe=pd.merge(dfe, sigma_df, on=['permno','permco','jdate'])

# Resample #
dfe = dfe.set_index(['jdate'])

# Check default prob predictors one by one

#NIMTA (0.77)

#Do not recompute NIMTA, use the one from the raw data

w='nimta'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#TLMTA

#Do not recompute TLMTA, use the one from the raw data

w='tlmta'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#CASHMTA

#Do not recompute CASHMTA, use the one from the raw data

w='cashmta'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#MB

dfe['me_be']=dfe['me']/dfe['beq0']/1000

w='me_be'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#EXRET (ok)

dfe['exret']=np.log(1+dfe['rets'])-np.log(1+dfe['sprtrn'])

w='exret'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#SIGMA

w='sigma'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

#Size (ok)

dfe['rsize']=np.log(dfe['me']/dfe['usdval'])

w='rsize'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)


#PRICE (ok)

dfe['logprice'] = np.log(np.minimum(dfe['prc'], 15))

w='logprice'

dfe.loc[dfe[w] > np.nanpercentile(dfe[w],95),w] = np.nanpercentile(dfe[w],95)

dfe.loc[dfe[w] < np.nanpercentile(dfe[w],5),w] = np.nanpercentile(dfe[w],5)

# Winsorization increases the correlation with Kevin Aretz's predictors.


# Compute CDR default probability
CDR_coef=pd.read_excel(path+data_dir+'drcoefficients2021.xlsx')

CDR_coef.rename(columns={'YEAR':'year'}, inplace=True)

dfe['year']=dfe.index.year

dfe=dfe.reset_index()

CDR_merged=dfe.merge(CDR_coef, on='year', how='left').sort_values('year')

#forward fill the constant and beta coefficients

coefs = ['CONSTANT', 'BETA_NIMTA', 'BETA_TLMTA', 'BETA_RET','BETA_RSIZ',
       'BETA_SIGMA', 'BETA_PRICE', 'BETA_CASHMTA', 'BETA_MB']

CDR_merged[coefs] = CDR_merged[coefs].ffill()

fitted_values=CDR_merged['CONSTANT'] + \
    CDR_merged['nimta']*CDR_merged['BETA_NIMTA'] + \
    CDR_merged['tlmta']*CDR_merged['BETA_TLMTA'] + \
    CDR_merged['exret']*CDR_merged['BETA_RET']+ \
    CDR_merged['rsize']*CDR_merged['BETA_RSIZ']+ \
    CDR_merged['sigma']*CDR_merged['BETA_SIGMA']+ \
    CDR_merged['logprice']*CDR_merged['BETA_PRICE']+ \
    CDR_merged['cashmta']*CDR_merged['BETA_CASHMTA']+ \
    CDR_merged['me_be']*CDR_merged['BETA_MB']
    
    
logit_values=1 / (1 + np.exp(-fitted_values))      
    
CDR_merged['cdr']=logit_values

PROB=CDR_merged[['permno','jdate','year','me','rsize','exret','nimta','tlmta','cashmta',
                 'me_be','logprice','sigma','cdr']]

PROB.to_hdf(path+data_dir+r'PROB.h5',
          key = 'daily')


# Compare with Kevin Aretz

dfp, meta = pyreadstat\
    .read_sas7bdat\
        (path+data_dir+'/campbelldefrisk_2021.sas7bdat')
    
dfp.rename(columns={'cdr':'CDR'}, inplace=True) # Kevin's calculation upper case

dfp['jdate'] = pd.to_datetime(dfp[['year', 'month']].assign(DAY=1))
dfp['jdate'] = dfp['jdate']+MonthEnd(0)
dfp.drop(columns=['year', 'month'], inplace=True)

CDR_compare = dfp.merge(PROB,how = "inner", left_on = ['jdate','permno'],
                                      right_on= ['jdate','permno'])

#99%
CDR_compare['NIMTA'].corr(CDR_compare['nimta'])

#99%
CDR_compare['TLMTA'].corr(CDR_compare['tlmta'])

#99%
CDR_compare['CASHMTA'].corr(CDR_compare['cashmta'])

#98%
CDR_compare['MB'].corr(CDR_compare['me_be'])

#99.7%
CDR_compare['EXRET'].corr(CDR_compare['exret'])

#99.5%
CDR_compare['SIGMA'].corr(CDR_compare['sigma'])

#99.94%
CDR_compare['RSIZE'].corr(CDR_compare['rsize'])

#99%
CDR_compare['LOGPRICE'].corr(CDR_compare['logprice'])

#97.31%, almost perfectly replicate Kevin's CDR calculation.
CDR_compare['CDR'].corr(CDR_compare['cdr'])


# 2025-09-30: Add aggregate default probability.
PROB = PROB.copy()

PROB.rename(columns={'jdate': 'date'}, inplace=True)

# --- Equal-weighted ---
# Equal-weighted mean + counts
prob_ew = (
    PROB.groupby('date', as_index=False)
        .agg(
            PROB_ew=('cdr', 'mean'),   # EW default prob (NA-safe)
            n_firms=('cdr', 'count'),  # number of firms with non-NA cdr
            # n_total=('cdr', 'size')  # <-- uncomment if you want all rows incl. NA
        )
)

# --- Value-weighted by EQUITY ---
# keep only rows with finite cdr and positive weights
tmp = PROB.loc[(PROB['cdr'].notna()) & (PROB['me'] > 0), ['date', 'cdr', 'me']].copy()
tmp['wx'] = tmp['cdr'] * tmp['me']

prob_vw = (
    tmp.groupby('date', as_index=False)
       .agg(wx_sum=('wx', 'sum'), w_sum=('me', 'sum'))
)
prob_vw['PROB_vw'] = prob_vw['wx_sum'] / prob_vw['w_sum']
prob_vw = prob_vw[['date', 'PROB_vw']]

# --- Combine ---
PROB_agg = prob_ew.merge(prob_vw, on='date', how='outer').sort_values('date')

PROB_agg.to_csv(path+'Data/'+'PROB_agg.csv', index=False)

