%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function computing the unlevered equity value %
% given by Equation 8 in the paper              %
% NOTE: Needs the function vcoch.m              %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Eunlev] = UnleveredEquity(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi)

%computed parameters
eta=sqrt(sig*sig+sigB*sigB-2*rho*sig*sigB);
nu=muB-mu-0.5*sigB*sigB+0.5*sig*sig;
psi=sqrt(nu*nu+2*del*eta*eta);
thet=(nu+psi)/(eta*eta);
gamm=(nu-psi)/(eta*eta);

%definition
y=linspace(ymin,ymax,Ny);
dy=y(2)-y(1);

%This defines the unlevered asset value
vc=zeros(Ns,1);
[vc] = vcoch(Ns,del,gamm,nu,eta,thet,psi);
for j=1:Ns
    for i=1:Ny
        Eunlev(i,j) = (1-phi)*exp(y(i))*vc(j);
    end
end