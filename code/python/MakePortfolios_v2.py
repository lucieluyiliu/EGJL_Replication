# -*- coding: utf-8 -*-
"""

Created on Tue Mar  5 11:45:15 2024

@author: Lucie Lu

Updated 2025-07-13: add return over different horizons

"""

#* ************************************** */
#* Libraries                              */
#* ************************************** */ 

import pandas as pd
import numpy as np

import os

from datetime import datetime, timedelta
from tqdm import tqdm
import pandas_datareader as pdr
from dateutil.relativedelta import *
from pandas.tseries.offsets import *
import datetime as dt
from pandas.tseries.offsets import *
import pyreadstat
import wrds
tqdm.pandas()

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

data_dir='Data/'

os.chdir(path)

# Read stock characteristic anomalies
dfstock=\
pd.read_hdf(path+data_dir+'raw_data.hdf', 
             key = "daily").reset_index()  

dfstock.columns

# use annual ebitda when quarterly ebitda is not available
dfstock['ebitda'] = np.where(dfstock['ebitda_sum'].isnull(),dfstock['ebitdaA'],
                             dfstock['ebitda_sum'])

#pick useful variables
dfstock = dfstock[['permno','jdate',
                   'atq' ,# total assets
                   'ebitda',
                   'sales_at',
                   'gp_at',
                   'ebitda_sale',
                   'cashmta',
                   'nimta',
                   'me',
                   'rets',  # total return
                   'ret_exc',  # excess return one month T-bil
                   't90ret',  # 90-day T-bill
                   'dd1','dd2' ,'dd3','dd4','dd5',
                   'book_leverage_ltq',                                    
                   'market_leverage',
                   'debt3Y',
                   'debt5Y',
                   'debtST',
                   'earn1q_at',
                   'earn1y_at',
                   'earn2y_at',
                   'earnlt_at'
                   ]]

dfstock.columns

#Check variable first start date at the stock level

dfstock_start_dic={}

for column in dfstock.columns:
    first_non_null_date=dfstock.dropna(subset=[column]).jdate.min()
    dfstock_start_dic[column]=first_non_null_date

dfstock_start=pd.DataFrame(list(dfstock_start_dic.items()), columns=['variables','start'])    

dfp=pd.read_hdf(path+'Data/PROB.h5')

#rename winsorized variables for PROB calculation
dfp.rename(columns={"nimta":"NIMTA","cashmta":"CASHMTA","sigma":"SIGMA","tlmta":"TLMTA"}, inplace=True)


# =============================================================================
# dfp, meta = pyreadstat\
#     .read_sas7bdat\
#         (path+data_dir+'/campbelldefrisk_2021.sas7bdat')
# 
# dfp['date'] = pd.to_datetime(dfp[['year', 'month']].assign(DAY=1))
# dfp['date'] = dfp['date']+MonthEnd(0)
# =============================================================================

dfe = dfp.merge(dfstock,how = "left", left_on = ['jdate','permno'],
                                      right_on= ['jdate','permno'])

dfe.sort_values(by=['permno','jdate'], inplace=True)
# Resample #
dfe = dfe.set_index(['jdate'])

# Quarterly Data #
# Quarterly total return, quarterly excess return using 3-month and one-month T-bill rate
dfe['retq'] = 1+dfe['rets']

dfe['rf90'] = dfe.groupby("permno")['t90ret'].transform(lambda x: x.shift(3).ffill())

#test=dfe[['permno','t90ret','shifted_t90ret']].reset_index().sort_values(['permno','jdate'])

dfret = dfe.groupby("permno")['retq'].progress_apply(lambda x: x.resample("QE").prod())-1

dfret=dfret.to_frame()

dfret['rf90']= dfe.groupby(["permno", pd.Grouper(freq='QE')])['rf90'].last()

dfret['ret_exc_1q'] = dfret['retq'] - dfret['rf90']

#Compound returns to over longer horizons

horizons = {
    '1y': 4,
    '2y': 8,
    '5y': 20
}

# 3) Equity return over horizons to date
Rets= ['retq', 'rf90']

for col in Rets:
    for label, lag in horizons.items():
        newcol = f"{col}_{label}"
        dfret[newcol] = (
            dfret
            .groupby('permno', group_keys=False)[col]
            .transform(lambda x: np.exp(np.log1p(x).rolling(window=lag, min_periods=lag).sum()) - 1)
        )

#Excess returns over horizons to date
for label in horizons:
    dfret[f'ret_exc_{label}'] = dfret[f'retq_{label}'] - dfret[f'rf90_{label}']


#test1=dfret[['retq','shifted_t90ret']].reset_index().sort_values(['permno','jdate'])


#dfe_reset=dfe[['rets','t90ret','ret_exc']].reset_index().sort_values(by=['permno','date'])

#dfret=dfret.reset_index().sort_values(by=['permno', 'date'])

#merged_df=pd.merge(dfe_reset,dfret, on=['date','permno'], how='left')

#merged_df=merged_df.sort_values(by=['permno','date'])

# Quarterly returns #
#dfe['retq'] = 1+dfe['rets']
#dfret = dfe.groupby("permno")['retq'].progress_apply(lambda x: x.resample("QE").prod())

#dfret = dfret-1
#dfret = dfret.to_frame()

dfret.to_hdf(path+data_dir+r'_ret_quarterly_2.h5',
          key = 'daily')

#resample monthly data to quarterly here.
dfq = dfe.groupby("permno").progress_apply(lambda x: x.resample("QE").last())

dfq.columns

dfq.drop(['permno'], axis = 1, inplace = True)

# Copy here for "resets" #

df = dfq.copy()

df = df[['year', 
         'NIMTA','CASHMTA','SIGMA', 'cdr', 'atq', 'ebitda',
         'sales_at', 'gp_at' , 'ebitda_sale', 'me','dd1', 'dd2','dd3','dd4','dd5',
         'book_leverage_ltq',                                    
         'market_leverage','debt3Y','debt5Y','debtST','earn1q_at','earn1y_at','earn2y_at','earnlt_at']]

df.columns = [
         'year', 
         'NIMTA','CASHMTA','SIGMA', 'cdr', 'ASSETS', 'EBITDA',
         'sales_at','gp_at', 'ebitda_sale', 'EQUITY', 'dd1','dd2' ,'dd3','dd4','dd5',
         'book_leverage',                                    
         'market_leverage',
         'debt3Y','debt5Y','debtST','EARN1Q','EARN1Y','EARN2Y','EARNLT'
         ]

df_summary=df.isnull().sum()


# Vars to calculate percentage changes and differences

df=df.reset_index()

df = df.sort_values(['permno','jdate'])

# define how many periods correspond to each horizon
# 1-quarter = shift(1), 1-year = shift(4), 2-year = shift(8), 5-year=shift(20)
# Note that data frequency is quarterly, but we consider alternative horizons for changes in and industry-level variables.
horizons = {
    '1q': 1,
    '1y': 4,
    '2y': 8,
    '5y': 20
}

# 1) Percentage growth for Vars
Vars = ['EBITDA', 'NIMTA','CASHMTA','ASSETS','sales_at','gp_at', 'ebitda_sale','EARN1Q','EARN1Y','EARN2Y','EARNLT']
# percentage growth for columns in Vars
for col in Vars:
    for label, lag in horizons.items():
        newcol = f"{col}_pct_{label}"
        # pct_change does (x_t / x_{t-lag} - 1)
        df[newcol] = df.groupby('permno',group_keys=False)[col].transform(lambda x: x.pct_change( periods=lag,fill_method=None))

# 2) First differences for Diffs
Diffs = ['SIGMA'  , 'cdr','market_leverage','book_leverage'] # Add market leverage

for col in Diffs:
    for label, lag in horizons.items():
        newcol = f"{col}_diff_{label}"
        df[newcol] = df.groupby('permno',group_keys=False)[col].transform(lambda x: x.diff(periods=lag))


#df_describe0=df.describe()

# Cleaning #
df = df.replace([np.inf, -np.inf], np.nan)


#Check extreme values before winsorization

df_summary=df.describe()

    
from scipy.stats.mstats import winsorize

WinzVars = ['EBITDA_pct_1q','EBITDA_pct_1y', 'EBITDA_pct_2y', 'EBITDA_pct_5y',
            'NIMTA_pct_1q', 'NIMTA_pct_1y', 'NIMTA_pct_2y', 'NIMTA_pct_5y',
            'CASHMTA_pct_1q', 'CASHMTA_pct_1y', 'CASHMTA_pct_2y', 'CASHMTA_pct_5y',
            'ASSETS_pct_1q', 'ASSETS_pct_1y', 'ASSETS_pct_2y', 'ASSETS_pct_5y',
            'sales_at_pct_1q','sales_at_pct_1y', 'sales_at_pct_2y', 'sales_at_pct_5y',
            'gp_at_pct_1q', 'gp_at_pct_1y','gp_at_pct_2y', 'gp_at_pct_5y',
            'ebitda_sale_pct_1q', 'ebitda_sale_pct_1y', 'ebitda_sale_pct_2y', 'ebitda_sale_pct_5y',
            'EARN1Q_pct_1q', 'EARN1Q_pct_1y', 'EARN1Q_pct_2y', 'EARN1Q_pct_5y',
            'EARN1Y_pct_1q', 'EARN1Y_pct_1y', 'EARN1Y_pct_2y', 'EARN1Y_pct_5y',
            'EARN2Y_pct_1q', 'EARN2Y_pct_1y', 'EARN2Y_pct_2y', 'EARN2Y_pct_5y',
            'EARNLT_pct_1q', 'EARNLT_pct_1y', 'EARNLT_pct_2y', 'EARNLT_pct_5y',
            'SIGMA_diff_1q', 'SIGMA_diff_1y', 'SIGMA_diff_2y', 'SIGMA_diff_5y',
            'cdr_diff_1q', 'cdr_diff_1y', 'cdr_diff_2y', 'cdr_diff_5y',
            'market_leverage_diff_1q', 'market_leverage_diff_1y', 'market_leverage_diff_2y', 'market_leverage_diff_5y',
            'book_leverage_diff_1q', 'book_leverage_diff_1y', 'book_leverage_diff_2y', 'book_leverage_diff_5y',
            # levels, PROB predictors NIMTA and CASHMTA are pre-winsorized #
'sales_at','gp_at','ebitda_sale',
'book_leverage', 'market_leverage',
'dd1','dd2','dd3','dd4','dd5',
'debt3Y','debt5Y','debtST'
]

# Updated 2025-06-28: 5% and 95% winsorization instead of 1% and 99%, to be consistent with default probability calculation winsorization

for w in WinzVars:
    print(w)
    df.loc[df[w] > np.nanpercentile(df[w],95),w] = np.nanpercentile(df[w],95)
    df.loc[df[w] < np.nanpercentile(df[w],5),w] = np.nanpercentile(df[w],5)
    
#df_describe1=df.describe()   

# =============================================================================
# df[['book_leverage', 'market_leverage']].describe().round(3)
# df[['book_leverage', 'market_leverage']].corr()
# =============================================================================

dfi = pd.read_hdf(path+data_dir+'/FF48_Stocks.h5', 
                     key = "daily")

dfi.columns = ['date','permno', 'sic', 'ffi48', 'ffi48_desc']

dfi['jdate'] = dfi['date'] + MonthEnd(0)

dfi.drop(columns='date', inplace=True)

df = df.merge(dfi, how = "left", left_on = ['jdate','permno'],
                                      right_on= ['jdate','permno'])

#forward fill sic codes and ff48 classification as Alex D's table is up to end of 2022

df.sort_values(by=['permno', 'jdate'], inplace=True)

df['sic']=df.groupby('permno')['sic'].ffill()

df['ffi48']=df.groupby('permno')['ffi48'].ffill()

df = df[~df['sic'].isnull()]
df = df[~df['ffi48'].isnull()]
df.isnull().sum()

df.drop(['year'], axis = 1, inplace = True)
df.to_hdf(path+data_dir+r'_main_data_2.h5',
          key = 'daily')

####################################################