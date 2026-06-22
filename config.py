# -*- coding: utf-8 -*-
"""
Central paths for the EGJL "Excess Default Correlations" replication package.

MNSC item 13: paths are PORTABLE. The package root is derived from this file's own
location, so every script resolves files against the package root regardless of the
current working directory (e.g. when run from an IDE such as PyCharm, not just from
the master script run at the package root).
"""
import os

# Package root = the directory that contains this config.py.
path = os.path.dirname(os.path.abspath(__file__)) + os.sep
data_dir = "Data/"           # all build inputs/outputs live under Data/
table_dir = "output/tables/" # R exhibit scripts write tables here
fig_dir = "output/figures/"  # R exhibit scripts write figures here

# WRDS username for the live database pulls (Compustat / CRSP / IBES).
# Replicators: set this to your own WRDS username. Leave as None to fall back to
# your OS login + ~/.pgpass (works only when your OS login matches your WRDS username).
wrds_username = "lucielu"
