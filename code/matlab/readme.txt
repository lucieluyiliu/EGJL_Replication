"Excess Co-movement in Default Risk"
by Jan Ericsson, Kristoffer Glover, Alexandre Jeanneret, Lucie Y. Lu

Replication package


MATLAB Codes

main.m
Main script to compute all numerical computations for the calibrated model (calibration parameters are described in Sections 2.1 and 3.3, for the asset price calculations, and Section 2.6 for the simulated economies).
Running the entire code (with the functions below in the same folder) should create the data for Tables 1-2, OA.1-2, and OA.10, and produce .pdf/.eps files for Figures 2-6 and OA.1-OA.4. 
It will also produce the asset pricing moment values stated in Sections 2.1 and 3.3, for the baseline calibrations.

CorrEst.m
Function to estimate the distance-to-default correlation between trees A and B given the optimal default boundary (i.e., computes Equation (11) in the paper).

Counterfactual.m
Function to compute the fixed-interest-rate counterfactual debt and equity values using the PSOR finite-difference method described in online Appendix A. The counterfactual keeps the risk-premium channel but replaces r(s) with a constant rbar, and holds the default boundary fixed at the solution of the full model. Used for Figure OA.1 in the Online Appendix.

CPE1D.m
Function to calculate the cross elasticity of two 1D s-dependent functions from numerical differentiation. Used for equilibrium credit spreads in Table OA.10 in the Online Appendix.

CSpread.m
Function to compute the credit spreads for both trees given the debt value as an input.

DefaultTimes.m
Function to compute the default times and default rates of each simulation.

Elasticity.m
Function to estimate the slope (elasticity) of the default boundary at a given point (using polyfix.m).

Equil.m
Function computing the total equity volatility and risk-free rate for a given economy (given by Equations (4) and (6) in the paper).

EqVol.m, EqVolPlot.m
Functions to calculate the equity return volatility from numerical differentiation of the equity value function (i.e., computation of Equation (F.5) in the Online Appendix).

ERPcalc.m, ERPPlot.m
Functions to calculate the equity risk premium from numerical differentiation of the equity value function (i.e., computation of Equation (F.8) in the Online Appendix).

polyfix.m
Function to fit a polynomial of order n to some data but with the constraint that the fitted function passes through a given point (needed for computing the elasticity of the boundary with Elasticity.m).

PROBDEF.m
Function to compute the probability of default (under both P and Q) for a given boundary, as described in online Appendix G.

SimulatedCorrelation.m, SimulatedCorrelationDD.m, SimulatedCorrelationDDstat.m, SimulatedCorrelationEExRet.m
Functions performing calculation of various quantities using the results from 'Simulation.m' and 'DefaultTimes.m'

SimulatedMoment.m
Function to compute the distribution of various asset pricing moments across different simulations.

Simulation.m
Function producing the different simulated economy values of X_i according to the details described in Section 2.6.

TWOTREEY.m
Function to compute the debt and equity value (with optimal default boundary) using the PSOR finite-difference method described in online Appendix A.

UnleveredEquity.m
Function computing the unlevered equity value (given by Equation (8) in the paper).

UnleveredEquity_count.m
Function computing the unlevered equity value in the counterfactual case when r(s)=rbar.

vcoch.m
Function computing the price-to-output ratio of an unlevered tree (the value V^i(s_t) in Equation (8) and given by Equation (A.1) in the Online Appendix).