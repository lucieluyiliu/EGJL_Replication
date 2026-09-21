#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created:       2026-09-21
Last modified: 2026-09-21
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Rebuilds from WRDS the firm-month Fama-French 48 industry tags shared by Alex
Dickerson (FF48_Stocks.h5) and compares the two tables.

This script documents how FF48_Stocks.h5 is constructed. It is NOT a step of the
build pipeline: Step1_PrepareAllData.py does not run it, and MakePortfolios_v2.py
reads the shared table FF48_Stocks.h5, not the rebuild. The rebuild agrees with the
shared table for 99.76% of stock-months (run of 2026-09-21); the differences come
from later CRSP revisions of SIC codes.

The shared table has one row per CRSP stock-month (crsp.msf_v2, January 1960 to
December 2022) and gives every stock a single SIC code for its whole history: the
CRSP header SIC code as of the end of 2022. It is rebuilt here as the last SIC code
in the CRSP name history (crsp.stocknames) that is effective on or before
31 December 2022. SIC codes are mapped to the 48 industries with the SIC ranges
published by Kenneth French (Siccodes48.txt). Following the shared table, the
unclassified SIC code 9999 is assigned to industry 48 (Other); any other SIC code
outside French's ranges is left unclassified (missing ffi48, empty description).

Inputs:  WRDS (crsp.msf_v2, crsp.stocknames); Data/Siccodes48.txt (Kenneth French's
         data library); Data/FF48_Stocks.h5 (shared table, used for the comparison only)
Outputs: Data/FF48_Stocks_WRDS.h5 (key 'daily'; columns mthcaldt, permno, sic, ffi48,
         ffi48_desc, the same layout as FF48_Stocks.h5)
"""

#* ************************************** */
#* Libraries                              */
#* ************************************** */

import os
import re
import pandas as pd
import numpy as np
import wrds
from pandas.tseries.offsets import *

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path, wrds_username

data_dir='Data/'

start_date='1/1/1960'

end_date='12/31/2022'      # last month of the shared table; SIC codes are taken as of this date

os.chdir(path)


#* ************************************** */
#* SIC -> FF48 map (Kenneth French)       */
#* ************************************** */

# Siccodes48.txt lists each industry as a header line ("<number> <short name> <long
# name>") followed by its SIC ranges ("<first>-<last> <description>").
ranges = []
industry = None
with open(path+data_dir+'Siccodes48.txt', encoding='latin-1') as f:
    for line in f:
        sic_range = re.match(r'^\s+(\d{4})-(\d{4})', line)
        header = re.match(r'^\s*(\d{1,2})\s+(\S+)\s+\S', line)
        if sic_range and industry is not None:
            ranges.append((industry[0], industry[1], int(sic_range.group(1)), int(sic_range.group(2))))
        elif header:
            industry = (int(header.group(1)), header.group(2))

ff48 = pd.DataFrame(ranges, columns=['ffi48', 'ffi48_desc', 'sic_first', 'sic_last'])
assert ff48['ffi48'].nunique() == 48, 'Siccodes48.txt did not parse into 48 industries'

# Lookup table indexed by the 4-digit SIC code (0-9999); NaN = not classified.
sic_to_ff48 = np.full(10000, np.nan)
for r in ff48.itertuples(index=False):
    sic_to_ff48[r.sic_first:r.sic_last+1] = r.ffi48
sic_to_ff48[9999] = 48          # convention of the shared table: SIC 9999 -> Other

ff48_names = ff48.drop_duplicates('ffi48').set_index('ffi48')['ffi48_desc']


#* ************************************** */
#* CRSP stock-months and SIC codes        */
#* ************************************** */

conn=wrds.Connection(wrds_username=wrds_username)   # WRDS username from config.py

# One row per stock-month.
crsp_m = conn.raw_sql(f"""
                      select mthcaldt, permno
                      from crsp.msf_v2
                      where mthcaldt between '{start_date}' and '{end_date}'
                      """, date_cols=['mthcaldt'])

# CRSP name history: each row is a period (namedt to nameenddt) with its SIC code.
names = conn.raw_sql(f"""
                     select permno, namedt, siccd
                     from crsp.stocknames
                     where namedt <= '{end_date}'
                     """, date_cols=['namedt'])

conn.close()

# Header SIC as of end_date: the SIC code of the last name period that started on or
# before end_date. It is constant within a stock.
hsic = names.sort_values(['permno', 'namedt']).groupby('permno', as_index=False).last()
hsic = hsic[['permno', 'siccd']].rename(columns={'siccd': 'sic'})

df = crsp_m.merge(hsic, how='left', on='permno')

print('CRSP stock-months:', len(df))
print('  of which without a SIC code (dropped):', int(df['sic'].isnull().sum()))
df = df[~df['sic'].isnull()].copy()

df['permno'] = df['permno'].astype(float)     # same dtypes as FF48_Stocks.h5
df['sic'] = df['sic'].astype('int32')

in_range = df['sic'].between(0, 9999)
df['ffi48'] = np.nan
df.loc[in_range, 'ffi48'] = sic_to_ff48[df.loc[in_range, 'sic'].values]
df['ffi48_desc'] = df['ffi48'].map(ff48_names).fillna('')

df = df.sort_values(['permno', 'mthcaldt'])
df = df[['mthcaldt', 'permno', 'sic', 'ffi48', 'ffi48_desc']].reset_index(drop=True)

df.to_hdf(path+data_dir+'FF48_Stocks_WRDS.h5', key='daily', mode='w')

print('Saved Data/FF48_Stocks_WRDS.h5:', len(df), 'rows,', df['permno'].nunique(), 'permnos,',
      df['mthcaldt'].min().date(), 'to', df['mthcaldt'].max().date())


#* ************************************** */
#* Compare with the shared table          */
#* ************************************** */

alex = pd.read_hdf(path+data_dir+'FF48_Stocks.h5', key='daily')
alex.columns = ['mthcaldt', 'permno', 'sic', 'ffi48', 'ffi48_desc']

both = alex.merge(df, on=['mthcaldt', 'permno'], how='outer', suffixes=('_alex', '_wrds'), indicator=True)

print('\nComparison with FF48_Stocks.h5 (shared table:', len(alex), 'rows,', alex['permno'].nunique(), 'permnos)')
print('  stock-months in both      :', int((both['_merge'] == 'both').sum()))
print('  only in the shared table  :', int((both['_merge'] == 'left_only').sum()))
print('  only in the WRDS rebuild  :', int((both['_merge'] == 'right_only').sum()))

m = both[both['_merge'] == 'both'].copy()
same_sic = m['sic_alex'] == m['sic_wrds']
same_ff = (m['ffi48_alex'] == m['ffi48_wrds']) | (m['ffi48_alex'].isnull() & m['ffi48_wrds'].isnull())
print('  same SIC code             : %.2f%%' % (100*same_sic.mean()))
print('  same FF48 industry        : %.2f%%' % (100*same_ff.mean()))
print('  same FF48 given same SIC  : %.2f%%' % (100*same_ff[same_sic].mean()))

by_permno = m.assign(same_sic=same_sic, same_ff=same_ff).groupby('permno')[['same_sic', 'same_ff']].first()
print('  stocks with the same SIC  : %.2f%% (%d of %d differ)' % (100*by_permno['same_sic'].mean(),
      int((~by_permno['same_sic']).sum()), len(by_permno)))
print('  stocks with the same FF48 : %.2f%% (%d of %d differ)' % (100*by_permno['same_ff'].mean(),
      int((~by_permno['same_ff']).sum()), len(by_permno)))

# Agreement over the sample period of the paper (1986 onwards), by year.
m['year'] = m['mthcaldt'].dt.year
m['same_ff'] = same_ff
by_year = m[m['year'] >= 1986].groupby('year')['same_ff'].agg(['size', 'mean'])
by_year.columns = ['stock-months', 'share same FF48']
print('\nShare of matched stock-months with the same FF48 industry, by year:')
print(by_year.to_string(float_format=lambda x: '%.4f' % x))

# Most frequent disagreements (shared table vs WRDS rebuild).
diff = m[~same_ff]
if len(diff) > 0:
    print('\nMost frequent FF48 disagreements (shared table -> WRDS rebuild), in stock-months:')
    print(diff.groupby(['ffi48_desc_alex', 'ffi48_desc_wrds']).size()
              .sort_values(ascending=False).head(15).to_string())
