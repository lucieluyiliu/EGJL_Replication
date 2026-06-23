%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function producing Nsim different simulations of the values of X_i %
% given the default boundary function B                              %
% NOTE: This only works in the symmetric tree case                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [xA,xB,sims,DefA,DefB,xAstat,xBstat,simsstat,DefAstat,DefBstat] = Simulation(B,xAl,xAu,Tmax,Nt,Nsim,sig,sigB,rho,mu,muB,del,c)
                                                                          
%This defines the s vector to interpolate the boundary
Ns = length(B);
s=linspace(0,1,Ns);

%This computes the static boundaries for different values of s0
for j=1:Ns
    s0=s(j);
    rs0=del+mu*s0+muB*(1-s0)-s0*s0*sig*sig-(1-s0)*(1-s0)*sigB*sigB-2*s0*(1-s0)*rho*sig*sigB;
    betars0=(0.5*sig*sig-(mu-sig*sig+sig*(sig-rho*sigB)*(1-s0))-sqrt(2*rs0*sig*sig+(0.5*sig*sig-(mu-sig*sig+sig*(sig-rho*sigB)*(1-s0)))*(0.5*sig*sig-(mu-sig*sig+sig*(sig-rho*sigB)*(1-s0)))))/(sig*sig);
    Bs0=betars0*c*(rs0-(mu-sig*sig+sig*(sig-rho*sigB)*(1-s0)))/(rs0*(betars0-1));
    Bounds0(j)=Bs0;
end

%This computes an interpolated function for the stochastic default boundary
BoundInterp = griddedInterpolant(s,B,'makima','none');

%This computes an interpolated function for the static default boundary
BoundstatInterp = griddedInterpolant(s,Bounds0,'makima','none');

%This randomly draws the starting point for xA and xB from a uniform distribution
for j=1:Nsim
    xA0(j) = unifrnd(xAl,xAu);
    %xB0(j) = xA0(j)*((1/s0)-1); %This defines the starting value of XB from s0
    xB0(j) = unifrnd(xAl,xAu);
end

%This computes the time grid
t=linspace(0,Tmax,Nt);
dt=t(2)-t(1);

%This creates random path for each simulation
phixA = normrnd(0,1,Nt,Nsim);
phixBPerp = normrnd(0,1,Nt,Nsim);
phixB = rho*phixA + sqrt(1-rho^2)*phixBPerp;

%This simulates exactly for the actual boundary
for j=1:Nsim
    xA(1,j) = xA0(j);
    xB(1,j) = xB0(j);
    sims(1,j) = xA0(j)/(xA0(j)+xB0(j));
    for i=2:Nt
        if xA(i-1,j)==0 || xA(i-1,j)<BoundInterp(sims(i-1,j))
            xA(i,j) = 0;
            DefA(i,j) = 1;
        else 
            xA(i,j) = xA(i-1,j)*exp((mu-sig^2/2)*dt+sig*sqrt(dt)*phixA(i,j));
            DefA(i,j) = 0;
        end
        if xB(i-1,j)==0 || xB(i-1,j)<BoundInterp(1-sims(i-1,j))
            xB(i,j) = 0;
            DefB(i,j) = 1;
        else 
            xB(i,j) = xB(i-1,j)*exp((muB-sigB^2/2)*dt+sigB*sqrt(dt)*phixB(i,j));
            DefB(i,j) = 0;
        end
        if xA(i,j)>0 || xB(i,j)>0
            sims(i,j) = xA(i,j)./(xA(i,j)+xB(i,j));
        else
            sims(i,j) = 0.5;
        end
    end
end

%This simulates exactly for the static boundary
for j=1:Nsim
    xAstat(1,j) = xA0(j);
    xBstat(1,j) = xB0(j);
    simsstat(1,j) = xA0(j)/(xA0(j)+xB0(j));
    for i=2:Nt
        if xAstat(i-1,j)==0 || xAstat(i-1,j)<BoundInterp(simsstat(1,j)) %This assumes that the static boundary is the stochastic one at s0
            xAstat(i,j) = 0;
            DefAstat(i,j) = 1;
        else 
            xAstat(i,j) = xAstat(i-1,j)*exp((mu-sig^2/2)*dt+sig*sqrt(dt)*phixA(i,j));
            DefAstat(i,j) = 0;
        end
        if xBstat(i-1,j)==0 || xBstat(i-1,j)<BoundInterp(1-simsstat(1,j)) %This assumes that the static boundary is the stochastic one at s0
            xBstat(i,j) = 0;
            DefBstat(i,j) = 1;
        else 
            xBstat(i,j) = xBstat(i-1,j)*exp((muB-sigB^2/2)*dt+sigB*sqrt(dt)*phixB(i,j));
            DefBstat(i,j) = 0;
        end
        if xAstat(i,j)>0 || xBstat(i,j)>0
            simsstat(i,j) = xAstat(i,j)./(xAstat(i,j)+xBstat(i,j));
        else
            simsstat(i,j) = 0.5;
        end
    end
end