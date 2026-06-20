#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat May 18 19:27:24 2024

@author: Lucie Lu

Generates quarterly series of aggregate shocks.

Based on Bao Hou Zhang + Liquidity + HKM Intermediary capital ratio

"""

import os
import pandas as pd
import numpy as np
import datetime as dt
import wrds
import matplotlib.pyplot as plt
from dateutil.relativedelta import *
from pandas.tseries.offsets import *
from scipy import stats
from tqdm import tqdm
tqdm.pandas()

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

data_dir='Data/AggShocks/'

start_date='1/1/1986'###############################

end_date='12/31/2024'

# Function to calculate the end date of a quarter
def end_of_quarter(year, quarter):
    year = int(year)  # Convert to integer
    quarter = int(quarter)  # Convert to integer
    
    if quarter == 1:
        end_month = 3
        end_day = 31
    elif quarter == 2:
        end_month = 6
        end_day = 30
    elif quarter == 3:
        end_month = 9
        end_day = 30
    elif quarter == 4:
        end_month = 12
        end_day = 31
    else:
        raise ValueError("Quarter must be an integer between 1 and 4.")

    return dt.date(year, end_month, end_day)


#Liquidity

file_path=path+data_dir+'liq_data_1962_2024.csv'

df_liq = pd.read_csv(
    file_path
)

df_liq.columns = ["yyyymm", "Agg", "DeltaLiq", "Liq_v"]

df_liq['date']=pd.to_datetime(df_liq['yyyymm'].astype(str)+'01', format='%Y%m%d')+ MonthEnd(1)

df_liq.set_index('date', inplace=True)

df_liq_qtr=df_liq.resample('QE').mean().drop(columns='yyyymm')  # Quarterly liquidity innovation as average of monthly liquidity innovation

# Industrial production

df_IP=pd.read_csv(path+'Data/AggShocks/'+'INDPRO.csv').rename(columns={'observation_date':'date', 'INDPRO':'IP'})

df_IP['date']=pd.to_datetime(df_IP['date'], errors='coerce')

df_IP.set_index('date', inplace=True)

df_IP_qtr = df_IP['IP'].resample('QE').last()

df_IP_qtr=df_IP_qtr.reset_index()

df_IP_qtr['IP_pct']=df_IP_qtr['IP'].pct_change(fill_method=None)


# CFNAI

df_CFNAI=pd.read_excel(path+'Data/AggShocks/'+'cfnai-realtime-3-xlsx.xlsx', usecols=['Date', 'CF122024']).rename(columns={'Date':'date','CF122024':'CFNAI'})

df_CFNAI['date']=pd.to_datetime(df_CFNAI['date'], format='%d-%b-%Y')

df_CFNAI.set_index('date', inplace=True)

df_CFNAI_qtr = df_CFNAI['CFNAI'].resample('QE').last()

df_CFNAI_qtr = df_CFNAI_qtr.reset_index()

df_CFNAI_qtr['CFNAI_diff']=df_CFNAI_qtr['CFNAI'].diff()


#EPU

df_EPU=pd.read_excel(path+'Data/AggShocks/'+'US_Policy_Uncertainty_Data.xlsx')

df_EPU = df_EPU.iloc[:-1]

df_EPU.columns=['Year', 'Month', 'EPU']

df_EPU['date'] = pd.to_datetime(df_EPU[['Year', 'Month']].assign(day=1))+ MonthEnd(1)

df_EPU.sort_values(by='date', inplace=True)

df_EPU.set_index('date',inplace=True)

df_EPU_qtr = df_EPU['EPU'].resample('QE').last()

df_EPU_qtr = df_EPU_qtr.reset_index()

df_EPU_qtr['EPU_diff']=df_EPU_qtr['EPU'].diff()

# Unemployment

df_UNRATE=pd.read_csv(path+'Data/AggShocks/'+'UNRATE.csv').rename(columns={'observation_date':'date'})

df_UNRATE['date']=pd.to_datetime(df_UNRATE['date'], errors='coerce')

df_UNRATE.set_index('date', inplace=True)

df_UNRATE_qtr = df_UNRATE['UNRATE'].resample('QE').last()

df_UNRATE_qtr=df_UNRATE_qtr.reset_index()

df_UNRATE_qtr['UNRATE']=df_UNRATE_qtr['UNRATE']/100

df_UNRATE_qtr['UNRATE_diff']=df_UNRATE_qtr['UNRATE'].diff()

# Jurado uncertainty

df_fin=pd.read_excel(path+'Data/AggShocks/MacroFinanceUncertainty_202506Update/FinancialUncertaintyToCirculate.xlsx', usecols=['Date', 'h=3'])

df_fin.rename(columns={'Date':'date','h=3':'FinU'}, inplace=True)

df_fin['date']=df_fin['date']+MonthEnd(1)

df_macro=pd.read_excel(path+'Data/AggShocks/MacroFinanceUncertainty_202506Update/MacroUncertaintyToCirculate.xlsx', usecols=['Date', 'h=3'])

df_macro.rename(columns={'Date':'date','h=3':'MacroU'}, inplace=True)

df_macro['date']=df_macro['date']+MonthEnd(1)

df_real=pd.read_excel(path+'Data/AggShocks/MacroFinanceUncertainty_202506Update/RealUncertaintyToCirculate.xlsx', usecols=['Date', 'h=3'])

df_real.rename(columns={'Date':'date','h=3':'RealU'}, inplace=True)

df_real['date']=df_real['date']+MonthEnd(1)

df_uncertainty= df_fin.merge(df_macro, on='date').merge(df_real, on='date')

df_uncertainty.set_index('date',inplace=True)

df_uncertainty_qtr = df_uncertainty.resample('QE').last()

df_uncertainty_qtr = df_uncertainty_qtr.reset_index()

df_uncertainty_qtr['MacroU_diff']=df_uncertainty_qtr['MacroU'].diff()

df_uncertainty_qtr['RealU_diff']=df_uncertainty_qtr['RealU'].diff()

df_uncertainty_qtr['FinU_diff']=df_uncertainty_qtr['FinU'].diff()

# GDP forecast

df_SPF=pd.read_excel(path+'Data/AggShocks/'+'meanGrowth.xlsx', sheet_name='NGDP', usecols=['YEAR', 'QUARTER','dngdp3'])

df_SPF['date'] = df_SPF.apply(lambda row: end_of_quarter(row['YEAR'], row['QUARTER']), axis=1)

df_SPF['date'] = pd.to_datetime(df_SPF['date'])

df_SPF['NGDP']=df_SPF['dngdp3']/100

df_SPF.drop(columns=['YEAR','QUARTER'],inplace=True)


# Fed Funds rate

df_FEDFUNDS=pd.read_csv(path+'Data/AggShocks/'+'FEDFUNDS.csv').rename(columns={'observation_date':'date'})

df_FEDFUNDS['date']=pd.to_datetime(df_FEDFUNDS['date'], errors='coerce')

df_FEDFUNDS.set_index('date', inplace=True)

df_FEDFUNDS_qtr = df_FEDFUNDS['FEDFUNDS'].resample('QE').last()

df_FEDFUNDS_qtr=df_FEDFUNDS_qtr.reset_index()

df_FEDFUNDS_qtr['FEDFUNDS']=df_FEDFUNDS_qtr['FEDFUNDS']/100

df_FEDFUNDS_qtr['FEDFUNDS_diff']=df_FEDFUNDS_qtr['FEDFUNDS'].diff()


# HKM Intermediary Capital Ratio

df_HKM=pd.read_csv(path+'Data/AggShocks/'+'HKM_Factors.csv')

df_HKM['YEAR']=df_HKM['yyyyq'] // 10

df_HKM['QUARTER']=df_HKM['yyyyq'] % 10

df_HKM['date'] = df_HKM.apply(lambda row: end_of_quarter(row['YEAR'], row['QUARTER']), axis=1)

df_HKM['date'] = pd.to_datetime(df_HKM['date'])

df_HKM=df_HKM[['date','intermediary_capital_risk_factor']]

df_HKM.rename(columns={'intermediary_capital_risk_factor':'DeltaICR'}, inplace=True)

# Merge

Agg_shocks=df_IP_qtr

Agg_shocks=pd.merge(Agg_shocks, df_liq_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_CFNAI_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_EPU_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_UNRATE_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_uncertainty_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_SPF, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_FEDFUNDS_qtr, on='date', how='left')

Agg_shocks=pd.merge(Agg_shocks, df_HKM, on='date', how='left')

Agg_shocks=Agg_shocks[Agg_shocks.date<=end_date]

Agg_shocks.to_csv(path+'Data/AggShocks/Agg_shocks.csv', index=False)






