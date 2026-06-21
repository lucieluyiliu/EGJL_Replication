# -*- coding: utf-8 -*-
"""
Created on Tue Feb  6 15:58:08 2024

@author: Lucie Lu
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

start_date='6/30/1986'###############################

end_date='12/31/2024'

os.chdir(path)

df   = pd.read_hdf(path+'Data/'+r'_main_data_2.h5')

df.rename(columns={'jdate': 'date'}, inplace=True)


#check availability of forecasted earnings

#df['forearn'].isnull().sum() #There are a lot of missing values, but not too many.
#13601 out of 19758 in IBES, given restriction on horizon, quite reasonable.
df.loc[df['EARN1Q'].notnull()]['permno'].nunique()
#14051
df.loc[df['EARN1Y'].notnull()]['permno'].nunique()
#12345
df.loc[df['EARN2Y'].notnull()]['permno'].nunique()
#11975
df.loc[df['EARNLT'].notnull()]['permno'].nunique()



#check how many stocks per industry per year

df['year']=df['date'].dt.year

nfirms_ffi48 = df.groupby(['ffi48', 'year'])['permno'].nunique().reset_index(name='nfirms')

dfret= pd.read_hdf(path+'Data/'+r'_ret_quarterly_2.h5').reset_index()

dfret.rename(columns={'jdate': 'date'}, inplace=True)

# Add CS
CS=pd.read_hdf(path+'Data/CS.h5')

CS.set_index(['date'], inplace=True)

CS_Qtr=CS.groupby('permno').resample('QE').last().drop(columns='permno')

# Take differnce in CS at various horizons

horizons = {
    '1q': 1,
    '1y': 4
}

Vars=['CS5y', 'CS10y']

for col in Vars:
    for label, lag in horizons.items():
        newcol = f"{col}_diff_{label}"
        CS_Qtr[newcol] = CS_Qtr.groupby('permno',group_keys=False)[col].transform(lambda x: x.diff(periods=lag))


#Add average maturity from TRACE
firm_mat=pd.read_hdf(path+'Data/firm_mat.h5')

firm_mat.set_index(['date'], inplace=True)

firm_mat_Qtr=firm_mat.groupby('permno').resample('QE').last().drop(columns='permno')

df = df.merge(dfret, how = "inner", left_on = ['date','permno'],
              right_on = ['date','permno'])

df = df.merge(CS_Qtr, how = "left", left_on = ['date','permno'],
              right_on = ['date','permno'])  #Left join CS, which starts in 2002

df = df.merge(firm_mat_Qtr, how = "left", left_on = ['date','permno'],
              right_on = ['date','permno'])  #Left join firm-level average maturity, which starts in 2002

df   = df[df['date'] <= end_date]
df   = df[df['date'] >= start_date]

##### Form EQUITY_lag (lagged market cap) weighted portfolios of
df['EQUITY_lag'] = df.groupby("permno")['EQUITY'].shift(1)
W = 'EQUITY_lag' # use lagged market cap to weight growth

# Output is going to be a stacked panel
# Output = pd.DataFrame()

#Add fundamental variables, both difference and level
#I think for earnings forecast, only the quarterly change is relevant.
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
        'ebitda_sale','ebitda_sale_pct_1q', 'ebitda_sale_pct_1y',
        'EARN1Q_pct_1q', 'EARN1Q_pct_1y',
        'EARN1Y_pct_1q', 'EARN1Y_pct_1y',
        'EARN2Y_pct_1q', 'EARN2Y_pct_1y',
        'EARNLT_pct_1q', 'EARNLT_pct_1y',
        'retq', 'ret_exc_1q','ret_exc_1y',
        'debt3Y', 'debt5Y', 'debtST',
        'CS5y', 'CS5y_diff_1q', 'CS5y_diff_1y',
        'CS10y', 'CS10y_diff_1q', 'CS10y_diff_1y',
        'avgmat'
        ]

#Value-weighted characteristics within each industry
#Weights need to be recalculated taking into account data availability.

dfindustry_start_dic = {}

for column in df.columns:
    first_non_null_date = df.reset_index().dropna(subset=[column]).date.min()
    dfindustry_start_dic[column] = first_non_null_date

dfindustry_start0 = pd.DataFrame(list(dfindustry_start_dic.items()), columns=['variables', 'start'])
# I will start sample in 1987Q2 because this seems to be the starting date when most variables are available


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
        #Output = pd.concat([Output, sorts], axis = 1)
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

Output=Output.merge(ffi48_share, how='left', left_index=True, right_index=True)  #Add industry relative share in MV and EBITDA and ASSETS

# =============================================================================
# zz = 'dd5'
# zz='debt3Y'
# 
# zz='gp_at_pct'
# 
# dfx = Output.pivot_table(index = ['date'],
#                          columns = 'ffi48',
#                          values = zz)
# 
# dfx.plot()
# 
# Output.isnull().sum()
# =============================================================================

# Cleaning #
Output = Output.replace([np.inf, -np.inf], np.nan)

dfindustry_start_dic={}

for column in Output.columns:
    first_non_null_date=Output.reset_index().dropna(subset=[column]).date.min()
    dfindustry_start_dic[column]=first_non_null_date
    

dfindustry_start=pd.DataFrame(list(dfindustry_start_dic.items()), columns=['variables','start'])      
# I will start sample in 1987Q2 because this seems to be the starting date when most variables are available


#Check variable first start date at the industry level

#Output.to_hdf(r'~\Dropbox\Alex_and_Lucie\_industry_sorts_2.h5',key='daily')

#Sample starts in 1987Q2
Output = Output.reset_index()

Output=Output[Output['date']>=dt.datetime(1987, 6, 30)]

Output.to_hdf(path+'Data/'+r'_industry_sorts_2.h5',key='daily')

Output.to_csv(path+'Data/'+'industry_sorts.csv', index=False)






