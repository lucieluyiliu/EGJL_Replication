%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate the equity risk premium from numerical %
% differentiation of the equity value function (E)             %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [ERP] = ERPcalc(Ny,Ns,ymin,ymax,sig,sigB,rho,E)

eta=sqrt(sig*sig+sigB*sigB-2*rho*sig*sigB);

%Defines the grid
y=linspace(ymin,ymax,Ny);
s=linspace(0,1,Ns);
ds=s(2)-s(1);
dy=y(2)-y(1);

%This computs the derivative of E wrt s
for i=1:Ny
    dEds(i,1)=(E(i,2)-E(i,1))/(ds);
    for j=2:Ns-1
        dEds(i,j)=(E(i,j+1)-E(i,j-1))/(2*ds);
    end
    dEds(i,Ns)=(E(i,Ns)-E(i,Ns-1))/(ds);
end

%This computs the derivative of E wrt y
for j=1:Ns
    dEdy(1,j)=(E(2,j)-E(1,j))/(dy);
    for i=2:Ny-1
        dEdy(i,j)=(E(i+1,j)-E(i-1,j))/(2*dy);
    end
    dEdy(Ny,j)=(E(Ny,j)-E(Ny-1,j))/(dy);
end

for j=1:Ns
    for i=1:Ny
        ERP(i,j)=sig*(sig*s(j)+rho*sigB*(1-s(j)))*dEdy(i,j)/E(i,j)+(eta*eta*s(j)+sigB*(rho*sig-sigB))*s(j)*(1-s(j))*dEds(i,j)/E(i,j);
    end
end