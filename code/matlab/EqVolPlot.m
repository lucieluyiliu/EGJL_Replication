%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to calculate the equity return volatility from    %
% numerical differentiation of the equity value function (E) %
% and to then compute the values of this for trees A and B   %
% NOTE: This only works in the symmetric tree case           %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [EvolA,EvolB] = EqVolPlot(Ny,Ns,ymin,ymax,sig,sigB,rho,E,X)

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
        Evol(i,j)=sqrt(s(j)*s(j)*(1-s(j))*(1-s(j))*(sig*sig+sigB*sigB-2*rho*sig*sigB)*dEds(i,j)*dEds(i,j)+sig*sig*dEdy(i,j)*dEdy(i,j)+2*sig*sig*(1-(rho*sigB/sig))*s(j)*(1-s(j))*dEdy(i,j)*dEds(i,j))/E(i,j);
    end
end

%Define (Y,S) grid
[Y,S] = ndgrid(y,s);

%This creates an interpolated function
EVolInterp = griddedInterpolant(Y,S,Evol,'makima','none');

%This computes the Evol of A and B
for j=1:Ns
    EvolA(j)=EVolInterp(log(X),s(j));
    EvolB(j)=EVolInterp(log(X*(1-s(j))/s(j)),1-s(j));
end






