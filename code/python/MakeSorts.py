# -*- coding: utf-8 -*-
"""
Created:       2024-02-06
Last modified: 2026-06-21
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Builds the industry-level panel Data/industry_sorts.csv: for each Fama-French 48
industry and quarter, the lagged-market-cap value-weighted average of every firm
characteristic (levels and 1-quarter / 1-year changes), plus industry market-cap,
EBITDA, and assets shares. Inputs: _main_data_2.h5, _ret_quarterly_2.h5 (firm panel),
CS.h5 (credit spreads).
"""

#* ************************************** */
#* Libraries                              */
#* ************************************** */ 

import os
import pandas as pd
import numpy as np
from datetime import datetime, timedelta
from tqdm import tqdm
import pandas_datareader as pdr
from dateutil.relativedelta import *
from pandas.tseries.offsets import *
import datetime as dt
from pandas.tseries.offsets import *
tqdm.pandas()

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

start_date='6/30/1986'

end_date='12/31/2024'

os.chdir(path)

df   = pd.read_hdf(path+'Data/'+r'_main_data_2.h5')

df.rename(columns={'jdate': 'date'}, inplace=True)

dfret= pd.read_hdf(path+'Data/'+r'_ret_quarterly_2.h5').reset_index()

dfret.rename(columns={'jdate': 'date'}, inplace=True)

# Add CS
CS=pd.read_hdf(path+'Data/CS.h5')

CS.set_index(['date'], inplace=True)

CS_Qtr=CS.groupby('permno').resample('QE').last().drop(columns='permno')

# First differences of credit spreads at the 1-quarter and 1-year horizons
horizons = {
    '1q': 1,
    '1y': 4
}

Vars=['CS5y', 'CS10y']

for col in Vars:
    for label, lag in horizons.items():
        newcol = f"{col}_diff_{label}"
        CS_Qtr[newcol] = CS_Qtr.groupby('permno',group_keys=False)[col].transform(lambda x: x.diff(periods=lag))


df = df.merge(dfret, how = "inner", left_on = ['date','permno'],
              right_on = ['date','permno'])

df = df.merge(CS_Qtr, how = "left", left_on = ['date','permno'],
              right_on = ['date','permno'])  #Left join CS, which starts in 2002

df   = df[df['date'] <= end_date]
df   = df[df['date'] >= start_date]

# Lagged market cap, used as the value-weighting variable W
df['EQUITY_lag'] = df.groupby("permno")['EQUITY'].shift(1)
W = 'EQUITY_lag'

# Firm characteristics to value-weight by industry: levels plus 1q/1y changes
Vars = ['SIGMA', 'SIGMA_diff_1q','SIGMA_diff_1y',
        'cdr', 'cdr_diff_1q', 'cdr_diff_1y',
        'market_leverage', 'market_leverage_diff_1q', 'market_leverage_diff_1y',
        'book_leverage', 'book_leverage_diff_1q', 'book_leverage_diff_1y',
        'EBITDA','EBITDA_pct_1q', 'EBITDA_pct_1y',
        'NIMTA', 'NIMTA_pct_1q', 'NIMTA_pct_1y',
        'CASHMTA', 'CASHMTA_pct_1q', 'CASHMTA_pct_1y',
        'ASSETS','ASSETS_pct_1q', 'ASSETS_pct_1y',
        'sales_at', 'sales_at_pct_1q', 'sales_at_pct_1y',
        'gp_at', 'gp_at_pct_1q', 'gp_at_pct_1y',
        'EARN1Q_pct_1q', 'EARN1Q_pct_1y',
        'ret_exc_1q','ret_exc_1y',
        'CS5y', 'CS5y_diff_1q', 'CS5y_diff_1y',
        'CS10y', 'CS10y_diff_1q', 'CS10y_diff_1y'
        ]

# Value-weighted characteristics within each industry. Weights are recomputed per
# variable so each weight set respects that variable's data availability.
for d in Vars:
    print(d)
    dfST = df[~df[d].isnull()]
    dfST = dfST[~dfST[W].isnull()]
    dfST['value-weights'] = dfST.groupby([ 'date','ffi48'],group_keys=False)[W]\
        .progress_apply( lambda x: x/np.nansum(x) )
    sorts = dfST.groupby(['date','ffi48'],group_keys=False)[[d,'value-weights']]\
        .progress_apply( lambda x: np.nansum( x[d] * x['value-weights']) ).\
            to_frame()
    sorts.columns = [d]
    if d == Vars[0]:
        Output=sorts
    else:
        Output = Output.merge(sorts, how = "left", left_index = True,
                              right_index = True)
        

#Add and merge industry market-cap share and industry EBITDA share
ffi48_mktcap=df.groupby(['date','ffi48'])['EQUITY'].sum().reset_index(name='ffi48_mktcap')

total_mktcap=df.groupby('date')['EQUITY'].sum().reset_index(name='total_mktcap')

ffi48_share=pd.merge(ffi48_mktcap,total_mktcap,on='date')

ffi48_ebitda=df.groupby(['date','ffi48'])['EBITDA'].sum().reset_index(name='ffi48_ebitda')

total_ebitda=df.groupby('date')['EBITDA'].sum().reset_index(name='total_ebitda')

ffi48_assets=df.groupby(['date','ffi48'])['ASSETS'].sum().reset_index(name='ffi48_assets')

total_assets=df.groupby('date')['ASSETS'].sum().reset_index(name='total_assets')

ffi48_share=pd.merge(ffi48_share,ffi48_ebitda,on=['date', 'ffi48'])

ffi48_share=pd.merge(ffi48_share,total_ebitda,on=['date'])

ffi48_share=pd.merge(ffi48_share,ffi48_assets,on=['date', 'ffi48'])

ffi48_share=pd.merge(ffi48_share,total_assets,on=['date'])

ffi48_share['mktcap_share']=ffi48_share['ffi48_mktcap']/ffi48_share['total_mktcap']
        
ffi48_share['ebitda_share']=ffi48_share['ffi48_ebitda']/ffi48_share['total_ebitda']

ffi48_share['assets_share']=ffi48_share['ffi48_assets']/ffi48_share['total_assets']

ffi48_share.set_index(['date','ffi48'], inplace=True)

Output=Output.merge(ffi48_share, how='left', left_index=True, right_index=True)  # industry shares of market cap, EBITDA, assets

# Clean infinities, then keep the sample from 1987Q2 (when most variables become available)
Output = Output.replace([np.inf, -np.inf], np.nan)

Output = Output.reset_index()

Output=Output[Output['date']>=dt.datetime(1987, 6, 30)]

Output.to_csv(path+'Data/'+'industry_sorts.csv', index=False)






