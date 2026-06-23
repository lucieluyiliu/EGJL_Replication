%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to estimate the distance-to-default correlation between %
% trees A and B given the optimal default boundary B               % 
% NOTE: This only works in the symmetric tree case                 %
% NOTE: Needs the function Elasticity.m                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Corr] = CorrEst(B,Ns,smin,smax,jdelfit,jdel,order,rho)

%This defines the boundary for A and B, assuming symmetric mu and sigma
for j=1:Ns
  BA(j) = B(j);
  BB(j) = B(Ns+1-j);  
end

[~,~,jmin,jmax,FA] = Elasticity(BA,Ns,smin,smax,jdelfit,jdel,order);
[~,~,~,~,FB] = Elasticity(BB,Ns,smin,smax,jdelfit,jdel,order);

for j=jmin:jmax
  Corr(j) = (FB(j)-FA(j)+rho*(1-FA(j)*FB(j)))/sqrt((1-2*rho*FA(j)+FA(j)*FA(j))*(1+2*rho*FB(j)+FB(j)*FB(j)));
end
