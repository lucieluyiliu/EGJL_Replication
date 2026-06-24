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
import sys
from datetime import datetime

# Path config (MNSC item 13: relative paths; run from the package root).
sys.path.insert(0, os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..')))
from config import path
os.chdir(path)   # no-op when already at the package root

# Build-stage log: tee each script's output to the console AND output/log/step1_build.log.
log_dir = os.path.join('output', 'log')
os.makedirs(log_dir, exist_ok=True)
log_path = os.path.join(log_dir, 'step1_build.log')

# Scripts live in code/python/. Order matters: iclink builds the CRSP-IBES link first;
# CreditSpread must precede Sorts (which reads CS.h5 from CreditSpread).
scripts = ['iclink.py', 'MakeMainDataFile_V1.py', 'MakeSIGMA.py', 'MakePROB.py',
           'MakeCreditSpread.py', 'MakePortfolios_v2.py', 'MakeSorts.py', 'MakeAggShocks_v1.py']

with open(log_path, 'w') as log:
    def tee(text):
        sys.stdout.write(text)
        sys.stdout.flush()
        log.write(text)
        log.flush()

    tee(f"Step 1 build started {datetime.now():%Y-%m-%d %H:%M:%S}\n")
    for script in scripts:
        tee(f"\n=== Running {script} ({datetime.now():%H:%M:%S}) ===\n")
        proc = subprocess.Popen(['python', os.path.join('code', 'python', script)],
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        for line in proc.stdout:
            tee(line)
        proc.wait()
        if proc.returncode != 0:  # stop if a script failed
            tee(f"Error occurred while running {script} (exit {proc.returncode}). Stopping execution.\n")
            break
        tee(f"--- Finished {script} (exit 0, {datetime.now():%H:%M:%S}) ---\n")
    tee(f"\nStep 1 build ended {datetime.now():%Y-%m-%d %H:%M:%S}\n")
    
    
    
    