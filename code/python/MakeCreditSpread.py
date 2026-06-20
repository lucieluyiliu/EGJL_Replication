#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Tue Dec 17 08:53:28 2024

@author: yiliul2
"""

# This python code creates industry-level credit spreads based on the Dickerson, Robotti, and Rossetti (2024) WRDS(TRACE) dataset


##########################################
# Two Trees Data Preparation             #
# Date:    November 2024                 #
# Updated: November   2024               #
# Credit spread                          #
##########################################


#
import duckdb
import subprocess
import os
import pandas as pd
import numpy as np
import datetime as dt
from datetime import datetime, timedelta
import wrds
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

tqdm.pandas()
conn=wrds.Connection()   # uses your own configured WRDS credentials


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

#Check number of companies  in each industry
dfi = pd.read_hdf(path+data_dir+'/FF48_Stocks.h5', 
                     key = "daily")

dfi.columns = ['date','permno', 'sic', 'ffi48', 'ffi48_desc']

dfi['date'] = dfi['date'] + MonthEnd(0)


WRDS_BOND['date']=pd.to_datetime(WRDS_BOND['date'])

WRDS_BOND_ind=WRDS_BOND.merge(dfi, how = "left", left_on = ['date','permno'],
                                      right_on= ['date','permno'])

WRDS_BOND_ind.sort_values(by=['permno', 'date'], inplace=True)

# forward fill last know industry classification

WRDS_BOND_ind['sic']=WRDS_BOND_ind.groupby('permno')['sic'].ffill()

WRDS_BOND_ind['ffi48']=WRDS_BOND_ind.groupby('permno')['ffi48'].ffill()

# #Summary of TRACE data
#Check how many firms in each industry each month
#count_firm_ind=WRDS_BOND_ind.groupby(['date','ffi48'])['permno'].nunique().reset_index(name='nunique_firms').pivot(index='date',columns='ffi48', values='nunique_firms')

# # Check distribution of bonds across industries.
# count_bonds_ind=WRDS_BOND_ind.groupby(['date','ffi48'])['cusip'].nunique().reset_index(name='nunique_bonds').pivot(index='date',columns='ffi48', values='nunique_bonds')
#
# # Average maturity by industry
# avg_mat_ind = WRDS_BOND_ind.groupby(['ffi48', 'ffi48_desc'])['tmt'].agg(
#     min_value='min',
#     p25=lambda x: x.quantile(0.25),
#     median='median',
#     p75=lambda x: x.quantile(0.75),
#     max_value='max',
#     mean='mean',
#     count='count'
# ).reset_index()
#
# avg_mat_ind.to_csv(data_dir+'Maturity_by_ind.csv', index=False)
#
# #Average maturity at the firm and industry level, firm level is the amount-outstanding weighted across bonds,
# #Industry level is the market-cap weighted average across firms.
firm_mat = (
    WRDS_BOND.groupby(['permno', 'date'], group_keys=False)
    .apply(lambda group: (group['bond_maturity'] * group['bond_amount_out']).sum() / group['bond_amount_out'].sum())
    .reset_index(name='avgmat')
)

#Save firm average debt maturity
firm_mat.to_hdf(path+data_dir+r'firm_mat.h5',
          key = 'daily')

# Interpolated CS

# 10Y maturity

mat_short=8

mat_long=12

target=10

filtered_WRDS_BOND=WRDS_BOND[(WRDS_BOND['bond_maturity']>=mat_short)&(WRDS_BOND['bond_maturity']<=mat_long)]

#Function to interpolate credit spread

def get_credit_spread(group, mat):
    if len(group)==1:
        # Only one bond, return its credit spread
        return group['CREDIT_SPREAD'].values[0]
    else:
        return np.interp(mat, group['bond_maturity'], group['CREDIT_SPREAD'])


CS10y=filtered_WRDS_BOND.groupby(['permno','date'], group_keys=False).apply(
    lambda group: get_credit_spread(group, target)
    ).reset_index()

CS10y.columns=['permno','date','CS10y']


# 5Y maturity

mat_short=3

mat_long=7

target=5 #target maturity in years

filtered_WRDS_BOND=WRDS_BOND[(WRDS_BOND['bond_maturity']>=mat_short)&(WRDS_BOND['bond_maturity']<=mat_long)]

#Function to interpolate credit spread

CS5y=filtered_WRDS_BOND.groupby(['permno','date'], group_keys=False).apply(
    lambda group: get_credit_spread(group, target)
    ).reset_index()

CS5y.columns=['permno','date','CS5y']

CS=pd.merge(CS5y, CS10y, how='outer', on=['permno','date'])

#Save merged CS
CS.to_hdf(path+data_dir+r'CS.h5',
          key = 'daily')




