# -*- coding: utf-8 -*-
"""
Created on Tue Mar  5 10:31:10 2024

@author: Lucie Lu based on Alex Dickerson's code

"""

##########################################
# CRSP-COMPUSTAT Merge                   #
# Re-worked by Alex Dickerson using code #
# from:                                  #
# Qingyi (Freda) Song Drechsler          #
# Date:    January 2023                  #
# Updated: April   2023                  #
###########
import os
import pandas as pd
import numpy as np
import datetime as dt
import wrds
import matplotlib.pyplot as plt
from dateutil.relativedelta import *
from pandas.tseries.offsets import *
import pickle as pkl
from scipy import stats
from tqdm import tqdm
tqdm.pandas()

import matplotlib.pyplot as plt

conn=wrds.Connection()   # uses your own configured WRDS credentials

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path

# path0=r'/Users/yiliul2/Dropbox/TwoTrees_EGJL/Data_empirics/Empirics/Data_MS_R1/'
#
# dfstock=\
# pd.read_hdf(path0+'raw_data.hdf',
#              key = "daily").reset_index()

os.chdir(path)

start_date='1/1/1986'###############################

end_date='12/31/2024'

AcctLag=2  #JKP 4, Kevin 2

###################
# Compustat Block #
#  Quarterly      #
###################
#naics is not available
#Updated 2024-03-29 to extend to 1986

compQ = conn.raw_sql(
    f"""
    select gvkey, datadate, rdq, fqtr, fyearq, datafqtr,
           atq, ltq, dlttq, dlcq, seqq, ceqq, pstkq, txditcq,
           pstknq, pstkrq, ibq, revtq, cogsq, cogsy, ppentq,
           actq, lctq, oiadpq, chq, cheq, invtq, mibtq, niq,
           saleq, dpq, xsgaq
    from comp.fundq
    where indfmt='INDL'
      and datafmt='STD'
      and popsrc='D'
      and consol='C'
      and datadate >= '{start_date}'
      and datadate <= '{end_date}'
    """,
    date_cols=['datadate']
)


compQ.to_hdf(path+r'Data/comp_quarter.hdf',
             key = "daily")

compQ =\
  pd.read_hdf(path+r'Data/comp_quarter.hdf', key = "daily")

#######################
# Quarterly COMPUSTAT #
#######################

compQ['year']=compQ['datadate'].dt.year

# Create preferrerd stock

# Set ps (preferred stock) to book value of preferred stock #
compQ['ps'] = compQ['pstkq']

# 1 Where ps is null, set to sum of non-redeemable and redeemable #
compQ['ps'] =np.where( compQ['ps'].isnull(),
                     ( compQ['pstknq'] + compQ['pstkrq']),
                       compQ['ps'])

# 2 Where ps is null, set to redeemable # 
compQ['ps'] =np.where(  compQ['ps'].isnull(), 
                        compQ['pstkrq'], 
                        compQ['ps']  )

# 3 Where ps is null, set to non-redeemable # 
compQ['ps'] =np.where(  compQ['ps'].isnull(), 
                        compQ['pstknq'], 
                        compQ['ps']  )

# 4 If NaN set to 0 value
compQ['ps']=compQ['ps'].fillna(0)

# 5 Set  Deferred Taxes and Investment Tax Credit (TXDITCQ) to 0 if NaN
compQ['txditc']=compQ['txditcq'].fillna(0)

# 6 Set share holders equity to seq
compQ['sh'] = compQ['seqq']

# 7 If NaN set to (CEQ + PSTX)
compQ['sh'] = np.where( compQ['sh'].isnull(),                      
                       (compQ['ceqq'] + compQ['ps']),
                        compQ['sh'] )

# 8 If still NaN set to (AT - LT)
compQ['sh'] = np.where( compQ['sh'].isnull(),
                       (compQ['atq'] - compQ['ltq']), 
                        compQ['sh'] )
                          

# 9 Create book equity
compQ['beq0'] = compQ['sh'] + compQ['txditc'] - compQ['ps']
compQ['beq'] = np.where(compQ['beq0']>0,
                      compQ['beq0'],
                      np.nan)

# Resampling each gvkey based on fiscal year-ends #  
# Round the datadate upward, i.e., if date is 29-04-2023,
# it becomes  30-04-2023 
compQ['datadate']     = compQ['datadate'] + MonthEnd(0)

compQ['fiscal_month'] = compQ['datadate'].dt.month

# Masks for resampling for contiguous quarterly data that accounts for
# fiscal year-end changes and different quarterly reporting periods
# Really for filling in missing quarters

compQ['mask_march'] = ((compQ.fiscal_month == 3) | (compQ.fiscal_month == 6) |\
       (compQ.fiscal_month == 9) | (compQ.fiscal_month == 12) ) * 1  
    
compQ['mask_feb']   = ((compQ.fiscal_month == 2) | (compQ.fiscal_month == 5) |\
       (compQ.fiscal_month == 8) | (compQ.fiscal_month == 11) ) * 1      

compQ['mask_apr']   = ((compQ.fiscal_month == 4) | (compQ.fiscal_month == 7) |\
       (compQ.fiscal_month == 10) | (compQ.fiscal_month == 1) ) * 1   
    
compQ['fiscal_q'] = np.where(compQ['mask_march'] == 1,
                             "March",
                             np.nan)

compQ['fiscal_q'] = np.where(compQ['mask_feb'] == 1,
                             "Feb",
                             compQ['fiscal_q'])

compQ['fiscal_q'] = np.where(compQ['mask_apr'] == 1,
                             "Apr",
                             compQ['fiscal_q'])

quarter_ends =   compQ['fiscal_q'].unique()

#Initialize empty DataFrame to store resampled data
comp_resamp  = pd.DataFrame()

#### Resampling to create continuous quarterly observation that is aligned with the firm's fiscal quarter ####

for y in quarter_ends:
    print(y)  
    if   y == "March":
        R = "QE-MAR"
    elif y == "Feb":
        R = "QE-FEB"
    elif y == "Apr":
        R = "QE-APR"   
           
    # No Fiscal changes
    df = compQ[((compQ['fiscal_q']    == y))]
    df = df.set_index(['datadate'])
    
    KEYs = list(df['gvkey'].unique())
    c       = 5000
    chunks  = [KEYs[x:x+c] for x in range(0, len(KEYs), c)]
    df_resamp = pd.DataFrame()
    for l in range(0,len(chunks)):
        print(l)
        KEY_Chunk = pd.DataFrame(chunks[l], columns = ['gvkey'])
        dfChunk = df[(df['gvkey'].isin(KEY_Chunk['gvkey']))]
        dfR = dfChunk.groupby(["gvkey"])[ dfChunk.columns[1:] ].\
            apply(lambda x: x.resample(R).last())  # Resample quarterly data at fiscal quarter end dates.
        df_resamp = pd.concat([df_resamp, dfR], axis = 0)
   
    # Concat to comp_resamp #
    comp_resamp = pd.concat([comp_resamp, df_resamp], axis = 0)
        
compQ = comp_resamp.sort_index(level = ['gvkey',
                                     'datadate'])   

# Calculate NOA #
# See Correia et al. 2018, "Asset Volatility" -- Page 52/59
compQ['mibtq']       = compQ['mibtq'].fillna(0)
compQ['noa']         = compQ['ceqq']+compQ['ps']+compQ['dlttq']+compQ['dlcq']\
                   +compQ['mibtq'] - compQ['cheq']

# WRDS Annual File definition of these variables #
compQ['xsgaq']    = compQ['xsgaq'].fillna(0)
compQ['ebitda']   = compQ['saleq'] - compQ['cogsq'] - compQ['xsgaq']
compQ['gp']   = compQ['saleq'] - compQ['cogsq']

# Drop any gvkey--datadate duplicates
compQ = compQ[~compQ.index.duplicated()]
compQ = compQ.reset_index()

# Sum the last 4 quarters of income statement data, where available #
compQ['revtq_sum']    = compQ.groupby("gvkey",group_keys=False)['revtq'].progress_apply(\
                         lambda x: x.rolling(window = 4,min_periods=4).sum())
compQ['cogsq_sum']    = compQ.groupby("gvkey",group_keys=False)['cogsq'].progress_apply(\
                          lambda x: x.rolling(window = 4,min_periods=4).sum())
compQ['niq_sum']      = compQ.groupby("gvkey",group_keys=False)['niq'].progress_apply(\
                          lambda x: x.rolling(window = 4,min_periods=4).sum())
compQ['saleq_sum']    = compQ.groupby("gvkey",group_keys=False)['saleq'].progress_apply(\
                          lambda x: x.rolling(window = 4,min_periods=4).sum())
compQ['ebitda_sum']   = compQ.groupby("gvkey",group_keys=False)['ebitda'].progress_apply(\
                          lambda x: x.rolling(window = 4,min_periods=4).sum())
compQ['gp_sum']       = compQ.groupby("gvkey",group_keys=False)['gp'].progress_apply(\
                              lambda x: x.rolling(window = 4,min_periods=4).sum())

#All dates are month ends already
#unique_dates = compQ['datadate'].drop_duplicates().sort_values()

# Cleaning #
compQ = compQ.replace([np.inf, -np.inf], np.nan)

# Round date #
compQ['datadate'] = compQ['datadate'] + MonthEnd(0)
    
# Use 2-Month accounting date lag to replicate Aretz #

compQ['datadate'] = compQ['datadate'] + MonthEnd(AcctLag)

# Total debt alternative to LTQ (ltq)  
compQ['totaldebt'] = compQ[['dlttq', 'dlcq']].sum(axis=1, skipna=True)  #update 2025-06-18, in line with JKP

compQ['totaldebt'] = compQ['totaldebt'].where(compQ[['dlttq', 'dlcq']].notna().any(axis=1), np.nan) # if

# Operating leverage  
# Operating leverage is sales minus EBITDA, divided by EBITDA
# EBITDA is not explicitly defined, we assume the WRDS definition        
compQ['oper_lvg'] =(compQ['saleq_sum'] - compQ['ebitda_sum'])/\
    compQ['ebitda_sum']

# Debt-EBITDA      
# Debt-to-EBITDA uses total debt
# Neither total debt nor EBITDA is defined
# We assume it is sum of short-term and long-term debt divided by
# WRDS definition of quarterly EBITDA
compQ['debt_ebitda']   = compQ['totaldebt'] / compQ['ebitda_sum']

# Set and sort firms by gvkey and date #
compQ = compQ.set_index(['gvkey',
                         'datadate']).sort_index(level = ['gvkey',
                                                          'datadate'])

## Data is sampled continuously each and every fiscal quarter   ##
## Forward fill gvkey for merging with annual ##
compQ = compQ.groupby(level = "gvkey").ffill()

# Reset index
compQ = compQ.reset_index()

# Create other variables available in the KPP public data file #
# Total assets to book equity
compQ['at_be']          = compQ['atq']      /compQ['beq']
compQ['sales_at']       = compQ['saleq_sum']/compQ['atq']
compQ['gp_at']       = compQ['gp_sum']/compQ['atq']
compQ['sh_ps']          = compQ['sh'] + compQ['ps']
compQ['ebitda_sale']    = compQ['ebitda_sum'] / compQ['saleq_sum']

#### Other metrics ####
compQ['book_leverage_ltq'] = compQ['ltq']/compQ['atq']
compQ['book_leverage_2']   = compQ[ 'totaldebt']/compQ['atq']


#2025-06-06 remove duplicate subset
compQ1=compQ[['gvkey', 'datadate','year',
             'atq', 'ltq', 'dlttq', 'dlcq','beq0','beq', 
             'niq','mibtq','ps','cheq','invtq','sh','sh_ps',
             'ebitda_sum', 'saleq_sum','ebitda_sale',
             'totaldebt',  
             'oper_lvg', 
             'debt_ebitda',              
              'niq_sum',
             'at_be','sales_at' , 'gp_at',
             'book_leverage_ltq',
             'book_leverage_2'
             ]]

###################
# CRSP Block      #
###################
# sql similar to crspmerge macro
crsp_m = conn.raw_sql(f"""
    select 
        a.permno,
        a.permco,
--         a.ticker, Not using ticker, using IBES ticker
        a.issuernm,
        a.mthcaldt,
        a.siccd,
        a.issuertype,
        a.securitytype,
        a.securitysubtype,
        a.sharetype,
        a.usincflg,
        a.primaryexch,
        a.conditionaltype,
        a.tradingstatusflg,
        a.mthret,
        a.mthretx,
        a.shrout,
        a.mthprc,
        a.mthret - coalesce(b.t30ret, c.rf) as ret_exc,
        b.t90ret
    from crsp.msf_v2 as a
      left join crsp.mcti as b
           on extract(year  from a.mthcaldt) = extract(year  from b.caldt)
          and extract(month from a.mthcaldt) = extract(month from b.caldt)
      left join ff.factors_monthly as c
           on extract(year  from a.mthcaldt) = extract(year  from c.date)
          and extract(month from a.mthcaldt) = extract(month from c.date)
    where a.mthcaldt between '{start_date}' and '{end_date}'
    """,
    date_cols=['mthcaldt']
)
                      
crsp_m = crsp_m.loc[(crsp_m.sharetype=='NS') & \
                    (crsp_m.securitytype=='EQTY') & \
                    (crsp_m.securitysubtype=='COM') & \
                    (crsp_m.usincflg=='Y') & \
                    (crsp_m.issuertype.isin(['ACOR', 'CORP']))]

crsp_m = crsp_m.loc[(crsp_m.primaryexch.isin(['N', 'A', 'Q'])) & \
                   (crsp_m.conditionaltype =='RW') & \
                   (crsp_m.tradingstatusflg =='A')]

# change variable format to int
crsp_m[['permco','permno']]=crsp_m[['permco','permno']].astype(int)

# Line up date to be end of month
crsp_m['jdate']=crsp_m['mthcaldt']+MonthEnd(0)

# calculate market equity
crsp = crsp_m.copy()

# crsp['mthret']=crsp['mthret'].fillna(0)
# crsp['mthretx']=crsp['mthretx'].fillna(0)
crsp['me']=crsp['mthprc']*crsp['shrout']  #CRSP share numbers in thousands
crsp=crsp.sort_values(by=['jdate','permco','me'])

### Aggregate Market Cap ###
# sum of me across different permno belonging to same permco a given date
crsp_summe = crsp.groupby(['jdate','permco'])['me'].sum().reset_index()

# largest mktcap within a permco/date
crsp_maxme = crsp.groupby(['jdate','permco'])['me'].max().reset_index()

# join by jdate/maxme to find the permno with the largest me
crsp1=pd.merge(crsp, crsp_maxme, how='inner', on=['jdate','permco','me'])  #max permno me as me_unadjusted

# drop me column and replace with the sum me, company me
# crsp1=crsp1.drop(['me'], axis=1)
crsp1.rename(columns={'me':'me_unadjusted'}, inplace=True)

# join with sum of me to get the correct market cap info, me is the sum of me under a permnoco
crsp2=pd.merge(crsp1, crsp_summe, how='inner', on=['jdate','permco'])

# sort by permno and date and also drop duplicates
crsp2 = crsp2.sort_values(by=['permno','jdate']).drop_duplicates()

crsp2 = crsp2.drop(['issuertype', 'securitytype',
       'securitysubtype', 'sharetype', 'usincflg', 'primaryexch',
       'conditionaltype', 'tradingstatusflg',     
       ], axis = 1)


#######################
# CCM Block           #
#######################

# 2025-06-05: I added iid because IBES ticker is security based.

ccm0=conn.raw_sql("""
                  select gvkey, liid as iid, lpermno as permno, lpermco as permco, linktype, linkprim, 
                  linkdt, linkenddt
                  from crsp.ccmxpf_linktable
                  where substr(linktype,1,1)='L'
                  and (linkprim ='C' or linkprim='P')
                  """, date_cols=['linkdt', 'linkenddt'])

# if linkenddt is missing then set to today date
ccm0['linkenddt']=ccm0['linkenddt'].fillna(pd.to_datetime('today'))
ccm0['linkdt']=pd.to_datetime(ccm0['linkdt'])
ccm0['linkenddt']=pd.to_datetime(ccm0['linkenddt'])

# There is duplicates in comp.security, important to remove duplicates.
_sec = conn.raw_sql(""" select distinct ibtic, gvkey, iid from comp.security """)

#This step does not increase duplicates.
ccm0 = pd.merge(ccm0, _sec.loc[_sec.ibtic.notna()], how='left', on=['gvkey', 'iid'])

# Duplicate here?
# Check ccm duplicates: for given linkdt-linkenddt, one permno can map to multiple gvkeys, but not the other way around.
# Each gvkey corresponds to one permno becauses of the primary link marker filter
# Inevitably, when permno corresponds to multiple gvkeys or gvkey iid, there will be duplicates.

#dup_mask=ccm0.groupby(['permno','linkdt','linkenddt']).size().reset_index(name='count')
#duplicates0=pd.merge(ccm0, dup_mask[dup_mask['count']>1], how='inner', on=['permno','linkdt','linkenddt']).sort_values(by=['count','permno','iid'], ascending=False)


# Read in ICLINK output #
# iclink.pkl is the output from the python program iclink
# it contains the linking between crsp and ibes
with open('Data/iclink.pkl', 'rb') as f:
    iclink = pkl.load(f)

# high quality links from iclink
# score = 0 or 1, there is duplicate by permno and ticker due to change in names? Remove duplicates.
iclink_hq = iclink.loc[(iclink.score <=1)]

# For each permno, find the ticker with the lowest score (best match)
# This ensures that adding IBES ticker does not create duplicates
idx = (
    iclink_hq
    .groupby("permno")["score"]
    .idxmin()
)

#Select best matches
iclink_hq = iclink_hq.loc[idx, ["permno", "ticker"]]

#This step increases duplicates, because iclink_hq has multiple tickers per permno...
ccm = pd.merge(ccm0, iclink_hq, how='left', on=['permno'])

# fill missing ticker with ibtic
ccm.ticker = np.where(ccm.ticker.notnull(),ccm.ticker, ccm.ibtic)

#dup_mask=ccm.groupby('permno')['ticker'].nunique().reset_index(name='count')

#dup_mask=ccm.groupby(['permno','linkdt','linkenddt']).size().reset_index(name='count')

#duplicates=pd.merge(ccm, dup_mask[dup_mask['count']>1], how='inner', on=['permno','linkdt','linkenddt']).sort_values(by=['count','permno'], ascending=False)

# Keep relevant columns and drop duplicates if there is any (Any duplicates here is due to duplicates in ccm0)
ccm = ccm[['gvkey', 'permco', 'permno', 'linkdt', 'linkenddt','ticker']]

#no duplicates, but there are 2 gvkeys for the same permno sometimes.
ccm = ccm.drop_duplicates()


# Merge COMPUSTAT Quarter
ccm1 = pd.merge( compQ1 , ccm, how = 'left' , on =[ 'gvkey'])
ccm1['yearend'] = ccm1['datadate']+YearEnd(0)
ccm1['jdate']   = ccm1['datadate']+MonthEnd(0) #Month End, not necessary, but for consistency with CRSP

# Impose date ranges
ccm2 = ccm1[(ccm1['datadate']>=ccm1['linkdt'])&(ccm1['datadate']<=ccm1['linkenddt'])].copy()
ccm2 ['permno'] = ccm2 ['permno'].astype(int)

# check whether obs is not unique by permno and datadate
# countobs=ccm2.groupby(['permno','datadate']).size().reset_index(name='count').sort_values(by='count', ascending=False)
#
# countobs[countobs['count']>1]['permno'].nunique()
# Some duplicates generateed by the 27 duplicates in ccm0.
# duplicates=pd.merge(ccm2[['permno','datadate','gvkey','ticker']], countobs[countobs['count']>1], how='inner', on=['permno','datadate']).sort_values(by=['count','permno','datadate'], ascending=False)

#################################
# Could try merge_asof here #

df = pd.merge(crsp2, 
              ccm2, 
              how='left',
              on = ['permco', 
                    'permno', 
                    'jdate'])  #Concurrent MV not lagged MV

df.drop(['datadate', 'linkdt', 'linkenddt', 'yearend','year'], axis = 1, inplace = True)

#drop 320 duplicates due to ccm merging table
df.drop_duplicates(subset=['jdate', 'permno'], keep='first', inplace=True)

#forward fill and back fill ticker for IBES matching, since CRSP is monthly and CCM is quarterly, there are some missing ticker values.
#I need to do this for ticker not gvkey becase accounting vars are forward filled, IBES ticker is not forward filled.
df=df.sort_values(by=['permno', 'jdate'])
df['ticker']=df.groupby('permno')['ticker'].ffill()
df['ticker']=df.groupby('permno')['ticker'].bfill() #monthly data before the first quarterly data also has ticker

#I need to fill gvkey for Compustat annual matching. This is to accommodate the difference in accounting variable lag: quarterly 2 month and annual 4 month,
# without forward filling gvkey, the annual accounting variables will not have a gvkey in df in the corresponding month.
df['gvkey']=df.groupby('permno')['gvkey'].ffill()
df['gvkey']=df.groupby('permno')['gvkey'].bfill() #monthly data before the first quarterly data also has gvkey

#df_test=df[df.permno==14471][['permno','jdate','ticker','atq']].sort_values(by='jdate')

# check whether obs is unique by permno and jdate
# countobs=df.groupby(['permno','jdate']).size().reset_index(name='count').sort_values(by='count', ascending=False)
#
# test=df[df.permno==23536].sort_values(by='jdate')
#
# test1=ccm[ccm['permno']==23536]

#updated 2025-05-05, resample to month-end for each permno to remove duplicates?
#df1 = df.groupby("permno")[df.columns[1:]].\
#    progress_apply(lambda x: x.resample("ME").last())  #For each permno resample ME so that if there are multiple observations only the last one will be kept

# Why df has duplicates? because in ccm one permno could correspond to 2 gvkey-iids. No duplicate here

##########################
# IBES Block             #
#
##########################

#check ibes horizon
# ibes_horizon=conn.raw_sql("""
# select ticker, fpi, fpedats, statpers
# from ibes.statsum_epsus
# where fpi in ('6','7','1','2','3','4','5')
# and statpers<ANNDATS_ACT /*only keep summarized forecasts prior to earnings annoucement*/
# and measure='EPS'
# and medest is not null and fpedats is not null
# and (fpedats-statpers)>=0
# """, date_cols=['statpers', 'fpedats'])
#
# ibes_horizon['jdate'] = ibes_horizon['statpers'] + MonthEnd(0)  #Align with month-end
#
# ibes_horizon['horizon']= (ibes_horizon['fpedats'] - ibes_horizon['jdate']).dt.days #Still we would like to restrict the forecast to within 2-4 months before merging.

# fpis=['6','7','1','2','3','4','5']
#
# n_panels=len(fpis)
#
# ncols = min(3, n_panels)
# nrows = int(np.ceil(n_panels / ncols))
#
# fig, axes = plt.subplots(nrows, ncols, figsize=(5 * ncols, 4 * nrows), squeeze=False)
#
# for ax, f in zip(axes.flatten(), fpis):
#     data = ibes_horizon.loc[ibes_horizon['fpi'] == f, 'horizon'].dropna().values
#     if len(data) == 0:
#         ax.set_visible(False)
#         continue
#
#     # Histogram (density=True scales to a PDF)
#     ax.hist(data, bins=30, density=True, alpha=0.7, edgecolor='black')
#     ax.set_ylabel('Density')
#     ax.set_xlabel('horizon')
#     ax.set_title(f"fpi = {f!r}")
#
#     ax.set_title(f"fpi = {f!r}")
#     ax.set_xlabel('horizon')
#
# # turn off any unused axes
# for ax in axes.flatten()[n_panels:]:
#     ax.set_visible(False)
#
# plt.tight_layout()
# plt.show()

#check fpi distribution
# ax = ibes_horizon['fpi'].dropna().hist(bins=20, edgecolor='black', alpha=0.7, figsize=(8,5))
#
# ax.set_xlabel('fpi')
# ax.set_ylabel('Frequency')
# ax.set_title('Histogram of fpi')
#
# plt.tight_layout()
# plt.show()
#
# ax = ibes_horizon['horizon'].dropna().hist(bins=20, edgecolor='black', alpha=0.7, figsize=(8,5))
#
# ax.set_xlabel('fpi')
# ax.set_ylabel('Frequency')
# ax.set_title('Histogram of fpi')
#
# plt.tight_layout()
# plt.show()


#include all possible horizons till FY5

ibes = conn.raw_sql(f"""
select a.ticker, a.cusip,fpedats,a.statpers,ANNDATS_ACT,numest, medest,actual,stdev, fpi, b.shout
from ibes.statsum_epsus a, ibes.actpsum_epsus b
where fpi in ('6', '7','1','2','3','4','5')  /*1 is for annual forecasts, 6 is for quarterly*/
and (a.statpers<ANNDATS_ACT or ANNDATS_ACT is null) /*only keep summarized forecasts prior to earnings annoucement, or anonouncement yet to be made*/
and a.measure='EPS' 
and medest is not null and fpedats is not null
and fpedats>=a.statpers
and a.statpers>='{start_date}'
and a.statpers<='{end_date}'
and a.statpers=b.statpers
and a.ticker=b.ticker
""", date_cols=['statpers', 'fpedats', 'ANNDATS_ACT'])

ibes['forearn']=ibes['medest']*ibes['shout']  #Forecast earnings in million dollars

ibes['jdate'] = ibes['statpers'] + MonthEnd(0)  #Align with month-end

ibes['horizon']= (ibes['fpedats'] - ibes['jdate']).dt.days #Still we would like to restrict the forecast to within 2-4 months before merging.


#Can I do something similar and musk IBES fpedates? Not a good idea because we need to match with statpers not fpedats.
# ibes['fiscal_month'] = ibes['fpedats'].dt.month

#Perhaps restrict horizon to above 90 days and keep the shortest horizon for each ticker/statpers combination?
#Then resample statpers to end of month for matching with CRSP/COMPUSTAT

#before filtering horizon, forward fill jdate per fpedate? No.

#Merge with CRSP/COMPUSTAT

#Forcasted earnings in million dollars, I will not fill in missing values for forecast. Keep forecast horizon between 2-4 months.

#Add one-quarter ahead forecast to the dataset (60-120 days ahead).
#Filter '6' and '7' is necessary, because '6' and '7' are quarterly EPS, others are annual EPS
df = pd.merge(df,
              ibes[ ibes['horizon'].between(50, 130) & ibes['fpi'].isin(['6', '7'])][['ticker','jdate','forearn','horizon']],
              how='left',
              on = ['ticker',
                    'jdate'])

df=df.rename(columns={'forearn':'EARN1Q','horizon':'horizon1Q'})

#Some month only has one quarterly forecast some months have two: if it is the month immediately after a fiscal quarter end, there is only one (2 months), otherwise two (1-4 or 0-3).
#I take the longest horizon for each month, which could be 2, 3, or 4 months ahead.
#This is quite important: take longest horizion after merging.

df=df.sort_values(['permno','jdate','horizon1Q'], ascending=[True, True, False])

df=df.drop_duplicates(['permno','jdate'], keep='first')  #Keep the longest horizon for each month, this step keeps duplicates from the ccm merge.

print(df.horizon1Q.describe()) #average prediction horizion is 90 days, perfect.

#Add one-year ahead forecast to the dataset (180-540 days ahead)
df = pd.merge(df,
              ibes[ ibes['horizon'].between(170, 550) & ibes['fpi'].isin(['1', '2'])][['ticker','jdate','forearn','horizon']],
              how='left',
              on = ['ticker',
                    'jdate'])

df=df.rename(columns={'forearn':'EARN1Y','horizon':'horizon1Y'})

#Keep the longest horizon for each month, which could be 6-18 months ahead.
df=df.sort_values(['permno','jdate','horizon1Y'], ascending=[True, True, False])

df=df.drop_duplicates(['permno','jdate'], keep='first')  #Keep the longest horizon for each month, this step keeps duplicates from the ccm merge.

print(df.horizon1Y.describe()) #average and median prediction horizion around 365 days, perfect.

#Maybe 2-Y?
df = pd.merge(df,
              ibes[ ibes['horizon'].between(530, 1000) & ibes['fpi'].isin(['2', '3'])][['ticker','jdate','forearn','horizon']],
              how='left',
              on = ['ticker',
                    'jdate'])

df=df.rename(columns={'forearn':'EARN2Y','horizon':'horizon2Y'})

#Keep the longest horizon for each month, which could be 6-18 months ahead.
df=df.sort_values(['permno','jdate','horizon2Y'], ascending=[True, True, False])

df=df.drop_duplicates(['permno','jdate'], keep='first')  #Keep the longest horizon for each month, this step keeps duplicates from the ccm merge.

print(df.horizon2Y.describe()) #average and median prediction horizion around 730 days, perfect.

df=df.drop(['horizon1Q', 'horizon1Y', 'horizon2Y'], axis=1)  #drop horizon columns, not needed anymore)

#IBES LTG

ibes_ltg = conn.raw_sql(f"""
select a.ticker, a.cusip, a.statpers, numest, medest, stdev, fpi, b.shout
from ibes.statsum_epsus a, ibes.actpsum_epsus b
where fpi ='0'  /*1 is for annual forecasts, 6 is for quarterly*/
and a.measure='EPS' 
and medest is not null 
and a.statpers>='{start_date}'
and a.statpers<='{end_date}'
and a.statpers=b.statpers
and a.ticker=b.ticker
""", date_cols=['statpers'])

ibes_ltg['forearn']=ibes_ltg['medest']*ibes_ltg['shout']  #Forecast earnings in million dollars

ibes_ltg['jdate'] = ibes_ltg['statpers'] + MonthEnd(0)  #Align with month-end


df = pd.merge(df,
              ibes_ltg[['ticker','jdate','forearn']],
              how='left',
              on = ['ticker',
                    'jdate'])


df=df.rename(columns={'forearn':'EARNLT'})

#sanity check
#ibes_test=ibes[ibes.ticker=='0000'][['ticker','fpedats', 'jdate','forearn']].sort_values(['jdate','fpedats'])
#df_test=df[df1.permno==14471][['permno','jdate','ticker','atq','fpedats','horizon','forearn']].sort_values(by=['jdate','fpedats'])


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

df = df.set_index(['permno','jdate'])

###################
# Compustat Block #
#  Annual         #
###################

comp = conn.raw_sql(f"""
                    select gvkey, datadate, fyr, fyear,
                    at, pstkl, txditc,
                    pstkrv, seq,ceq, pstk, lt, dltt, dlc, sich,
                    ebitda, gp, revt, cogs, mibt, sale,ni, dd1,dd2,dd3,dd4,dd5 
                    from comp.funda
                    where indfmt='INDL' 
                    and datafmt='STD'
                    and popsrc='D'
                    and consol='C'
                    and datadate >= '{start_date}'
                    and datadate <= '{end_date}'
                    """, date_cols=['datadate'])
        
comp.to_hdf(path+'Data/comp_annual.h5', key = 'daily')        
#comp = pd.read_hdf(path+r'Data/comp_annual.h5')

####################### 
# Annual COMPUSTAT    #
#######################                    
comp['year']=comp['datadate'].dt.year

####################### 
# Old Book value      #
####################### 

# Create preferrerd stock
comp['ps']=np.where(comp['pstkrv'].isnull(),
                    comp['pstkl'], 
                    comp['pstkrv'])
comp['ps']=np.where(comp['ps'].isnull(),
                    comp['pstk'], 
                    comp['ps'])
comp['ps']=np.where(comp['ps'].isnull(),
                    0,
                    comp['ps'])
comp['txditc']=comp['txditc'].fillna(0)

# create book equity
comp['be1']=comp['seq']+comp['txditc']-comp['ps']
comp['be1']=np.where(comp['be1']>0, 
                    comp['be1'], 
                    np.nan)

#######################

####################### 
# New Book value      #
####################### 
comp['year']=comp['datadate'].dt.year

# Create preferrerd stock
comp['ps']=np.where(comp['pstkrv'].isnull(),
                    comp['pstkl'], 
                    comp['pstkrv'])
comp['ps']=np.where(comp['ps'].isnull(),
                    comp['pstk'], 
                    comp['ps'])
comp['ps']=np.where(comp['ps'].isnull(),
                    0,
                    comp['ps'])
comp['txditc']=comp['txditc'].fillna(0)

#  Set share holders equity to seq
comp['sh'] = comp['seq']

#  If NaN set to (CEQ + PSTX)
comp['sh'] = np.where( comp['sh'].isnull(),                      
                       (comp['ceq'] + comp['ps']),
                        comp['sh'] )

#  If still NaN set to (AT - LT)
comp['sh'] = np.where( comp['sh'].isnull(),
                       (comp['at'] - comp['lt']), 
                        comp['sh'] )
                          
# Create book equity
comp['be2'] = comp['sh'] + comp['txditc'] - comp['ps']
comp['be2'] = np.where(comp['be2']>0,
                      comp['be2'],
                      np.nan)

#comp[['be1','be2']].isnull().sum()
comp['be'] = comp['be2']

#######################
# Number of years in Compustat
comp=comp.sort_values(by=['gvkey','datadate'])
comp['count']=comp.groupby(['gvkey']).cumcount()

comp=comp[['gvkey','datadate','year','be','at','lt','dltt', 'dlc','sich',
           'ebitda','gp','sale','revt','cogs','mibt','ps','count', 'fyr','ni',
           'dd1','dd2', 'dd3','dd4', 'dd5'
           ]]

comp['fiscal_year'] = comp['datadate']+ MonthEnd(0)

comp = comp.replace([np.inf, -np.inf], np.nan)

comp['datadate'] = comp['datadate'] + MonthEnd(0)

comp = comp.set_index(['gvkey',
                       'datadate']).sort_index(level = ['gvkey',
                                                        'datadate'])
# Resample each firm based on its fiscal year end to get
# an annual "contiguous" time-series #
comp                 = comp.reset_index()   
comp['fiscal_month'] = comp['datadate'].dt.month
    
# Resampling each gvkey based on fiscal year-ends #                             
year_ends =   comp['fiscal_month'].sort_values().unique()

comp_resamp = pd.DataFrame()

for y in year_ends:
    print(y)  
    if   y == 12:
        R = "YE-DEC"
    elif y == 11:
        R = "YE-NOV"
    elif y == 10:
        R = "YE-OCT"   
    elif y == 9:
        R = "YE-SEP"   
    elif y == 8:
        R = "YE-AUG"   
    elif y == 7:
        R = "YE-JUL"   
    elif y == 6:
        R = "YE-JUN"   
    elif y == 5:
        R = "YE-MAY"   
    elif y == 4:
        R = "YE-APR"   
    elif y == 3:
        R = "YE-MAR"   
    elif y == 2:
        R = "YE-FEB"   
    elif y == 1:
        R = "YE-JAN"       
    # No Fiscal changes
    dfy = comp[((comp['fiscal_month']    == y))]
    dfy = dfy.set_index(['datadate'])
    
    KEYs = list(dfy['gvkey'].unique())
    c       = 5000
    chunks  = [KEYs[x:x+c] for x in range(0, len(KEYs), c)]
    df_resamp = pd.DataFrame()
    for l in range(0,len(chunks)):
        print(l)
        KEY_Chunk = pd.DataFrame(chunks[l], columns = ['gvkey'])
        dfChunk = dfy[(dfy['gvkey'].isin(KEY_Chunk['gvkey']))]
        dfR = dfChunk.groupby(["gvkey"])[ dfChunk.columns[1:] ].\
            apply(lambda x: x.resample(R).last())
        df_resamp = pd.concat([df_resamp, dfR], axis = 0)
    
    # Concat to comp_resamp #
    comp_resamp = pd.concat([comp_resamp, df_resamp], axis = 0)
        
comp = comp_resamp.sort_index(level = ['gvkey',
                                     'datadate'])   

# Cleaning #
comp = comp.reset_index()
comp = comp.replace([np.inf, -np.inf], np.nan)

# JKP. 2023 use a 4-Month accounting date lag #

comp['datadate'] = comp['datadate'] + MonthEnd(4)

# Operating leverage is sales minus EBITDA, divided by EBITDA
# EBITDA is not explicitly defined, we assume the WRDS definition        
comp['oper_lvg'] =(comp['sale'] - comp['ebitda'])/\
    comp['ebitda']

# Debt-EBITDA      
# Debt-to-EBITDA uses total debt
# Neither total debt nor EBITDA is defined
# We assume it is sum of short-term and long-term debt divided by
# WRDS definition of quarterly EBITDA
comp['totaldebt']         = comp[['dltt', 'dlc']].sum(axis=1, skipna=True) #coarse missing dlc and dltt to zero

comp['totaldebt'] = comp['totaldebt'].where(comp[['dltt', 'dlc']].notna().any(axis=1), np.nan)

comp['debt_ebitda']   = comp['totaldebt'] / comp['ebitda']

#### Additional variables ####
comp['book_leverage_lt']  = comp['lt']/comp['at']

comp['book_leverage_2']   = comp[ 'totaldebt']/comp['at']

#Add debt maturity
mask_3Y = comp[['dltt', 'dd2', 'dd3']].notna().any(axis=1)
numerator_3Y = comp['dltt'].fillna(0) - comp[['dd2', 'dd3']].fillna(0).sum(axis=1)
comp['debt3Y'] = (numerator_3Y / comp['totaldebt']).where(mask_3Y, np.nan)

mask_5Y = comp[['dltt', 'dd2', 'dd3', 'dd4', 'dd5']].notna().any(axis=1)
numerator_5Y = comp['dltt'].fillna(0) - comp[['dd2', 'dd3', 'dd4', 'dd5']].fillna(0).sum(axis=1)
comp['debt5Y'] = (numerator_5Y / comp['totaldebt']).where(mask_5Y, np.nan)


comp['debtST'] = comp['dlc']/comp['totaldebt']

# Set and sort firms by gvkey and date #
comp = comp.set_index(['gvkey',
                         'datadate']).sort_index(level = ['gvkey',
                                                          'datadate'])

## Data is sampled continuously each and every fiscal year   ##
comp.columns

comp = comp[['oper_lvg','debt_ebitda',
             'ebitda','gp','sale',
             'be', 'at', 'lt', 'dltt', 'dlc',
             'dd1','dd2', 'dd3','dd4' , 'dd5',
             'totaldebt', 'book_leverage_2', 'book_leverage_lt',
             'debt3Y','debt5Y','debtST'                          
             ]]

# Rename columns to add A for annual
comp.columns = ['oper_lvgA','debt_ebitdaA',
             'ebitdaA', 'gpA','saleA',
             'be', 'at', 'lt', 'dltt', 'dlc',
             'dd1','dd2', 'dd3','dd4' ,'dd5',
             'totaldebtA', 'book_leverage_2A', 'book_leverage_ltA',
             'debt3Y','debt5Y','debtST']

###############################################################################

COMPa  = comp .reset_index()

# Merge COMPa with compQ and CRSP merged, COMPa data is assumed to be 4 month lagged
COMPa.rename(columns = {'datadate':'jdate'}, inplace = True)

df = pd.merge(df.reset_index(), 
              COMPa, 
              how='left',
              on = ['gvkey',                   
                    'jdate'])


# test=df[df['permno']==14593][['jdate','gvkey','dd1','dd2', 'dd3','dd4' ,'dd5',
#              'totaldebtA', 'book_leverage_2A', 'book_leverage_ltA',
#              'debt3Y','debt5Y','debtST']].sort_values(['jdate'])

df = df.set_index(['permno','jdate'])


# Forward fill #

cols_ffill = ['atq',
'ltq', 'dlttq', 'dlcq', 'beq','beq0' , 'niq', 'mibtq', 'ps', 'cheq', 'invtq',
'sh', 'sh_ps', 'ebitda_sum', 'saleq_sum', 'ebitda_sale', 'totaldebt',
'oper_lvg', 'debt_ebitda', 'niq_sum', 'at_be', 'sales_at',
'book_leverage_ltq', 'book_leverage_2', 'oper_lvgA', 'debt_ebitdaA',
'ebitdaA', 'saleA', 'be', 'at', 'lt', 'dltt', 'dlc', 'dd1', 'dd2','dd3', 'dd4',
'dd5', 'totaldebtA', 'book_leverage_2A', 'book_leverage_ltA',
'debt3Y','debt5Y','debtST']

df[cols_ffill] = df.groupby("permno")\
    [cols_ffill].ffill()
    
df = df.sort_index(level  =  "permno")

# Remove duplicates from ccm merge.
df = df[~df.index.duplicated()]


#######################
# Market Leverage     #
#######################
df['market_leverage']         = df['ltq']*1000 / (df['me']      + df['ltq']*1000 )

                                
#######################
# Earnings-Price      #
#######################     
df['ni_me']   =     df['niq_sum']*1000/df['me']

####################################
# Forecasted earning-to-Price      #
####################################

df['earn1q_at']=df['EARN1Q']/df['atq'] #Forecasted earnings to total asset ratio

df['earn1y_at']=df['EARN1Y']/df['atq'] #Forecasted earnings to total asset ratio

df['earn2y_at']=df['EARN2Y']/df['atq'] #Forecasted earnings to total asset ratio

df['earnlt_at']=df['EARNLT']/df['atq'] #Forecasted earnings to total asset ratio


#df['forearnmta']=df['forearn']*1000/(df['me']+df['ltq']*1000) #Forecasted earnings to total asset ratio?

print(df.earn1q_at.describe())

print(df.earn1y_at.describe())

print(df.sales_at.describe())

#######################
# Book-to-Price      #
#######################  
df['be_me']   =     df['beq']*1000/df['me']        
df['be_prc']  =     (df['sh']*1000 + df['ps']*1000)/df['me']        #Whether include tax credit or not

#######################
# Assets-to-Price      #
#######################  
df['at_me']   =     df['atq']*1000/df['me_unadjusted']         # This is the max market cap across all securities


########################
# Cash to MTA          #
########################

df['cashmta']=df['cheq']*1000/(df['me']+df['ltq']*1000)

df['nimta']=df['niq']*1000/(df['me']+df['ltq']*1000)

df['tlmta']= df['ltq']*1000 / (df['me']+ df['ltq']*1000 )


#Cleaning:
df = df.replace([np.inf, -np.inf], np.nan)


# rename columns

df.rename(columns={'mthret' :'rets',
                   'mthretx':'retx',
                   'mthprc' : 'prc'}, inplace=True)

# #######################
# Export to file        #
# #######################
df\
.to_hdf(path+f'Data/raw_data.hdf',
        key = "daily")  
# #######################












