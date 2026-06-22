#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created:       2024-12-27
Last modified: 2026-06-22
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Computes firm-level equity return volatility (sigma): the annualized standard
deviation of daily CRSP returns over a trailing 3-month window, anchored to each
month-end, with a degrees-of-freedom adjustment. Missing values are filled with the
cross-sectional monthly mean. The rolling-volatility routine was reworked by
Alex Dickerson.
Inputs:  WRDS (crsp.dsf_v2 daily returns)
Outputs: sigma.h5
"""

#* ************************************** */
#* Libraries                              */
#* ************************************** */

import os
import pandas as pd
import numpy as np
import wrds
from pandas.tseries.offsets import *

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

data_dir='Data/'

start_date='1/1/1986'

end_date='12/31/2024'

os.chdir(path)


conn=wrds.Connection()   # uses your own configured WRDS credentials

crsp_d = conn.raw_sql(f"""
                      select permno, permco, dlycaldt, dlyret, dlyretx 
                      from crsp.dsf_v2 
                      where dlycaldt between '{start_date}' and '{end_date}'
                      """, date_cols=['dlycaldt']) 
                      

# change variable format to int
crsp_d[['permco','permno']]=crsp_d[['permco','permno']].astype(int)

# Step 1: Create month-end date column
# Line up date to be end of month

crsp_d['jdate']=crsp_d['dlycaldt']+MonthEnd(0)

# Step 2: Calculate squared returns
crsp_d['squared_ret'] = crsp_d['dlyret'] ** 2


# Step 3: Calculate rolling volatility anchored to month-end dates
def calc_volatility_rolling(group):
    # Ensure daily returns are ordered by date
    group = group.sort_values(by='dlycaldt')
    #Only keep month-end dates
    month_ends = (
        group['jdate'].unique()
    )

    #first return date, month start after the first return date
    first_return_date = group[group.dlyret.notnull()]['dlycaldt'].min()+ MonthEnd(1)+Day(1)

    earliest_valid_jdate = (first_return_date + pd.DateOffset(months=2)) + MonthEnd(0)

    # Create empty column for month-end volatility
    sigma_values = []

    # Iterate over unique month-end dates
    for date in month_ends:

        if date < earliest_valid_jdate:
            # skip: not enough history yet, necessary because I need to fill in nan with mean later.
            continue
        # Define 3-month rolling window for current month-end
        start_date = date - pd.DateOffset(months=3)+ MonthBegin(0)
        end_date = date
        
        # Filter returns within the 3-month window
        window = group[(group['dlycaldt'] >= start_date) & 
                       (group['dlycaldt'] <= end_date)]
        
        # Sum of squared returns in the window
        n = len(window)
        non_zero_n = (window['squared_ret'] > 0).sum()
        
        # Apply degree of freedom adjustment (N-1)
        if non_zero_n >= 5 and n > 1:
            sigma = np.sqrt(252 * window['squared_ret'].sum() / (n - 1))
        else:
            sigma = np.nan
        
        sigma_values.append((date, sigma))
    
    # Return DataFrame for the current group
    return pd.DataFrame(sigma_values, columns=['jdate', 'sigma'])


# Step 4: Apply by permno and permco
pieces = []
for (permno, permco), grp in crsp_d.groupby(['permno','permco']):
    df_vol = calc_volatility_rolling(grp)
    if not df_vol.empty:
        # re-attach the group keys
        df_vol['permno'] = permno
        df_vol['permco'] = permco
        pieces.append(df_vol)

sigma_df = pd.concat(pieces, ignore_index=True)


# Step 5: replace NaN values with mean in each month.
sigma_df['sigma'] = sigma_df['sigma'].fillna(
    sigma_df.groupby('jdate')['sigma'].transform('mean')
)



sigma_df.to_hdf(path+data_dir+'/sigma.h5',
                key='daily')

