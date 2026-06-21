#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created:       2024-12-17
Last modified: 2026-06-21
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Builds firm-level corporate credit spreads from the Dickerson, Robotti, and
Rossetti (2024) WRDS TRACE dataset (trace_29_04_2025.parquet). Bonds (keyed by
cusip) are linked to firms via the cusip->permno crosswalk in the WRDS
MMN-corrected file (WRDS_MMN_*_2024_July.csv).
Output:
  CS.h5  firm 5Y and 10Y credit spreads, interpolated by bond maturity
"""

import duckdb
import subprocess
import os
import pandas as pd
import numpy as np
import datetime as dt
from datetime import datetime, timedelta
import matplotlib.pyplot as plt
from dateutil.relativedelta import *
from pandas.tseries.offsets import *
from scipy import stats
from tqdm import tqdm
tqdm.pandas()
import pandas_datareader as pdr
from pandas.tseries.offsets import *
import pyreadstat
import matplotlib.pyplot as plt


# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

data_dir='Data/'

WRDS_BOND0=pd.read_csv(path+'Data/WRDS_MMN_Corrected_Data_2024_July.csv')

BOND_id=WRDS_BOND0[['date','cusip','permno']]

BOND_id['date'] = pd.to_datetime(BOND_id['date'], errors='coerce')

file_path = path + "Data/trace_29_04_2025.parquet"
WRDS_BOND = duckdb.query(f"SELECT * FROM '{file_path}'").to_df()
WRDS_BOND.columns = [col[:-2] if col.endswith('_1') else col for col in WRDS_BOND.columns]
WRDS_BOND.rename(columns={'cusip_id':'cusip'}, inplace=True)

columns=pd.DataFrame(WRDS_BOND.columns)

WRDS_BOND=pd.merge(WRDS_BOND, BOND_id, how='left', on=['cusip','date'])

WRDS_BOND['permno']=WRDS_BOND.groupby('cusip')['permno'].ffill() #forward fill permno from july2024 version of WRDS MMN data

WRDS_BOND['date']=pd.to_datetime(WRDS_BOND['date'])

def get_credit_spread(group, mat):
    if len(group)==1:
        # Only one bond, return its credit spread
        return group['CREDIT_SPREAD'].values[0]
    else:
        return np.interp(mat, group['bond_maturity'], group['CREDIT_SPREAD'])

# 10Y credit spread, interpolated from bonds with 8-12 years to maturity.
mat_short=8

mat_long=12

target=10

filtered_WRDS_BOND=WRDS_BOND[(WRDS_BOND['bond_maturity']>=mat_short)&(WRDS_BOND['bond_maturity']<=mat_long)]

CS10y=filtered_WRDS_BOND.groupby(['permno','date'], group_keys=False).apply(
    lambda group: get_credit_spread(group, target)
    ).reset_index()

CS10y.columns=['permno','date','CS10y']

# 5Y credit spread, interpolated from bonds with 3-7 years to maturity.
mat_short=3

mat_long=7

target=5 #target maturity in years

filtered_WRDS_BOND=WRDS_BOND[(WRDS_BOND['bond_maturity']>=mat_short)&(WRDS_BOND['bond_maturity']<=mat_long)]

CS5y=filtered_WRDS_BOND.groupby(['permno','date'], group_keys=False).apply(
    lambda group: get_credit_spread(group, target)
    ).reset_index()

CS5y.columns=['permno','date','CS5y']

CS=pd.merge(CS5y, CS10y, how='outer', on=['permno','date'])

#Save merged CS
CS.to_hdf(path+data_dir+r'CS.h5',
          key = 'daily')




