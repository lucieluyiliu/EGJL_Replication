%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to compute the credit spreads for both trees given the debt %
% value as an input. NOTE: This only works in the symmetric tree case  % 
% (since D would be different for A and B otherwise)                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CSA,CSB] = CSpread(Ny,Ns,ymin,ymax,c,m,p,D,X)

y=linspace(ymin,ymax,Ny);
s=linspace(0,1,Ns);
ds=s(2)-s(1);

%Define (Y,S) grid
[Y,S] = ndgrid(y,s);

DInterp = griddedInterpolant(Y,S,D,'makima','none');

%This computes the credit spread
for j=1:Ns
    CSA(j)=(c+m*p)*((1/DInterp(log(X),s(j)))-(1/DInterp(y(Ny),s(j))))*10000;
    CSB(j)=(c+m*p)*((1/DInterp(log(X*(1-s(j))/s(j)),1-s(j)))-(1/DInterp(y(Ny),1-s(j))))*10000;
end