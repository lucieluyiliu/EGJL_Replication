%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function computing the total equity volatility %
% and risk-free rate for a given economy         %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [tvol,rf] = Equil(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB)

%Defines the grid
y=linspace(ymin,ymax,Ny);
s=linspace(0,1,Ns);
dy=y(2)-y(1);
ds=s(2)-s(1);

%This computs the derivative of E wrt s
for j=1:Ns
    tvol(j)=sqrt(sig*sig*s(j)*s(j)+sigB*sigB*(1-s(j))*(1-s(j))+2*rho*sig*sigB*s(j)*(1-s(j)));
    rf(j)=del+mu*s(j)+muB*(1-s(j))-sig*sig*s(j)*s(j)-sigB*sigB*(1-s(j))*(1-s(j))-2*rho*sig*sigB*s(j)*(1-s(j));
end