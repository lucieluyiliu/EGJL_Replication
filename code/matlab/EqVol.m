%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate the equity return volatility from    %
% numerical differentiation of the equity value function (E) %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Evol] = EqVol(Ny,Ns,ymin,ymax,sig,sigB,rho,E)

%Defines the grid
y=linspace(ymin,ymax,Ny);
s=linspace(0,1,Ns);
dy=y(2)-y(1);
ds=s(2)-s(1);

%This computes the derivative of E wrt s
for i=1:Ny
    dEds(i,1)=(E(i,2)-E(i,1))/(ds);
    for j=2:Ns-1
        dEds(i,j)=(E(i,j+1)-E(i,j-1))/(2*ds);
    end
    dEds(i,Ns)=(E(i,Ns)-E(i,Ns-1))/(ds);
end

%This computes the derivative of E wrt y
for j=1:Ns
    dEdy(1,j)=(E(2,j)-E(1,j))/(dy);
    for i=2:Ny-1
        dEdy(i,j)=(E(i+1,j)-E(i-1,j))/(2*dy);
    end
    dEdy(Ny,j)=(E(Ny,j)-E(Ny-1,j))/(dy);
end

for j=1:Ns
    for i=1:Ny
       Evol(i,j)=sqrt(s(j)*s(j)*(1-s(j))*(1-s(j))*(sig*sig+sigB*sigB-2*rho*sig*sigB)*dEds(i,j)*dEds(i,j)+sig*sig*dEdy(i,j)*dEdy(i,j)+2*sig*sig*(1-(rho*sigB/sig))*s(j)*(1-s(j))*dEdy(i,j)*dEds(i,j))/E(i,j);
    end
end

