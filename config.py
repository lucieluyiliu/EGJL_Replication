# -*- coding: utf-8 -*-
"""
Central relative paths for the EGJL "Excess Default Correlations" replication package.

MNSC item 13: all paths are RELATIVE and point to files within the package. Run every
script from the package ROOT directory (the master script does this for you); the paths
below are then resolved against the package root.
"""
path = "./"                  # package root == current working directory
data_dir = "Data/"           # all build inputs/outputs live under Data/
table_dir = "output/tables/" # R exhibit scripts write tables here
fig_dir = "output/figures/"  # R exhibit scripts write figures here

# WRDS username for the live database pulls (Compustat / CRSP / IBES).
# Replicators: set this to your own WRDS username. Leave as None to fall back to
# your OS login + ~/.pgpass (works only when your OS login matches your WRDS username).
wrds_username = "lucielu"
