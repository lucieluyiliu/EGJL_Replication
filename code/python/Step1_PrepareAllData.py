#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created:       2024-11-30
Last modified: 2026-06-22
Author:        Lucie Lu <lucie.lu@unimelb.edu.au>

Master driver for the data-build stage: runs the Make* scripts in order, each as a
subprocess, stopping if any one fails. Produces all derived inputs to the R analysis
(raw_data.hdf, sigma.h5, PROB.h5 / PROB_agg.csv, CS.h5, industry_sorts.csv, Agg_shocks.csv).
"""

import subprocess
import os

# Path config (MNSC item 13: relative paths; run from the package root).
import sys
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path
os.chdir(path)   # no-op when already at the package root

# Scripts live in code/python/. Order matters: iclink builds the CRSP-IBES link first;
# CreditSpread must precede Sorts (which reads CS.h5 from CreditSpread).
scripts = ['iclink.py', 'MakeMainDataFile_V1.py', 'MakeSIGMA.py', 'MakePROB.py',
           'MakeCreditSpread.py', 'MakePortfolios_v2.py', 'MakeSorts.py', 'MakeAggShocks_v1.py']


for script in scripts:
    print(f"Running {script}...")
    result = subprocess.run(['python', os.path.join('code', 'python', script)])
    if result.returncode != 0:  # Check if the script ran successfully
        print(f"Error occurred while running {script}. Stopping execution.")
        break
    
    
    
    