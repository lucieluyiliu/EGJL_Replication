#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Sat Nov 30 05:34:47 2024

@author: Lucie Lu
"""


##########################################
# Two Trees Data Preparation             #
# Date:    November 2024                 #
# Updated: November   2024               #
# Kelly et al. 2023 Equity Chars         #
##########################################


# 
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

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path
os.chdir(path)   # no-op when already at the package root

# Scripts live in code/python/. Order matters: iclink builds the CRSP-IBES link first;
# CreditSpread must precede Sorts (which reads CS.h5 / firm_mat.h5 from CreditSpread).
scripts = ['iclink.py', 'MakeMainDataFile_V1.py', 'MakeSIGMA.py', 'MakePROB.py',
           'MakeCreditSpread.py', 'MakePortfolios_v2.py', 'MakeSorts.py', 'MakeAggShocks_v1.py']


for script in scripts:
    print(f"Running {script}...")
    result = subprocess.run(['python', os.path.join('code', 'python', script)])
    if result.returncode != 0:  # Check if the script ran successfully
        print(f"Error occurred while running {script}. Stopping execution.")
        break
    
    
    
    