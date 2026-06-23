%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate the cross elasticity of two 1D s-dependent %
% functions (FA/FB) from numerical differentiation                 %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CPE,EFA,EFB] = CPE1D(Ns,FA,FB)

%Defines the grid
s=linspace(0,1,Ns);
ds=s(2)-s(1);


%This computes the derivative of FA and FB wrt s
dFAds(1) = (FA(2)-FA(1))/ds;
dFBds(1) = (FB(2)-FB(1))/ds;
for j=2:Ns-1
    dFAds(j) = (FA(j+1)-FA(j-1))/(2*ds);
    dFBds(j) = (FB(j+1)-FB(j-1))/(2*ds); 
end
dFAds(Ns) = (FA(Ns)-FA(Ns-1))/ds;
dFBds(Ns) = (FB(Ns)-FB(Ns-1))/ds;

%This computes the cross-price elasticity of FB with respect to FA
for j=1:Ns
    EFA(j) = (1/FA(j))*dFAds(j);
    EFB(j) = (1/FB(j))*dFBds(j);
    CPE(j) = EFA(j)/EFB(j);
end