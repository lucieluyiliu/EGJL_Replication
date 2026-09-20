%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This file reproduces the calculation and plots the figures in           %
% "Excess Co-movement in Default"                                         % 
% by Jan Ericsson, Kristoffer Glover, Alexandre Jeanneret and Lucie Y. Yu %
% accepted at Management Science on XXX 2026                              % 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

clear; close all; clc;

% Resolve this file's folder so the helper functions and the relative output
% paths below work regardless of where MATLAB was launched. mfilename is empty
% when code is pasted/evaluated interactively (no current file); in that case we
% fall back to the current folder, so for interactive use first cd into code/matlab.
if isempty(mfilename)
    thisdir = pwd;
else
    thisdir = fileparts(mfilename('fullpath'));
end
cd(thisdir);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RUN OPTIONS AND OUTPUT PATHS                           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% RECOMPUTE = true  : recompute the model from scratch (the TWOTREEY solves,
%                     default probabilities, and the simulation block, which is
%                     slow), then save the results to Data/DataFile.mat.
% RECOMPUTE = false : skip that block and load the precomputed results from
%                     Data/DataFile.mat instead.
% Either way, the tables and figures below are produced from those results.
RECOMPUTE = false;

% Folders resolved relative to this file, so they work regardless of the working
% directory. Figures are written to the package output/figures; the precomputed
% solutions live in the package Data folder, alongside the empirical inputs.
figdir   = fullfile(thisdir, '..', '..', 'output', 'figures');
tabledir = fullfile(thisdir, '..', '..', 'output', 'tables');
datadir  = fullfile(thisdir, '..', '..', 'Data');
datafile = fullfile(datadir, 'DataFile.mat');
if ~exist(figdir,'dir');    mkdir(figdir);    end
if ~exist(tabledir,'dir');  mkdir(tabledir);  end
if ~exist(datadir,'dir');   mkdir(datadir);   end

% Log the console output (including the printed tables and timing) to
% output/log/matlab_run.log, fresh each run.
logdir = fullfile(thisdir, '..', '..', 'output', 'log');
if ~exist(logdir,'dir'); mkdir(logdir); end
logfile = fullfile(logdir, 'matlab_run.log');
if exist(logfile,'file'); delete(logfile); end
diary(logfile);
tStart = tic;   % overall runtime, reported at the end (recorded in the diary)

% Each figure is forced to the light theme just before export (see the theme(...)
% calls in the plotting section), so the transparent-background figures have dark
% axes and text regardless of the MATLAB UI theme. A groot default cannot be used:
% the Figure Theme property rejects default values.

% Fix the random number generator so the simulation block (Simulation.m, the only
% source of randomness) is reproducible across runs and machines. Seed 0 with the
% Mersenne Twister is MATLAB's default startup state, set here explicitly.
rng(0,'twister');

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% THIS CODE SECTION DEFINES SOME REQUIRED PARAMETERS ETC %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%base-line parameters
mu=0.02;     %Expected growth rate for Tree A
muB=0.02;    %Expected growth rate for Tree B
sig=0.2;     %Volatility for Tree A
sigB=0.2;    %Volatility for Tree B
rho=0;       %Correlation between trees
del=0.06;    %Representative agent's discount rate
cost=0.622;  %Fraction of unlevered assets lost in bankruptcy
phi=0.15;    %Tax rate
q=0;         %Fraction recovered by equity holders in default
m=0;         %Rollover parameter (1/m is the average maturity of debt)
c=0.4;       %Fixed coupon
omega=1.8;   %The baseline relaxation parameter for the PSOR finite-difference algorithm

%grid sizes
Ny=1001;                   %Number of y=log(X) steps (default 1001)
Ns=501;                    %Number of s steps (default 501)
ymin=-3;                   %Lower limit of y on the grid
ymax=3;                    %Upper limit of y on the grid
y=linspace(ymin,ymax,Ny);  %Defining the Y=ln(X) state space 
s=linspace(0,1,Ns);        %Defining the s state space 
dy=y(2)-y(1);              %Calculating the y-step size
ds=s(2)-s(1);              %Calculating the s-step size 

%This computes the risk-free rate as a function of s
[~,rf] = Equil(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB); 

%This computes the value of j corresponding to s=0.5
jhalf = round(0.5/ds)+1; 

%This computes the default face value of debt for rollover debt
p=c/rf(jhalf); 

%This computes the value of i corresponding to X=1
ibase = round((log(1)-ymin)/dy)+1; 

%Defines the joint (Y,S) grid for interpolation
[Y,S] = ndgrid(y,s); 

%This defines the parameters needed for the simulations analysis
Tmax = 10;              %The maximum length (in years) of each simulation
Nt = Tmax*252;          %This computes the number of daily time-steps
t=linspace(0,Tmax,Nt);  %This defines the time gridNsim = 20000;
xAl = 0.25;             %This is the lower bound of the uniform distribution for starting xA
xAu = 1.5;              %This is the upper bound of the uniform distribution for starting xA
Nsim = 20000;           %The number of simulations to run



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% THIS CODE SECTION COMPUTES THE RESULTS FOR CREATION OF RESULTS DATAFILE.MAT %               
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

if RECOMPUTE

%Start the parallel pool once, with the default number of workers (one per core),
%and disable the idle timeout. By default the pool shuts down after 30 idle minutes,
%which happens during the long serial steps below; a failed restart then makes the
%next parfor block run serially.
delete(gcp('nocreate'));
pool = parpool('Processes','IdleTimeout',Inf);
fprintf('Parallel pool started with %d workers (IdleTimeout = Inf)\n', pool.NumWorkers);

%CHANGING LEVERAGE [Needed for FIGURE 3]
%This uses parallel commands for different values of leverage (parameter c being 0.2, 0.4 and 0.6, 0.4 is base case)
parfor k=1:3
   [E{k},D{k},B{k}] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost,0.2+(k-1)*0.2,0,0,omega,q);
end
E00=E{2};
D00=D{2};
B00=B{2};
BM0=B{1};
BP0=B{3};


%CHANGING CORRELATION [Needed for FIGURE 4]
%This uses parallel commands for different values of correlation (parameter rho (from -0.9 to 0.9)
%Note there is some numerical instability for rho = -0.5 and 0.5 so we compute for a slightly different number
%Also note that the omega is the relaxation parameter for each run and it generally needs to be lower for more extreme correlations
%A lower omega value slows down convergence but increases the likelihood of convergence
numlist = {-0.9,-0.8,-0.7,-0.6,-0.4999,-0.4,-0.3,-0.2,-0.1,0.1,0.2,0.3,0.4,0.5001,0.6,0.7,0.8,0.9};
omegalist = {1.6,1.6,1.6,1.6,1.6,1.6,1.7,1.7,1.8,1.7,1.7,1.6,1.6,1.6,1.6,1.6,1.6,1.6};
parfor k=1:length(numlist)
   [~,~,B{k}] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,numlist{k},del,mu,muB,phi,cost,0.4,0,0,omegalist{k},q); 
end
Bcorm09=B{1};
Bcorm08=B{2};
Bcorm07=B{3};
Bcorm06=B{4};
Bcorm05=B{5};
Bcorm04=B{6};
Bcorm03=B{7};
Bcorm02=B{8};
Bcorm01=B{9};
Bcorp01=B{10};
Bcorp02=B{11};
Bcorp03=B{12};
Bcorp04=B{13};
Bcorp05=B{14};
Bcorp06=B{15};
Bcorp07=B{16};
Bcorp08=B{17};
Bcorp09=B{18};


%CHANGNG DEBT MATURITY [Needed for TABLE 1, TABLE 3, FIGURE 3C, and FIGURE 5]
%This uses parallel commands for different values m (1/30, 1/10 and 1/5, corresponding to 30-, 10- and 5-year average maturity)
numlist = {1/30,1/10,1/5};
omegalist = {1.7,1.6,1.5};
parfor k=1:length(numlist)
   [E{k},D{k},B{k}] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost,c,numlist{k},c/rf(jhalf),omegalist{k},q);
end
E0M=E{1};
D0M=D{1};
B0M=B{1};
E0=E{2};
D0=D{2};
B0=B{2};
E0P=E{3};
D0P=D{3};
B0P=B{3};


%ALTERNATIVE LIQUIDATION ASSUMPTION [Needed for Panel B in TABLE 1]
%This uses parallel commands for different vales of q (the fraction that equity holders get in default)
%Note the base-line results correspond to q=0, and the renegotiation in debt corresponds to q=cost/2
[~,~,B00q] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost/2,0.4,0,0,omega,cost/2);
mlist = {1/30,1/10,1/5};
parfor k=1:length(mlist)
    [~,~,B{k}] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost/2,0.4,mlist{k},c/rf(jhalf),omega,cost/2);
end
B0Mq = B{1};
B0q = B{2};
B0Pq = B{3};


%CHANGING BORROWER CHARACTERISTICS [Needed for Table OA.1]
%This uses parallel commands for different vales of sig_A and mu_A
numlist = {0.15,0.15,0.15,0.2,0.2,0.2,0.25,0.25,0.25};
numlist2 = {0.015,0.02,0.025,0.015,0.02,0.025,0.015,0.02,0.025};
omegalist = {1.9,1.9,1.9,1.9,1.9,1.9,1.9,1.9,1.9};
parfor k=1:length(numlist)
   [E{k},D{k},B{k}] = TWOTREEY(Ny,Ns,ymin,ymax,numlist{k},sigB,rho,del,numlist2{k},muB,phi,cost,c,m,p,omegalist{k},q); 
end
BmuMM=B{1};
BmuM0=B{2};
BmuMP=B{3};
Bmu0M=B{4};
Bmu00=B{5};
Bmu0P=B{6};
BmuPM=B{7};
BmuP0=B{8};
BmuPP=B{9};


%CALCULATING DEFAULT PROBABILITY FUNCTIONS [Needed for Table 2 and Table OA.2, and Figure 5]
%This computes the probability of default over Tmax years for the stochastic boundary
Tmax = 10;
Ntprob = 200; %The number of time steps used in the numerical computation
[probP] = PROBDEF(B00,Ny,Ns,Ntprob,Tmax,ymin,ymax,sig,sigB,rho,mu,muB,omega,0); %Needs to use the same Ns as the boundary B00 was computed with
[probQ] = PROBDEF(B00,Ny,Ns,Ntprob,Tmax,ymin,ymax,sig,sigB,rho,mu,muB,omega,1); %Needs to use the same Ns as the boundary B00 was computed with


%SIMULATION CALCULATIONS [Needed for Table 2 and Table OA.2, and Figure OA.2, Figure OA.3 and Figure OA.4]
%This runs Nsim simulations over [0,Tmax] with Nt timesteps for our baseline model (m=0) it also computes the values corresponding to a static boundary set at b(s=0.5)
[xA,xB,sims,DefA,DefB,xAstat,xBstat,simsstat,DefAstat,DefBstat] = Simulation(B00,xAl,xAu,Tmax,Nt,Nsim,sig,sigB,rho,mu,muB,del,c);


%CALCULATING THE FIXED INTEREST COUNTERFACTUAL DEBT AND EQUITY VALUES [Needed for Figure OA.1]
[E00count,D00count,~] = Counterfactual(B00,Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost,c,m,p,omega,q,0);


%CALCULATING DEBT VALUES FOR SOVEREIGN DEBT SPILLOVER CASE STUDY [Needed for Table OA.10]
mlist = {1/7,1/15,1/7,1/7};
siglist = {0.2,0.2,0.2,0.24};
mulist = {0.02,0.02,0.025,0.02};
omegalist = {1.6,1.7,1.6,1.6};
parfor k=1:length(mlist)
   [~,D{k},~] = TWOTREEY(Ny,Ns,ymin,ymax,siglist{k},siglist{k},rho,del,mulist{k},mulist{k},phi,cost,c,mlist{k},c/rf(jhalf),omegalist{k},q);
end
D7=D{1};
D15=D{2};
D7mu=D{3};
D7sig=D{4};

%Save the precomputed model solutions to the project Data folder (Data/DataFile.mat).
%-v7.3 is required because the simulation arrays exceed the 2GB v7 limit.
save(datafile, ...
    'E00','D00','B00','BM0','BP0', ...
    'E00count','D00count', ...
    'Bcorm09','Bcorm08','Bcorm07','Bcorm06','Bcorm05','Bcorm04','Bcorm03','Bcorm02','Bcorm01', ...
    'Bcorp01','Bcorp02','Bcorp03','Bcorp04','Bcorp05','Bcorp06','Bcorp07','Bcorp08','Bcorp09', ...
    'E0M','D0M','B0M','E0','D0','B0','E0P','D0P','B0P', ...
    'B00q','B0Mq','B0q','B0Pq', ...
    'BmuMM','BmuM0','BmuMP','Bmu0M','Bmu00','Bmu0P','BmuPM','BmuP0','BmuPP', ...
    'probP','probQ', ...
    'xA','xB','sims','DefA','DefB','xAstat','xBstat','simsstat','DefAstat','DefBstat', ...
    'D7','D15','D7mu','D7sig', ...
    '-v7.3');

else

%Load the precomputed model solutions from the project Data folder
load(datafile);

end



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% THIS CODE SECTION USES THE RESULTS TO PLOT GRAPHS ETC %               
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%The model solutions are computed above when RECOMPUTE=true, or loaded from
%Data/DataFile.mat when RECOMPUTE=false (see the run options at the top of this file).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code to produce the asset pricing moments stated in calibrations sections 2.1 and 3.3 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This code snippet computes the asset pricing moments stated in Section 2.1 for perpetual debt (i.e., when m=0)
[Evol00] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,E00);                      %This computes the equity volatility
[CSA00,~] = CSpread(Ny,Ns,ymin,ymax,0.4,0,0,D00,1);                      %This computes the credit spread
[ERPA00,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00,1);                %This computes the equity risk premium
[Eunlev] = UnleveredEquity(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi); %This computes the unlevered equity value
[ERPAUnlev,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,Eunlev,1);          %This computes the unlevered equity risk premium
fprintf('Equity volatility (m=0): %f\n', Evol00(ibase,jhalf));
fprintf('Leverage (m=0): %f\n', D00(ibase,jhalf)./(E00(ibase,jhalf)+D00(ibase,jhalf)));
fprintf('Credit spread (m=0): %f\n', CSA00(jhalf));
fprintf('Levered equity risk premium for tree A (m=0): %f\n', ERPA00(jhalf));
fprintf('Unlevered equity risk premium for tree A (m=0): %f\n', ERPAUnlev(jhalf));

%The code snippet computes the asset pricing moments stated in Section 3.3 for 10-year maturity debt (i.e., when m=0.1)
[Evol0] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,E0);                                      %This computes the equity volatility
[CSA0,~] = CSpread(Ny,Ns,ymin,ymax,0.4,0.1,0.4/rf(jhalf),D0,1);                        %This computes the credit spread
[ERPA0,ERPB0] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E0,1);                            %This computes the equity risk premium
fprintf('Equity volatility (m=0.1): %f\n', Evol0(ibase,jhalf));                        
fprintf('Leverage (m=0.1): %f\n', D0(ibase,jhalf)./(E0(ibase,jhalf)+D0(ibase,jhalf))); 
fprintf('Credit spread (m=0.1): %f\n', CSA0(jhalf));
fprintf('Levered equity risk premium for tree A (m=0.1): %f\n', ERPA0(jhalf));



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Table 1:                            %
% 'Default risk correlation and rollover risk' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This computes the correlation between distance-to-defaults for different maturities and the baseline and debt renegotiation model
j02 = round(0.20/ds)+1; %This computes the value of j corresponding to s=0.20
j03 = round(0.30/ds)+1; %This computes the value of j corresponding to s=0.30
j04 = round(0.40/ds)+1; %This computes the value of j corresponding to s=0.40
%Parameters required for the numerical differentiation of the default boundary
jdelfit = 80;
jdel = 40;
order = 6;

%BASELINE model
[Corrcor00] = CorrEst(B00,Ns,0.2,0.8,jdelfit,jdel,order,0); %Perpetual (baseline)
[Corrcor0M] = CorrEst(B0M,Ns,0.2,0.8,jdelfit,jdel,order,0); %30-years (baseline)
[Corrcor0] = CorrEst(B0,Ns,0.2,0.8,jdelfit,jdel,order,0);   %10-years (baseline)
[Corrcor0P] = CorrEst(B0P,Ns,0.2,0.8,jdelfit,jdel,order,0); %5-years (baseline)
%Perpetual
[Corrcor00(jhalf),Corrcor00(j04),Corrcor00(j03),Corrcor00(j02)] %which equals 1-2s = 0,0.2,0.4, and 0.6, respectively
%30-years
[Corrcor0M(jhalf),Corrcor0M(j04),Corrcor0M(j03),Corrcor0M(j02)]
%10-years
[Corrcor0(jhalf),Corrcor0(j04),Corrcor0(j03),Corrcor0(j02)]
%5-years
[Corrcor0P(jhalf),Corrcor0P(j04),Corrcor0P(j03),Corrcor0P(j02)]

%DEBT RENEGOTIATION model
[Corrcor00q] = CorrEst(B00q,Ns,0.2,0.8,jdelfit,jdel,order,0); %Perpetual (baseline)
[Corrcor0Mq] = CorrEst(B0Mq,Ns,0.2,0.8,jdelfit,jdel,order,0); %30-years (baseline)
[Corrcor0q] = CorrEst(B0q,Ns,0.2,0.8,jdelfit,jdel,order,0);   %10-years (baseline)
[Corrcor0Pq] = CorrEst(B0Pq,Ns,0.2,0.8,jdelfit,jdel,order,0); %5-years (baseline)
%Perpetual
[Corrcor00q(jhalf),Corrcor00q(j04),Corrcor00q(j03),Corrcor00q(j02)] %which equals 1-2s = 0,0.2,0.4, and 0.6, respectively
%30-years
[Corrcor0Mq(jhalf),Corrcor0Mq(j04),Corrcor0Mq(j03),Corrcor0Mq(j02)]
%10-years
[Corrcor0q(jhalf),Corrcor0q(j04),Corrcor0q(j03),Corrcor0q(j02)]
%5-years
[Corrcor0Pq(jhalf),Corrcor0Pq(j04),Corrcor0Pq(j03),Corrcor0Pq(j02)]

%--- Export Table 1 to output/tables/Table1_corr_by_maturity.tex (caption + numbers) ---
% Columns are |1-2s| = 0, 0.2, 0.4, 0.6 (s = 0.5, 0.4, 0.3, 0.2); values in percent.
t1lab  = {'Perpetual','30 year','10 year','5 year'};
t1base = 100*[Corrcor00(jhalf) Corrcor00(j04) Corrcor00(j03) Corrcor00(j02);
              Corrcor0M(jhalf) Corrcor0M(j04) Corrcor0M(j03) Corrcor0M(j02);
              Corrcor0(jhalf)  Corrcor0(j04)  Corrcor0(j03)  Corrcor0(j02);
              Corrcor0P(jhalf) Corrcor0P(j04) Corrcor0P(j03) Corrcor0P(j02)];
t1ren  = 100*[Corrcor00q(jhalf) Corrcor00q(j04) Corrcor00q(j03) Corrcor00q(j02);
              Corrcor0Mq(jhalf) Corrcor0Mq(j04) Corrcor0Mq(j03) Corrcor0Mq(j02);
              Corrcor0q(jhalf)  Corrcor0q(j04)  Corrcor0q(j03)  Corrcor0q(j02);
              Corrcor0Pq(jhalf) Corrcor0Pq(j04) Corrcor0Pq(j03) Corrcor0Pq(j02)];

fid = fopen(fullfile(tabledir,'Table1_corr_by_maturity.tex'),'w');
hdr = [ ...
"\begin{table}[h]"
"\small"
"\centering"
"\caption{Default risk correlation and rollover risk}"
"\label{tab:table_corr_by_maturity}"
"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc}"
"\toprule"
" & \multicolumn{4}{c}{\textbf{Output share distribution} ($|1-2s_t|$)} \\"
"\cmidrule{2-5}"
"  & 0 & 0.2 & 0.4 & 0.6  \\"
"  & Identical & &  & Very different \\"
"    & trees & &  & trees \\"
"    \addlinespace"
" & (1) & (2) & (3) & (4)"
"\\"
"\multicolumn{5}{l}{\textbf{Panel A: Baseline model}} \\"
"\midrule"
"\textbf{Debt maturity} ($1/m_i$) & & & & \\"
];
fprintf(fid,'%s\n',hdr);
for i=1:4
    fprintf(fid,'%s\n',sprintf('\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\', ...
        t1lab{i}, t1base(i,1), t1base(i,2), t1base(i,3), t1base(i,4)));
end
mid = [ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel B: With renegotiation in default}} \\"
"\midrule"
"\textbf{Debt maturity} ($1/m_i$) & & & & \\"
];
fprintf(fid,'%s\n',mid);
for i=1:4
    fprintf(fid,'%s\n',sprintf('\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\', ...
        t1lab{i}, t1ren(i,1), t1ren(i,2), t1ren(i,3), t1ren(i,4)));
end
ftr = [ ...
"\bottomrule"
"\end{tabular*}"
"\end{table}"
];
fprintf(fid,'%s\n',ftr);
fclose(fid);
fprintf('Wrote %s\n', fullfile(tabledir,'Table1_corr_by_maturity.tex'));



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Table 2:                                                        %           
% 'Co-movement in default risk and equity moments for simulated economies' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%COMPUTATIONS FOR PANEL A
%This uses the simulation results and computes the default rates, default times, and joint probability rates
[DefRateA,DefRateB,JDefRate,DefRateAstat,DefRateBstat,JDefRatestat,DefRateRatio,DefTimeA,DefTimeB,DefTimeAstat,DefTimeBstat] = DefaultTimes(t,DefA,DefB,DefAstat,DefBstat,Nsim);
%The 1-, 5- and 10-year default rates for the baseline model are as follows:
[DefRateA(1),DefRateA(5),DefRateA(10)]

%COMPUTATIONS FOR PANEL B
%This computes the statistics of the distribution for the state variables (s, xA and xB) accross simulations
for j=1:Nsim
    mean_s(j)=mean(sims(:,j));
    median_s(j)=prctile(sims(:,j),50);
    fifth_s(j)=prctile(sims(:,j),5);
    nintyfifth_s(j)=prctile(sims(:,j),95);
    mean_xa(j)=mean(xA(:,j));
    median_xa(j)=prctile(xA(:,j),50);
    fifth_xa(j)=prctile(xA(:,j),5);
    nintyfifth_xa(j)=prctile(xA(:,j),95);
    mean_xb(j)=mean(xB(:,j));
    median_xb(j)=prctile(xB(:,j),50);
    fifth_xb(j)=prctile(xB(:,j),5);
    nintyfifth_xb(j)=prctile(xB(:,j),95);
end
%This outputs the results from Panel B of the table (i.e., the mean of the mean, median, 5th and 95th percentile over all simulations
[mean(mean_s),mean(median_s),mean(fifth_s),mean(nintyfifth_s)]
[mean(mean_xa),mean(median_xa),mean(fifth_xa),mean(nintyfifth_xa)]
[mean(mean_xb),mean(median_xb),mean(fifth_xb),mean(nintyfifth_xb)]

%COMPUTATIONS FOR PANEL C
%--Distance-to-Default--
%This computes an interpolated function for distance to default
BoundInterp = griddedInterpolant(s,B00,'makima','none');
%This computes simulated correlation between the distance-to-defaults
[CorDD,~,~] = SimulatedCorrelationDD(xA,xB,sims,DefA,DefB,Nt,Nsim,sig,sigB,BoundInterp);

%--10-year Default Probability--
%This computes an interpolated function for default probability
DP10 = probP; %This sets the previously computed probability to a new variable. If it was not computed for 10-years previously then rerun the following code:
%[DP10] = PROBDEF(B00,Ny,Ns,Ntprob,10,ymin,ymax,sig,sigB,rho,mu,muB,omega,0); %Last arguement 0 for probability under P and 1 for probability under Q
DP10Interp = griddedInterpolant(Y,S,DP10,'makima','none');
%This computes the simulated correlation between default probability
[CorDP10,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,DP10Interp);

%--Leverage--
%This computes an interpolated function for leverage
for i=1:Ny
    for j=1:Ns
        Lev(i,j) = D00(i,j)./(E00(i,j)+D00(i,j));
    end
end
LevInterp = griddedInterpolant(Y,S,Lev,'makima','none');
%This computes the simulated correlation between leverage
[CorLev,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,LevInterp);

%--Credit Spreads--
%This computes an interpolated function for the credit spreads (using the debt value D00)
D00Interp = griddedInterpolant(Y,S,D00,'makima','none');
for i=1:Ny
    for j=1:Ns
        CS(i,j) = (c+m*p)*((1/D00(i,j))-(1/D00(Ny,j)))*10000;
    end
end
CSInterp = griddedInterpolant(Y,S,CS,'makima','none');
%This computes the simulated correlation between credit spreads
[CorCS,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,CSInterp);

%This resports the mean, median, 5th and 95th percentile for all four quantitites (Panel C)
[mean(CorDD),prctile(CorDD,50),prctile(CorDD,5),prctile(CorDD,95)]         %Distance-to-default
[mean(CorDP10),prctile(CorDP10,50),prctile(CorDP10,5),prctile(CorDP10,95)] %Default probability
[mean(CorLev),prctile(CorLev,50),prctile(CorLev,5),prctile(CorLev,95)]     %Leverage
[mean(CorCS),prctile(CorCS,50),prctile(CorCS,5),prctile(CorCS,95)]         %Credit spreads

%COMPUTATIONS FOR PANEL D
%--Equity Exces Return--
%This computes an interpolated function for the equity
E00Interp = griddedInterpolant(Y,S,E00,'makima','none');
%This computes the simulated correlation between equity excess returns
[CorEER,~,~] = SimulatedCorrelationEExRet(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,E00Interp,rf,phi,c,Tmax);

%--Equity Return Volatility--
%This computes an interpolated function for equity volatility
[Evol] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,E00);
EvolInterp = griddedInterpolant(Y,S,Evol,'makima','none');
%This computes the simulated correlation between equity volatilty
[CorEvol,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,EvolInterp);

%--Equity Risk Premium--
%This computes an interpolated function for equity risk premium
[ERP] = ERPcalc(Ny,Ns,ymin,ymax,sig,sigB,rho,E00);
ERPInterp = griddedInterpolant(Y,S,ERP,'makima','none');
%This computes the simulated correlation between equity risk premium
[CorERP,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,ERPInterp);

%This resports the mean, median, 5th and 95th percentile for all three quantitites (Panel D)
[mean(CorEER),prctile(CorEER,50),prctile(CorEER,5),prctile(CorEER,95)]     %Equity excess return
[mean(CorEvol),prctile(CorEvol,50),prctile(CorEvol,5),prctile(CorEvol,95)] %Equity return volatility
[mean(CorERP),prctile(CorERP,50),prctile(CorERP,5),prctile(CorERP,95)]     %Equity risk premium

%--- Export Table 2 to output/tables/Table2_histograms.tex (caption + numbers) ---
% Panel A in percent (baseline computed, empirical from S&P 2021); Panel B raw
% decimals; Panels C/D correlations in percent. Mean / Median / 5th / 95th.
fid = fopen(fullfile(tabledir,'Table2_histograms.tex'),'w');
fprintf(fid,'%s\n',[ ...
"\begin{table}[h]"
"\small"
"\centering"
"\caption{Co-movement in default risk and equity moments from simulated economies}"
"\label{tab:table_simulation}"
"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc}"
"\toprule"
"& \multicolumn{2}{c}{\textbf{Baseline model}} & \multicolumn{2}{c}{\textbf{Empirical data}} \\"
"\cmidrule{2-5}"
"& \multicolumn{2}{c}{(1)} & \multicolumn{2}{c}{(2)} \\"
"\multicolumn{5}{l}{\textbf{Panel A: Default probabilities}} \\"
"\midrule"
]);
fprintf(fid,'\\multicolumn{1}{l}{1-year default rate} & \\multicolumn{2}{c}{%.2f\\%%} & \\multicolumn{2}{c}{1.86\\%%} \\\\\n', 100*DefRateA(1));
fprintf(fid,'\\multicolumn{1}{l}{5-year default rate} & \\multicolumn{2}{c}{%.2f\\%%} & \\multicolumn{2}{c}{7.72\\%%} \\\\\n', 100*DefRateA(5));
fprintf(fid,'\\multicolumn{1}{l}{10-year default rate} & \\multicolumn{2}{c}{%.2f\\%%} & \\multicolumn{2}{c}{11.37\\%%} \\\\\n', 100*DefRateA(10));
fprintf(fid,'%s\n',[ ...
"\\"
"\midrule"
"& \textbf{Mean} & \textbf{Median} & \textbf{5th} & \textbf{95th} \\"
"\cmidrule{2-5}"
"& (1) & (2) & (3) & (4) \\"
"\multicolumn{5}{l}{\textbf{Panel B: State variables }} \\"
"\midrule"
]);
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.4f & %.4f & %.4f & %.4f \\\\\n', "Tree A's output level ($X^A_t)$", mean(mean_xa),mean(median_xa),mean(fifth_xa),mean(nintyfifth_xa));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.4f & %.4f & %.4f & %.4f \\\\\n', "Tree B's output level ($X^B_t)$", mean(mean_xb),mean(median_xb),mean(fifth_xb),mean(nintyfifth_xb));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.4f & %.4f & %.4f & %.4f \\\\\n', "Output share ($s_t$)", mean(mean_s),mean(median_s),mean(fifth_s),mean(nintyfifth_s));
fprintf(fid,'%s\n',[ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel C: Correlations in default risk across trees }} \\"
"\midrule"
]);
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Distance-to-default", 100*mean(CorDD),100*prctile(CorDD,50),100*prctile(CorDD,5),100*prctile(CorDD,95));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "10-year default probability", 100*mean(CorDP10),100*prctile(CorDP10,50),100*prctile(CorDP10,5),100*prctile(CorDP10,95));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Leverage", 100*mean(CorLev),100*prctile(CorLev,50),100*prctile(CorLev,5),100*prctile(CorLev,95));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Credit spread", 100*mean(CorCS),100*prctile(CorCS,50),100*prctile(CorCS,5),100*prctile(CorCS,95));
fprintf(fid,'%s\n',[ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel D: Correlations in equity moments across trees  }} \\"
"\midrule"
]);
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Equity excess return", 100*mean(CorEER),100*prctile(CorEER,50),100*prctile(CorEER,5),100*prctile(CorEER,95));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Equity return volatility", 100*mean(CorEvol),100*prctile(CorEvol,50),100*prctile(CorEvol,5),100*prctile(CorEvol,95));
fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', "Equity risk premium", 100*mean(CorERP),100*prctile(CorERP,50),100*prctile(CorERP,5),100*prctile(CorERP,95));
fprintf(fid,'%s\n',[ ...
"\bottomrule"
"\end{tabular*}"
"\end{table}"
]);
fclose(fid);
fprintf('Wrote %s\n', fullfile(tabledir,'Table2_histograms.tex'));



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure 2:                     %
% 'Equilibrium asset pricing quantities' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%The three lines below compute the levered equity risk premium (for X=1), the unlevered equit value, and the unlevered equity risk premium (for X=1)
[ERPA,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00,1);
[Eunlev] = UnleveredEquity(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi);
[ERPAUnlev,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,Eunlev,1);

%This plots the 3x2 figure
Fig2=figure;
%FIG-2a:
subplot(3,2,1)
plot(s(4:Ns),ERPA(4:Ns),'-b','LineWidth',2)
hold on
plot(s(4:Ns),ERPAUnlev(4:Ns),':r','LineWidth',2)
xlim([0 1])
ylabel('Equity risk premium')
title('(A) Risk Premium')
legend({'Levered','Unlevered'},'Location','northwest')
legend('boxoff')

%FIG-2b:
subplot(3,2,2)
plot(s(1:Ns),rf(1:Ns),'-b','LineWidth',2)
xlim([0 1])
ylim([0.03 0.07])
ylabel('Risk-free rate')
title('(B) Risk-free rate')

%FIG-2c:
subplot(3,2,3)
plot(s(2:Ns),E00(ibase,2:Ns),'-b','LineWidth',2)
hold on
plot(s(2:Ns),Eunlev(ibase,2:Ns),':r','LineWidth',2)
xlim([0 1])
ylabel('Equity value')
title('(C) Equity valuation of tree A')
legend({'Levered','Unlevered'},'Location','northeast')
legend('boxoff')

%FIG-2d:
subplot(3,2,4)
plot(s,D00(ibase,:),'-b','LineWidth',2)
xlim([0 1])
ylim([5 10])
ylabel('Debt value')
title('(D) Debt valuation of tree A')

%FIG-2e:
subplot(3,2,5)
plot(s(2:Ns),Eunlev(ibase,2:Ns)/(1-phi),'-b','LineWidth',2)
xlim([0 1])
ylabel('Total asset value')
xlabel('Share of tree A')
title('(E) Total asset valuation of tree A')

%FIG-2f:
subplot(3,2,6)
plot(s(2:Ns),D00(ibase,2:Ns)./(E00(ibase,2:Ns)+D00(ibase,2:Ns)),'-b','LineWidth',2)
xlim([0 1])
ylim([0.3 0.5])
ylabel('Debt/(Equity+Debt)')
xlabel('Share of tree A')
title('(F) Leverage ratio of tree A')

set(Fig2,'Units','inches')
set(Fig2,'Position',[25 1 8 9.66])
theme(Fig2,'light')
exportgraphics(Fig2,fullfile(figdir,'Fig2.eps'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure 3:                             %
% 'Optimal default policy in a two-tree economy' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%Everything should already be calculated that is needed. The following just plots the three subplot figure
Fig3=figure;
%FIG-3a: NOTE: We need to add annotation for 'distance-to-default' manually
subplot(2,2,1)
plot(s,B00,'-b','LineWidth',2)
xlim([0 1])
ylim([0 0.4])
ylabel('Default boundary')
xlabel('Share of tree A')
title('(A) Default boundary')

%FIG-3b:
subplot(2,2,2)
plot(s,B00,'-b','LineWidth',2)
hold on
plot(s,BP0,':r','LineWidth',2)
plot(s,BM0,'-.k','LineWidth',2)
plot(0,B00(1),'ob')
plot(0,BP0(1),'or')
plot(0,BM0(1),'ok')
plot(1,B00(Ns),'ob')
plot(1,BP0(Ns),'or')
plot(1,BM0(Ns),'ok')
xlim([0 1])
ylim([0 0.4])
ylabel('Default boundary')
xlabel('Share of tree A')
legend({'Baseline','High leverage','Low leverage'},'Location','southeast')
legend('boxoff')
title('(B) Effect of leverage')

%FIG-3c:
subplot(2,2,3.5)
plot(s,B00,'-b','LineWidth',2)
hold on
plot(s,B0M,'--','LineWidth',2,'color',[0 0.5 0])
plot(s,B0,'-.k','LineWidth',2)
plot(s,B0P,':r','LineWidth',2)
plot(0,B00(1),'ob')
plot(0,B0M(1),'o','color',[0 0.5 0])
plot(0,B0(1),'ok')
plot(0,B0P(1),'or')
plot(1,B00(Ns),'ob')
plot(1,B0M(Ns),'o','color',[0 0.5 0])
plot(1,B0(Ns),'ok')
plot(1,B0P(Ns),'or')
xlim([0 1])
ylim([0 0.55])
ylabel('Default boundary')
xlabel('Share of tree A')
legend({'Baseline (perpetual)','Long maturity (30-year)','Medium maturity (10-year)','Short maturity (5-year)'},'Location','southeast')
legend('boxoff')
title('(C) Effect of maturity')

set(Fig3,'Units','inches')
set(Fig3,'Position',[25 2 8 6.33])
theme(Fig3,'light')
exportgraphics(Fig3,fullfile(figdir,'Fig3.eps'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure 4:                                                    %
% 'Excess default risk correlation by level of fundamental correlation' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This computes the correlation between distance-to-defaults using the function 'CorrEst', using the computed default boundary 
jdelfit = 80;
jdel = 40;
order = 6;
jmin = round(0.2/ds)+1; 
jmax = round(0.8/ds)+1; 
[Corrm09] = CorrEst(Bcorm09,Ns,0.2,0.8,jdelfit,jdel,order,-0.9);
[Corrm08] = CorrEst(Bcorm08,Ns,0.2,0.8,jdelfit,jdel,order,-0.8);
[Corrm07] = CorrEst(Bcorm07,Ns,0.2,0.8,jdelfit,jdel,order,-0.7);
[Corrm06] = CorrEst(Bcorm06,Ns,0.2,0.8,jdelfit,jdel,order,-0.6);
[Corrm05] = CorrEst(Bcorm05,Ns,0.2,0.8,jdelfit,jdel,order,-0.5);
[Corrm04] = CorrEst(Bcorm04,Ns,0.2,0.8,jdelfit,jdel,order,-0.4);
[Corrm03] = CorrEst(Bcorm03,Ns,0.2,0.8,jdelfit,jdel,order,-0.3);
[Corrm02] = CorrEst(Bcorm02,Ns,0.2,0.8,jdelfit,jdel,order,-0.2);
[Corrm01] = CorrEst(Bcorm01,Ns,0.2,0.8,jdelfit,jdel,order,-0.1);
[Corr00] = CorrEst(B00,Ns,0.2,0.8,jdelfit,jdel,order,0);
[Corrp01] = CorrEst(Bcorp01,Ns,0.2,0.8,jdelfit,jdel,order,0.1);
[Corrp02] = CorrEst(Bcorp02,Ns,0.2,0.8,jdelfit,jdel,order,0.2);
[Corrp03] = CorrEst(Bcorp03,Ns,0.2,0.8,jdelfit,jdel,order,0.3);
[Corrp04] = CorrEst(Bcorp04,Ns,0.2,0.8,jdelfit,jdel,order,0.4);
[Corrp05] = CorrEst(Bcorp05,Ns,0.2,0.8,jdelfit,jdel,order,0.5);
[Corrp06] = CorrEst(Bcorp06,Ns,0.2,0.8,jdelfit,jdel,order,0.6);
[Corrp07] = CorrEst(Bcorp07,Ns,0.2,0.8,jdelfit,jdel,order,0.7);
[Corrp08] = CorrEst(Bcorp08,Ns,0.2,0.8,jdelfit,jdel,order,0.8);
[Corrp09] = CorrEst(Bcorp09,Ns,0.2,0.8,jdelfit,jdel,order,0.9);

%This plots the correlation between distance-to-defaults as rho is changed for various values of share (s)
%Defining the values of s to compute at (0.5, 0.2, and 0.35)
jhalf = round(0.5/ds)+1; 
j020 = round(0.20/ds)+1;
j035 = round(0.35/ds)+1;
%Creating the list of rho and excess correlation values for the plot
rhoplot=[-1,-0.9,-0.8,-0.7,-0.6,-0.5,-0.4,-0.3,-0.2,-0.1,0,0.1,0.2,0.3,0.4,0.5,0.6,0.7,0.8,0.9,1];
excesscorrplot=[0,Corrm09(jhalf)+0.9,Corrm08(jhalf)+0.8,Corrm07(jhalf)+0.7,Corrm06(jhalf)+0.6,Corrm05(jhalf)+0.5,Corrm04(jhalf)+0.4,Corrm03(jhalf)+0.3,Corrm02(jhalf)+0.2,Corrm01(jhalf)+0.1,Corr00(jhalf),Corrp01(jhalf)-0.1,Corrp02(jhalf)-0.2,Corrp03(jhalf)-0.3,Corrp04(jhalf)-0.4,Corrp05(jhalf)-0.5,Corrp06(jhalf)-0.6,Corrp07(jhalf)-0.7,Corrp08(jhalf)-0.8,Corrp09(jhalf)-0.9,0];
excesscorrplot25=[0,Corrm09(j020)+0.9,Corrm08(j020)+0.8,Corrm07(j020)+0.7,Corrm06(j020)+0.6,Corrm05(j020)+0.5,Corrm04(j020)+0.4,Corrm03(j020)+0.3,Corrm02(j020)+0.2,Corrm01(j020)+0.1,Corr00(j020),Corrp01(j020)-0.1,Corrp02(j020)-0.2,Corrp03(j020)-0.3,Corrp04(j020)-0.4,Corrp05(j020)-0.5,Corrp06(j020)-0.6,Corrp07(j020)-0.7,Corrp08(j020)-0.8,Corrp09(j020)-0.9,0];
excesscorrplot35=[0,Corrm09(j035)+0.9,Corrm08(j035)+0.8,Corrm07(j035)+0.7,Corrm06(j035)+0.6,Corrm05(j035)+0.5,Corrm04(j035)+0.4,Corrm03(j035)+0.3,Corrm02(j035)+0.2,Corrm01(j035)+0.1,Corr00(j035),Corrp01(j035)-0.1,Corrp02(j035)-0.2,Corrp03(j035)-0.3,Corrp04(j035)-0.4,Corrp05(j035)-0.5,Corrp06(j035)-0.6,Corrp07(j035)-0.7,Corrp08(j035)-0.8,Corrp09(j035)-0.9,0];
oneval=[1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1]; %Needed for the area plot below

Fig4=figure;
plot(rhoplot,excesscorrplot,'-k','LineWidth',2)
hold on
plot(rhoplot,excesscorrplot25,'--r','LineWidth',2)
plot(rhoplot,excesscorrplot35,'-.b','LineWidth',2)
area(rhoplot(rhoplot<=0),oneval(rhoplot<=0),'FaceColor',"#4DBEEE",'EdgeColor','none','FaceAlpha',0.1)
area(rhoplot(rhoplot>=0),oneval(rhoplot>=0),'FaceColor',"#D95319",'EdgeColor','none','FaceAlpha',0.1)
ylim([0 0.125])
ylabel('Excess default risk correlation')
xlabel('Fundamental correlation \rho')
legend({'Share = 0.50 vs 0.50','Share = 0.20 vs 0.80','Share = 0.35 vs 0.65'},'Position',[0.54,0.73,0.35,0.2])
legend('boxoff')

set(Fig4,'Units','inches')
set(Fig4,'Position',[25 2 5 3.67])
txt1 = {'\rho < 0:','Case of imperfectly','substitutable goods'};
txt2 = {'\rho > 0:','Case of predatory','competition'};
text(-0.45,0.02,txt1,'HorizontalAlignment','center')
text(0.33,0.02,txt2,'HorizontalAlignment','center')
theme(Fig4,'light')
exportgraphics(Fig4,fullfile(figdir,'Fig4.pdf'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure 5:                                                       %
% 'Co-movement in default probabilities and co-movement in credit spreads' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This creates an interpolated function from the precomputed default probability functions probP and probQ
PInterp = griddedInterpolant(Y,S,probP,'makima','none');
QInterp = griddedInterpolant(Y,S,probQ,'makima','none');

%This computes the P and Q of A and B (at X=1) as s varies
for j=1:Ns
    PA(j)=PInterp(log(1),s(j));
    PB(j)=PInterp(log(1*(1-s(j))/s(j)),1-s(j));
    QA(j)=QInterp(log(1),s(j));
    QB(j)=QInterp(log(1*(1-s(j))/s(j)),1-s(j));
end

%This computes the credit spreads for A and B for the four maturities 
[CSA00,CSB00] = CSpread(Ny,Ns,ymin,ymax,0.4,0,0,D00,1);            %Perpetual
[CSA0,CSB0] = CSpread(Ny,Ns,ymin,ymax,c,1/10,c/rf(jhalf),D0,1);    %10-years
[CSA0M,CSB0M] = CSpread(Ny,Ns,ymin,ymax,c,1/30,c/rf(jhalf),D0M,1); %30-years
[CSA0P,CSB0P] = CSpread(Ny,Ns,ymin,ymax,c,1/5,c/rf(jhalf),D0P,1);  %5-years

%This plots the 2x2 figure
Fig5=figure;
subplot(2,2,1)
plot(s,QA,'-b','LineWidth',2)
hold on
plot(s,PA,':r','LineWidth',2)
patch([s fliplr(s)],[QA fliplr(PA)],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.06])
ylabel('Default probability')
title('(A) Default probabilities for tree A')
leg = legend({'$\mathcal{Q}$','$\mathcal{P}$','\textrm{Default risk premium}'},'Location','northwest');
set(leg,'Interpreter','latex');
legend('boxoff')

subplot(2,2,2)
plot(s,QB,'-b','LineWidth',2)
hold on
plot(s,PB,':r','LineWidth',2)
vB = ~isnan(QB) & ~isnan(PB);   % drop NaNs (PB/QB undefined where log((1-s)/s) leaves the grid) so the fill renders
patch([s(vB) fliplr(s(vB))],[QB(vB) fliplr(PB(vB))],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.9])
title('(B) Default probabilities for tree B')
leg = legend({'$\mathcal{Q}$','$\mathcal{P}$','\textrm{Default risk premium}'},'Location','northwest');
set(leg,'Interpreter','latex');
legend('boxoff')

%FIG-5c:
subplot(2,2,3)
plot(s,CSA00,'-b','LineWidth',2)
hold on
plot(s,CSA0M,'--','LineWidth',2,'color',[0 0.5 0])
plot(s,CSA0,'-.k','LineWidth',2)
plot(s,CSA0P,':r','LineWidth',2)
xlim([0.2 0.8])
ylim([0 280])
ylabel('Credit spread (bps)')
xlabel('Share of tree A')
title('(C) CS of tree A (by maturity)')
legend({'Baseline (perpetual)','Long maturity (30-year)','Medium maturity (10-year)','Short maturity (5-year)'},'Location','northwest')
legend('boxoff')

%FIG-5d:
subplot(2,2,4)
plot(s,CSB00,'-b','LineWidth',2)
hold on
plot(s,CSB0M,'--','LineWidth',2,'color',[0 0.5 0])
plot(s,CSB0,'-.k','LineWidth',2)
plot(s,CSB0P,':r','LineWidth',2)
xlim([0.2 0.8])
ylim([0 280])
xlabel('Share of tree A')
title('(D) CS of tree B (by maturity)')

set(Fig5,'Units','inches')
set(Fig5,'Position',[25 2 8 6.33])
theme(Fig5,'light')
exportgraphics(Fig5,fullfile(figdir,'Fig5.pdf'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure 6:                                                        %
% 'Co-movement in equity volatility and co-movement in equity risk premium' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This computes the equity volatility (for X=1) for the baseline model
[EvolA00,EvolB00] = EqVolPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00,1);

%This computes the equity function for c=0 (i.e., unlevered) 
eta=sqrt(sig*sig+sigB*sigB-2*rho*sig*sigB);
nu=muB-mu-0.5*sigB*sigB+0.5*sig*sig;
psi=sqrt(nu*nu+2*del*eta*eta);
thet=(nu+psi)/(eta*eta);
gamm=(nu-psi)/(eta*eta);
[vzero] = vcoch(Ns,del,gamm,nu,eta,thet,psi);
for j=1:Ns
    for i=1:Ny
        Ezero(i,j) = (1-phi)*exp(y(i))*vzero(j); 
    end
end
[EvolAzero,EvolBzero] = EqVolPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,Ezero,1);

%The below should have already been computed for Figure 2, but if not reexecute the three lines below before plotting (they computes the equity risk premiums for baseline and unlevered)
[ERPA,ERPB] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00,1);
[Eunlev] = UnleveredEquity(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi); %This defines the unlevered asset value
[ERPAUnlev,ERPBUnlev] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,Eunlev,1); %This computes the equity risk premium

%This plots the 2x2 figure
z=10; %The lowest value of s plotted
Fig6=figure;
%FIG-6a:
subplot(2,2,1)
plot(s(z:Ns),EvolA00(z:Ns),'-b','LineWidth',2)
hold on
plot(s(z:Ns),EvolAzero(z:Ns),':r','LineWidth',2)
patch([s(z:Ns) fliplr(s(z:Ns))], [EvolA00(z:Ns) fliplr(EvolAzero(z:Ns))],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.6])
ylabel('Equity volatility')
title('(A) Levered volatility of tree A')
legend({'Baseline (levered)','Unlevered','Leverage effect'},'Location','northwest')
legend('boxoff')

%FIG-6b:
subplot(2,2,2)
plot(s(z:Ns),EvolB00(z:Ns),'-b','LineWidth',2)
hold on
plot(s(z:Ns),EvolBzero(z:Ns),':r','LineWidth',2)
Nsmaxplot=floor(0.8*Ns)+2;
z2=floor(0.2*Ns)-2;
patch([s(z2:Nsmaxplot) fliplr(s(z2:Nsmaxplot))], [EvolB00(z2:Nsmaxplot) fliplr(EvolBzero(z2:Nsmaxplot))],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.6])
title('(B) Levered volatility of tree B')

%FIG-6c:
subplot(2,2,3)
plot(s(2:Ns),ERPA(2:Ns),'-b','LineWidth',2)
hold on
plot(s(2:Ns),ERPAUnlev(2:Ns),':r','LineWidth',2)
patch([s(2:Ns) fliplr(s(2:Ns))], [ERPA(2:Ns) fliplr(ERPAUnlev(2:Ns))],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.07])
xlabel('Share of tree A')
ylabel('Equity risk premium')
title('(C) Levered ERP of tree A')

%FIG-6d:
subplot(2,2,4)
plot(s(2:Ns),ERPB(2:Ns),'-b','LineWidth',2)
hold on
plot(s(2:Ns),ERPBUnlev(2:Ns),':r','LineWidth',2)
Nsmaxplot=floor(0.8*Ns)+2;
Nsminplot=floor(0.2*Ns)-2;
patch([s(Nsminplot:Nsmaxplot) fliplr(s(Nsminplot:Nsmaxplot))], [ERPB(Nsminplot:Nsmaxplot) fliplr(ERPBUnlev(Nsminplot:Nsmaxplot))],'k','EdgeColor','none','FaceAlpha',0.1)
xlim([0.2 0.8])
ylim([0 0.07])
xlabel('Share of tree A')
title('(D) Levered ERP of tree B')

set(Fig6,'Units','inches')
set(Fig6,'Position',[25 2 8 6.33])
theme(Fig6,'light')
exportgraphics(Fig6,fullfile(figdir,'Fig6.pdf'),'BackgroundColor','none') %We need a pdf since the shading works best with this (rather than .eps)



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Results for the Internet Appendix %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Table OA.4:                                   %
% 'Default risk correlation by borrower characteristics' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This computes the correlation between distance-to-default values for the different borrower characteristics computed earlier (varying muA and sigA)
jdelfit = 80; %Varying this parameter changes the range over which the polynomial is fit
jdel = 40;
order = 6;
jmin = round(0.2/ds)+1;
jmax = round(0.8/ds)+1;
[CorrmuMM] = CorrEst(BmuMM,Ns,0.2,0.8,jdelfit,jdel,order,0);
[CorrmuM0] = CorrEst(BmuM0,Ns,0.2,0.8,jdelfit,jdel,order,0);
[CorrmuMP] = CorrEst(BmuMP,Ns,0.2,0.8,jdelfit,jdel,order,0);
[Corrmu0M] = CorrEst(Bmu0M,Ns,0.2,0.8,jdelfit,jdel,order,0);
[Corrmu00] = CorrEst(Bmu00,Ns,0.2,0.8,jdelfit,jdel,order,0);
[Corrmu0P] = CorrEst(Bmu0P,Ns,0.2,0.8,jdelfit,jdel,order,0);
[CorrmuPM] = CorrEst(BmuPM,Ns,0.2,0.8,jdelfit,jdel,order,0);
[CorrmuP0] = CorrEst(BmuP0,Ns,0.2,0.8,jdelfit,jdel,order,0);
[CorrmuPP] = CorrEst(BmuPP,Ns,0.2,0.8,jdelfit,jdel,order,0);

%This outputs the 9 values in the table (evaluated at s=0.5)
[CorrmuMM(jhalf) CorrmuM0(jhalf) CorrmuMP(jhalf);
 Corrmu0M(jhalf) Corrmu00(jhalf) Corrmu0P(jhalf);
 CorrmuPM(jhalf) CorrmuP0(jhalf) CorrmuPP(jhalf)]

%--- Export Table OA.1 to output/tables/TableOA1_by_characteristics.tex (caption + numbers) ---
% Rows = output volatility sigma_A (15/20/25%), cols = expected growth mu_A (1.5/2.0/2.5%); percent.
oa1 = 100*[CorrmuMM(jhalf) CorrmuM0(jhalf) CorrmuMP(jhalf);
           Corrmu0M(jhalf) Corrmu00(jhalf) Corrmu0P(jhalf);
           CorrmuPM(jhalf) CorrmuP0(jhalf) CorrmuPP(jhalf)];
oa1lab = {'15\%','20\%','25\%'};
fid = fopen(fullfile(tabledir,'TableOA1_by_characteristics.tex'),'w');
fprintf(fid,'%s\n',[ ...
"\begin{table}[h]"
"\small"
"\centering"
"\caption{Default risk correlation by borrower characteristics}"
"\label{tab:table_corr_by_characteristics}"
"\begin{tabular*}{0.8\textwidth}{@{\extracolsep{\fill}}lccc}"
"\toprule"
" & \multicolumn{3}{c}{\textbf{Expected output growth} ($\mu_A$)} \\"
"\cmidrule{2-4}"
" & 1.5\% & 2.0\% & 2.5\% \\"
" \addlinespace"
" & (1) & (2) & (3) \\"
"\midrule"
"\textbf{Output volatility} ($\sigma_A$) & & & \\"
]);
for i=1:3
    fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', oa1lab{i}, oa1(i,1), oa1(i,2), oa1(i,3));
end
fprintf(fid,'%s\n',[ ...
"\bottomrule"
"\end{tabular*}"
"\end{table}"
]);
fclose(fid);
fprintf('Wrote %s\n', fullfile(tabledir,'TableOA1_by_characteristics.tex'));



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Table OA.2:                                                                          %           
% 'Co-movement in default risk and equity moments for simulated economies - excluding defaults' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%This removes all the default simulations from sample 
sims_nodef = sims(:, sims(2520, :) ~= 0 & sims(2520, :) ~= 1); %For s (not 0 or 1)
xA_nodef = xA(:, sims(2520, :) ~= 0 & sims(2520, :) ~= 1); %For xA 
xB_nodef = xB(:, sims(2520, :) ~= 0 & sims(2520, :) ~= 1); %For xB
DefA_nodef = DefA(:, sims(2520, :) ~= 0 & sims(2520, :) ~= 1); %For DefA 
DefB_nodef = DefB(:, sims(2520, :) ~= 0 & sims(2520, :) ~= 1); %For DefA 

%COMPUTATIONS FOR PANEL C
%--Distance-to-Default--
%This computes an interpolated function for distance to default
BoundInterp = griddedInterpolant(s,B00,'makima','none');

%This computes simulated correlation between the distance-to-defaults
[CorDD_nodef,~,~] = SimulatedCorrelationDD(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),sig,sigB,BoundInterp);

%--10-year Default Probability--
%This computes an interpolated function for default probability
DP10 = probP; %This sets the previously computed probability to a new variable. If it was not computed for 10-years previously then rerun the following code:
%[DP10] = PROBDEF(B00,Ny,Ns,Ntprob,10,ymin,ymax,sig,sigB,rho,mu,muB,omega,0); %Last arguement 0 for probability under P and 1 for probability under Q
DP10Interp = griddedInterpolant(Y,S,DP10,'makima','none');
%This computes the simulated correlation between default probability
[CorDP10_nodef,~,~] = SimulatedCorrelation(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,DP10Interp);

%--Leverage--
%This computes an interpolated function for leverage
for i=1:Ny
    for j=1:Ns
        Lev(i,j) = D00(i,j)./(E00(i,j)+D00(i,j));
    end
end
LevInterp = griddedInterpolant(Y,S,Lev,'makima','none');
%This computes the simulated correlation between leverage
[CorLev_nodef,~,~] = SimulatedCorrelation(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,LevInterp);

%--Credit Spreads--
%This computes an interpolated function for the credit spreads (using the debt value D00)
D00Interp = griddedInterpolant(Y,S,D00,'makima','none');
for i=1:Ny
    for j=1:Ns
        CS(i,j) = (c+m*p)*((1/D00(i,j))-(1/D00(Ny,j)))*10000;
    end
end
CSInterp = griddedInterpolant(Y,S,CS,'makima','none');
%This computes the simulated correlation between credit spreads
[CorCS_nodef,~,~] = SimulatedCorrelation(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,CSInterp);

%This resports the mean, median, 5th and 95th percentile for all four quantitites (Panel C)
[mean(CorDD_nodef),prctile(CorDD_nodef,50),prctile(CorDD_nodef,5),prctile(CorDD_nodef,95)]         %Distance-to-default
[mean(CorDP10_nodef),prctile(CorDP10_nodef,50),prctile(CorDP10_nodef,5),prctile(CorDP10_nodef,95)] %Default probability
[mean(CorLev_nodef),prctile(CorLev_nodef,50),prctile(CorLev_nodef,5),prctile(CorLev_nodef,95)]     %leverage
[mean(CorCS_nodef),prctile(CorCS_nodef,50),prctile(CorCS_nodef,5),prctile(CorCS_nodef,95)]         %Credit spreads

%COMPUTATIONS FOR PANEL D
%--Equity Exces Return--
%This computes an interpolated function for the equity
E00Interp = griddedInterpolant(Y,S,E00,'makima','none');
%This computes the simulated correlation between equity excess returns
[CorEER_nodef,~,~] = SimulatedCorrelationEExRet(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,E00Interp,rf,phi,c,Tmax);

%--Equity Return Volatility--
%This computes an interpolated function for equity volatility
[Evol] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,E00);
EvolInterp = griddedInterpolant(Y,S,Evol,'makima','none');
%This computes the simulated correlation between equity volatilty
[CorEvol_nodef,~,~] = SimulatedCorrelation(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,EvolInterp);

%--Equity Risk Premium--
%This computes an interpolated function for equity risk premium
[ERP] = ERPcalc(Ny,Ns,ymin,ymax,sig,sigB,rho,E00);
ERPInterp = griddedInterpolant(Y,S,ERP,'makima','none');
%This computes the simulated correlation between equity risk premium
[CorERP_nodef,~,~] = SimulatedCorrelation(xA_nodef,xB_nodef,sims_nodef,DefA_nodef,DefB_nodef,Nt,size(sims_nodef,2),Ny,Ns,y,ERPInterp);

%This resports the mean, median, 5th and 95th percentile for all three quantitites (Panel D)
[mean(CorEER_nodef),prctile(CorEER_nodef,50),prctile(CorEER_nodef,5),prctile(CorEER_nodef,95)]     %Equity excess return
[mean(CorEvol_nodef),prctile(CorEvol_nodef,50),prctile(CorEvol_nodef,5),prctile(CorEvol_nodef,95)] %Equity return volatility
[mean(CorERP_nodef),prctile(CorERP_nodef,50),prctile(CorERP_nodef,5),prctile(CorERP_nodef,95)]     %Equity risk premium

%--- Export Table OA.2 to output/tables/TableOA2_histograms_nodefault.tex (caption + numbers) ---
% Panels A/B: correlations including defaults; Panels C/D: excluding defaults. All percent; Mean/Median/5th/95th.
prow = @(fid,label,x) fprintf(fid,'\\multicolumn{1}{l}{%s} & %.2f\\%% & %.2f\\%% & %.2f\\%% & %.2f\\%% \\\\\n', ...
    label, 100*mean(x), 100*prctile(x,50), 100*prctile(x,5), 100*prctile(x,95));
fid = fopen(fullfile(tabledir,'TableOA2_histograms_nodefault.tex'),'w');
fprintf(fid,'%s\n',[ ...
"\begin{table}[h]"
"\small"
"\centering"
"\caption{Co-movement in default risk and equity moments from simulated economies -- excluding defaults}"
"\label{tab:table_simulation_no_default}"
"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}lcccc}"
"\toprule"
"& \textbf{Mean} & \textbf{Median} & \textbf{5th} & \textbf{95th} \\"
"\addlinespace"
"& (1) & (2) & (3) & (4) \\"
"\cmidrule{2-5}"
"\\"
"\multicolumn{5}{l}{\textbf{Panel A: Correlations in default risk across trees (including default)}} \\"
"\midrule"
]);
prow(fid,"Distance-to-default",CorDD); prow(fid,"10-year default probability",CorDP10);
prow(fid,"Leverage",CorLev); prow(fid,"Credit spread",CorCS);
fprintf(fid,'%s\n',[ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel B: Correlations in equity moments across trees (including default)}} \\"
"\midrule"
]);
prow(fid,"Equity excess return",CorEER); prow(fid,"Equity return volatility",CorEvol); prow(fid,"Equity risk premium",CorERP);
fprintf(fid,'%s\n',[ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel C: Correlations in default risk across trees (excluding default)}} \\"
"\midrule"
]);
prow(fid,"Distance-to-default",CorDD_nodef); prow(fid,"10-year default probability",CorDP10_nodef);
prow(fid,"Leverage",CorLev_nodef); prow(fid,"Credit spread",CorCS_nodef);
fprintf(fid,'%s\n',[ ...
"\\"
"\multicolumn{5}{l}{\textbf{Panel D: Correlations in equity moments across trees (excluding default)}} \\"
"\midrule"
]);
prow(fid,"Equity excess return",CorEER_nodef); prow(fid,"Equity return volatility",CorEvol_nodef); prow(fid,"Equity risk premium",CorERP_nodef);
fprintf(fid,'%s\n',[ ...
"\bottomrule"
"\end{tabular*}"
"\end{table}"
]);
fclose(fid);
fprintf('Wrote %s\n', fullfile(tabledir,'TableOA2_histograms_nodefault.tex'));
 


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Table OA.10:                   %
% 'Sovereign debt spillover - case study' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%The computes the credit spreads for trees A and B for the baseline and counterfactuals
[CSA7,CSB7] = CSpread(Ny,Ns,ymin,ymax,c,1/7,c/rf(jhalf),D7,1);          %7-years (baseline)
[CSA15,CSB15] = CSpread(Ny,Ns,ymin,ymax,c,1/15,c/rf(jhalf),D15,1);      %15-years (longer maturity)
[CSA7x,CSB7x] = CSpread(Ny,Ns,ymin,ymax,c,1/7,c/rf(jhalf),D7,1.2);      %7-years (higher X)
[CSA7mu,CSB7mu] = CSpread(Ny,Ns,ymin,ymax,c,1/7,c/rf(jhalf),D7mu,1);    %7-years (higher mu)
[CSA7sig,CSB7sig] = CSpread(Ny,Ns,ymin,ymax,c,1/7,c/rf(jhalf),D7sig,1); %7-years (higher sig)

%The computes the cross price elasticity of the credit spreads for the baseline and counterfactuals
[CPECS7,~,~] = CPE1D(Ns,CSA7,CSB7);          %7-years (baseline)
[CPECS15,~,~] = CPE1D(Ns,CSA15,CSB15);       %15-years (longer maturity)
[CPECS7x,~,~] = CPE1D(Ns,CSA7x,CSB7x);     %7-years (higher X)
[CPECS7mu,~,~] = CPE1D(Ns,CSA7mu,CSB7mu);    %7-years (higher mu)
[CPECS7sig,~,~] = CPE1D(Ns,CSA7sig,CSB7sig); %7-years (higher sig)

%This outputs the numbers in Table OA.10
j06 = round(0.6/ds)+1; %Calculates the node corresponding to s=0.6
j07 = round(0.7/ds)+1; %Calculates the node corresponding to s=0.7

[CPECS7(j07),CPECS7(j06),CPECS7(jhalf)]          %7-years (baseline)
[CPECS15(j07),CPECS15(j06),CPECS15(jhalf)]       %15-years (longer maturity)
[CPECS7x(j07),CPECS7x(j06),CPECS7x(jhalf)]       %7-years (higher X)
[CPECS7mu(j07),CPECS7mu(j06),CPECS7mu(jhalf)]    %7-years (higher mu)
[CPECS7sig(j07),CPECS7sig(j06),CPECS7sig(jhalf)] %7-years (higher sig)

%--- Export Table OA.10 to output/tables/TableOA10_CPE_spillover.tex (caption + numbers) ---
% Panel A: data constants (Gabaix-Koijen). Panel B: model, rows = Italy relative size
% Low/Baseline/High = s nodes j07/j06/jhalf; cols = baseline + 4 counterfactuals; raw decimals.
fid = fopen(fullfile(tabledir,'TableOA10_CPE_spillover.tex'),'w');
fprintf(fid,'%s\n',[ ...
"\begin{table}[h]"
"\small"
"\centering"
"\caption{Sovereign debt spillover -- case study}"
"\label{tab:table_CPE_spillover}"
"\begin{tabular*}{\textwidth}{@{\extracolsep{\fill}}llcccccc}"
"\toprule"
" & & \multicolumn{1}{c}{\textbf{Baseline}} & \multicolumn{4}{c}{\textbf{Counterfactual}} \\"
"\cmidrule(lr){3-3} \cmidrule(lr){4-7}"
" & & \multicolumn{1}{c}{} & \multicolumn{1}{c}{Longer maturity} & \multicolumn{1}{c}{Lower default risk} & \multicolumn{1}{c}{Higher growth} & \multicolumn{1}{c}{Higher volatility} \\"
" & & \multicolumn{1}{c}{} & \multicolumn{1}{c}{15y} & \multicolumn{1}{c}{$X^i_t = 1.2$} & \multicolumn{1}{c}{$\mu_i = 2.5\%$} & \multicolumn{1}{c}{$\sigma_i = 24\%$} \\"
"\\"
"& &  (1) & (2) & (3) & (4) &(5) \\"
"\multicolumn{7}{l}{\textbf{Panel A: Data}} \\"
"\midrule \\"
"Italy's relative size: & & & & & & \\"
"\,\, Low & 0.3 & 0.1500 & & & & \\"
"\,\, Baseline & 0.4 & 0.2000 & & & & \\"
"\,\, High & 0.5 & 0.2500 & & & & \\"
"\\"
"\multicolumn{7}{l}{\textbf{Panel B: Model}} \\"
"\midrule \\"
"Italy's relative size: & & & & & & \\"
]);
fprintf(fid,'%s & 0.3 & %.4f & %.4f & %.4f & %.4f & %.4f \\\\\n', "\,\, Low",      CPECS7(j07),  CPECS15(j07),  CPECS7x(j07),  CPECS7mu(j07),  CPECS7sig(j07));
fprintf(fid,'%s & 0.4 & %.4f & %.4f & %.4f & %.4f & %.4f \\\\\n', "\,\, Baseline", CPECS7(j06),  CPECS15(j06),  CPECS7x(j06),  CPECS7mu(j06),  CPECS7sig(j06));
fprintf(fid,'%s & 0.5 & %.4f & %.4f & %.4f & %.4f & %.4f \\\\\n', "\,\, High",     CPECS7(jhalf),CPECS15(jhalf),CPECS7x(jhalf),CPECS7mu(jhalf),CPECS7sig(jhalf));
fprintf(fid,'%s\n',[ ...
"\bottomrule"
"\end{tabular*}"
"\end{table}"
]);
fclose(fid);
fprintf('Wrote %s\n', fullfile(tabledir,'TableOA10_CPE_spillover.tex'));



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure OA.1:                  %
% 'Equilibrium asset pricing quantities' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%The three lines below compute the levered equity risk premium (for X=1), the unlevered equity value, and the unlevered equity risk premium (for X=1)
[ERPA,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00,1);
[Eunlev] = UnleveredEquity(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi);

%Interest-rate counter factual (assuming full boundary)
[ERPAcount,~] = ERPPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E00count,1);
[Eunlevcount,~] = UnleveredEquity_count(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,0);

%This plots the 3x2 figure
FigOA1=figure;
%FIG-a:
subplot(3,2,1)
plot(s(4:Ns),ERPA(4:Ns),'-b','LineWidth',2)
hold on
plot(s(4:Ns),ERPAcount(4:Ns),':b','LineWidth',2)
xlim([0 1])
ylabel('Equity risk premium')
title('(A) Risk Premium')
legend({'Full model','Counterfactual'},'Location','northwest')
legend('boxoff')

%FIG-b:
subplot(3,2,2)
plot(s(1:Ns),rf(1:Ns),'-b','LineWidth',2)
hold on
plot(s(1:Ns),rf(1)*ones(Ns,1),':b','LineWidth',2)
xlim([0 1])
ylim([0.03 0.07])
ylabel('Risk-free rate')
title('(B) Risk-free rate')

%FIG-c:
subplot(3,2,3)
plot(s(1:Ns),E00(ibase,1:Ns),'-b','LineWidth',2)
hold on
plot(s(1:Ns),E00count(ibase,1:Ns),':b','LineWidth',2)
xlim([0 1])
ylabel('Equity value')
title('(C) Equity valuation of tree A')

%FIG-d:
subplot(3,2,4)
plot(s,D00(ibase,:),'-b','LineWidth',2)
hold on
plot(s,D00count(ibase,:),':b','LineWidth',2)
xlim([0 1])
ylim([5 10])
ylabel('Debt value')
title('(D) Debt valuation of tree A')

%FIG-e:
subplot(3,2,5)
plot(s(1:Ns),Eunlev(ibase,1:Ns)/(1-phi),'-b','LineWidth',2)
hold on
plot(s(1:Ns),Eunlevcount(ibase,1:Ns)/(1-phi),':b','LineWidth',2)
xlim([0 1])
ylabel('Total asset value')
xlabel('Share of tree A')
title('(E) Total asset valuation of tree A')

%FIG-f:
subplot(3,2,6)
plot(s(2:Ns),D00(ibase,2:Ns)./(E00(ibase,2:Ns)+D00(ibase,2:Ns)),'-b','LineWidth',2)
hold on
plot(s(2:Ns),D00count(ibase,2:Ns)./(E00count(ibase,2:Ns)+D00count(ibase,2:Ns)),':b','LineWidth',2)
xlim([0 1])
ylim([0.3 0.5])
ylabel('Debt/(Equity+Debt)')
xlabel('Share of tree A')
title('(F) Leverage ratio of tree A')

set(FigOA1,'Units','inches')
set(FigOA1,'Position',[25 1 8 9.66])
theme(FigOA1,'light')
exportgraphics(FigOA1,fullfile(figdir,'FigOA1.eps'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure OA.2:                                       %
% 'Distribution of asset pricing moments accross simulations' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%NOTE: The computations for Table 3 should have been run to produce the interpolated functions for the below
%The folowing computes the asset pricing moments (Leverage, Credit Spreads, Equity Volatility, and Equity Risk Premium) along the simulation paths
[simLevA,~] = SimulatedMoment(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,LevInterp);
[simCSA,~] = SimulatedMoment(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,CSInterp);
[simEvolA,~] = SimulatedMoment(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,EvolInterp);
[simERPA,~] = SimulatedMoment(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,ERPInterp);

%The following computes the average moment over time for each simulation
for j=1:Nsim
    mean_LevA(j)=mean(nonzeros(simLevA(:,j)));
    mean_CSA(j)=mean(nonzeros(simCSA(:,j)));
    mean_EvolA(j)=mean(nonzeros(simEvolA(:,j)));
    mean_ERPA(j)=mean(nonzeros(simERPA(:,j)));
end

%The following computes the averages to annotate the figure
a1 = round(mean(mean_LevA(:),'omitnan'),4);
a2 = round(mean(mean_CSA(:),'omitnan'),2);
a3 = round(mean(mean_EvolA(:),'omitnan'),4);
a4 = round(mean(mean_ERPA(:),'omitnan'),4);

%This plots the 2x2 figure 
FigOA2=figure;
%FIG-a:
subplot(2,2,1)
histogram(mean_LevA(:),'BinWidth',0.015)
xlim([0,1])
ylim([0 750])
line([mean(mean_LevA(:),'omitnan'),mean(mean_LevA(:),'omitnan')],ylim,'Color','b','LineWidth',1);
text(mean(mean_LevA(:),'omitnan')+0.02,700,num2str(a1),'Color','black','FontSize',12)
ylabel('Frequency')
xlabel('Average Leverage')
title('(A) Leverage')

%FIG-b:
subplot(2,2,2)
histogram(mean_CSA(:),'BinWidth',10)
xlim([0,600])
ylim([0 1600])
line([mean(mean_CSA(:),'omitnan'),mean(mean_CSA(:),'omitnan')],ylim,'Color','b','LineWidth',1);
text(mean(mean_CSA(:),'omitnan')+15,1000,num2str(a2),'Color','black','FontSize',12)
xlabel('Average Credit Spread')
title('(B) Credit Spread')

%FIG-c:
subplot(2,2,3)
histogram(mean_EvolA(:),'BinWidth',0.015)
xlim([0.2,1])
ylim([0 1900])
line([mean(mean_EvolA(:),'omitnan'),mean(mean_EvolA(:),'omitnan')],ylim,'Color','b','LineWidth',1);
text(mean(mean_EvolA(:),'omitnan')+0.03,1200,num2str(a3),'Color','black','FontSize',12)
ylabel('Frequency')
xlabel('Average Equity Volatility')
title('(C) Equity Volatility')

%FIG-d:
subplot(2,2,4)
histogram(mean_ERPA(:),'BinWidth',0.0015)
xlim([0,0.1])
ylim([0 1300])
line([mean(mean_ERPA(:),'omitnan'),mean(mean_ERPA(:),'omitnan')],ylim,'Color','b','LineWidth',1);
text(mean(mean_ERPA(:),'omitnan')+0.003,1200,num2str(a4),'Color','black','FontSize',12)
xlabel('Average Equity Risk Premium')
title('(D) Equity Risk Premium')

set(FigOA2,'Units','inches')
set(FigOA2,'Position',[25 2 8 6.33])
theme(FigOA2,'light')
exportgraphics(FigOA2,fullfile(figdir,'FigOA2.pdf'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure OA.3:                                                       %
% 'Distribution of default risk correlations - model vs. counterfactual case' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%FOR PANEL A
%This defines the static default boundary
for j=1:Ns
    Bzero(j) = B00(jhalf);
end
Bzero=Bzero';
%This computes an interpolated function for the static default boundary
BoundstatInterp = griddedInterpolant(s,Bzero,'makima','none');
%This computes for the simulated correlation between distance-to-default for the static boundarystatic boundary
[CorDDstat,~,~] = SimulatedCorrelationDDstat(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,sig,sigB,BoundstatInterp);

%FOR PANEL B
%This defines the static default probability function
for j=1:Ns
    for i=1:Ny
        DP10stat(i,j)=DP10(i,jhalf);
    end
end
DP10statInterp = griddedInterpolant(Y,S,DP10stat,'makima','none');
%This computes the simulated correlation between default probability for the static boundary
[CorDP10stat,DPA10statsim,DPB10statsim] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,DP10statInterp);

%FOR PANEL C
%This computes the function with a slice at s=0.5 (static Lev)
for i=1:Ny
    for j=1:Ns
        Levstat(i,j) = Lev(i,jhalf);
    end
end
LevInterpstat = griddedInterpolant(Y,S,Levstat,'makima','none');
%This computes the simulated correlation between leverage for the static boundary
[CorLevstat,LevAstatsim,LevBstatsim] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,LevInterpstat);

%FOR PANEL D
%This computes the function with a slice at s=0.5 (static CS)
for i=1:Ny
    for j=1:Ns
        CSstat(i,j) = CS(i,jhalf);
    end
end
CSInterpstat = griddedInterpolant(Y,S,CSstat,'makima','none');
%This computes the simulated correlation between credit spreads for the static boundary
[CorCSstat,CSAstatsim,CSBstatsim] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,CSInterpstat);

%This plots the 2x2 figure of the histograms
%NOTE: the non-static boundary simulation results should have already been computed when producing Table 2 so make sure the computations for this table are run first
FigOA3=figure;
%FIG-a:
subplot(2,2,1)
histogram(CorDD,'BinWidth',0.0075)
hold on
histogram(CorDDstat,'BinWidth',0.0075,'FaceAlpha',0.2)
xlim([-0.1,0.25])
ylim([0 3100])
line([mean(CorDD),mean(CorDD)],ylim,'Color','b','LineWidth',1);
line([mean(CorDDstat),mean(CorDDstat)],ylim,'Color','r','LineWidth',1);
ylabel('Frequency')
title('(A) Distance-to-default')

%FIG-b:
subplot(2,2,2)
histogram(CorDP10,'BinWidth',0.0075)
hold on
histogram(CorDP10stat,'BinWidth',0.0075,'FaceAlpha',0.2)
xlim([-0.1,0.25])
ylim([0 3100])
line([mean(CorDP10),mean(CorDP10)],ylim,'Color','b','LineWidth',1);
line([mean(CorDP10stat),mean(CorDP10stat)],ylim,'Color','r','LineWidth',1);
title('(B) 10-year default probability')

%FIG-c:
subplot(2,2,3)
histogram(CorLev,'BinWidth',0.0075)
hold on
histogram(CorLevstat,'BinWidth',0.0075,'FaceAlpha',0.2)
xlim([-0.1,0.25])
ylim([0 3100])
line([mean(CorLev),mean(CorLev)],ylim,'Color','b','LineWidth',1);
line([mean(CorLevstat),mean(CorLevstat)],ylim,'Color','r','LineWidth',1);
ylabel('Frequency')
xlabel('Correlation')
title('(C) Leverage')

%FIG-d:
subplot(2,2,4)
histogram(CorCS,'BinWidth',0.0075)
hold on
histogram(CorCSstat,'BinWidth',0.0075,'FaceAlpha',0.2)
xlim([-0.1,0.5])
ylim([0 3100])
line([mean(CorCS),mean(CorCS)],ylim,'Color','b','LineWidth',1);
line([mean(CorCSstat),mean(CorCSstat)],ylim,'Color','r','LineWidth',1);
xlabel('Correlation')
title('(D) Credit spread')
legend({'Stochastic boundary','Static boundary'},'Location','northeast')

set(FigOA3,'Units','inches')
set(FigOA3,'Position',[25 2 8 6.33])
theme(FigOA3,'light')
exportgraphics(FigOA3,fullfile(figdir,'FigOA3.pdf'),'BackgroundColor','none')



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Code for Figure OA.4:                                       %
% 'Distribution of the correlations in asset pricing moments' %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%FOR PANEL A
%This computes the ERP function with a slice at s=0.5 (static ERP)
for i=1:Ny
    for j=1:Ns
        ERPstat(i,j) = ERP(i,jhalf);
    end
end
ERPInterpstat = griddedInterpolant(Y,S,ERPstat,'makima','none');
%This computes the simulated correlation between equity risk premium for the static boundary
[CorERPstat,~,~] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,ERPInterpstat);

%FOR PANEL B
%This computes the Evol function with a slice at s=0.5 (static Evol)
for i=1:Ny
    for j=1:Ns
        Evolstat(i,j) = Evol(i,jhalf);
    end
end
EvolInterpstat = griddedInterpolant(Y,S,Evolstat,'makima','none');
%This computes the simulated correlation between equity volatility for the static boundary
[CorEvolstat,~,~] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,EvolInterpstat);

%FOR PANEL C
%This computes an interpolated function for debt risk premium
[DRP] = ERPcalc(Ny,Ns,ymin,ymax,sig,sigB,rho,D00);
DRPInterp = griddedInterpolant(Y,S,DRP,'makima','none');
%This computes the simulated correlation between debt risk premium
[CorDRP,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,DRPInterp);
%This computes the DRP function with a slice at s=0.5 (static DRP)
for i=1:Ny
    for j=1:Ns
        DRPstat(i,j) = DRP(i,jhalf);
    end
end
DRPInterpstat = griddedInterpolant(Y,S,DRPstat,'makima','none');
%This computes the simulated correlation between debt risk premium for the static boundary
[CorDRPstat,~,~] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,DRPInterpstat);

%FOR PANEL D
%This computes an interpolated function for debt volatility
[Dvol] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,D00);
DvolInterp = griddedInterpolant(Y,S,Dvol,'makima','none');
%This computes the simulated correlation between debt volatilty
[CorDvol,~,~] = SimulatedCorrelation(xA,xB,sims,DefA,DefB,Nt,Nsim,Ny,Ns,y,DvolInterp);
%This computes the Dvol function with a slice at s=0.5 (static Dvol)
for i=1:Ny
    for j=1:Ns
        Dvolstat(i,j) = Dvol(i,jhalf);
    end
end
DvolInterpstat = griddedInterpolant(Y,S,Dvolstat,'makima','none');
%This computes the simulated correlation between debt volatilty for the static boundary
[CorDvolstat,~,~] = SimulatedCorrelation(xAstat,xBstat,simsstat,DefAstat,DefBstat,Nt,Nsim,Ny,Ns,y,DvolInterpstat);

%This plots the 2x2 figure of the histograms
%NOTE: the non-static boundary simulation results should have already been computed when producing Table 2 so make sure the computations for this table are run first
FigOA4=figure;
%FIG-a:
subplot(2,2,1)
histogram(CorERP,'BinWidth',0.01)
hold on
histogram(CorERPstat,'BinWidth',0.01,'FaceAlpha',0.2)
xlim([-0.2,1])
ylim([0 3300])
line([mean(CorERP),mean(CorERP)],ylim,'Color','b','LineWidth',1);
line([mean(CorERPstat),mean(CorERPstat)],ylim,'Color','r','LineWidth',1);
ylabel('Frequency')
title('(A) Equity risk premium')

%FIG-b:
subplot(2,2,2)
histogram(CorEvol,'BinWidth',0.01)
hold on
histogram(CorEvolstat,'BinWidth',0.01,'FaceAlpha',0.2)
xlim([-0.2,1])
ylim([0 3300])
line([mean(CorEvol),mean(CorEvol)],ylim,'Color','b','LineWidth',1);
line([mean(CorEvolstat),mean(CorEvolstat)],ylim,'Color','r','LineWidth',1);
title('(B) Equity volatility')

%FIG-c:
subplot(2,2,3)
histogram(CorDRP,'BinWidth',0.01)
hold on
histogram(CorDRPstat,'BinWidth',0.01,'FaceAlpha',0.2)
xlim([-0.2,1])
ylim([0 3300])
line([mean(CorDRP),mean(CorDRP)],ylim,'Color','b','LineWidth',1);
line([mean(CorDRPstat),mean(CorDRPstat)],ylim,'Color','r','LineWidth',1);
ylabel('Frequency')
xlabel('Correlation')
title('(C) Debt risk premium')

%FIG-d:
subplot(2,2,4)
histogram(CorDvol,'BinWidth',0.01)
hold on
histogram(CorDvolstat,'BinWidth',0.01,'FaceAlpha',0.2)
xlim([-0.2,1])
ylim([0 3300])
line([mean(CorDvol),mean(CorDvol)],ylim,'Color','b','LineWidth',1);
line([mean(CorDvolstat),mean(CorDvolstat)],ylim,'Color','r','LineWidth',1);
xlabel('Correlation')
title('(D) Debt volatility')
legend({'Stochastic boundary','Static boundary'},'Location','northeast')

set(FigOA4,'Units','inches')
set(FigOA4,'Position',[25 2 8 6.33])
theme(FigOA4,'light')
exportgraphics(FigOA4,fullfile(figdir,'FigOA4.pdf'),'BackgroundColor','none')

fprintf('Total runtime: %.2f hours (%.0f seconds)\n', toc(tStart)/3600, toc(tStart));
diary off;
