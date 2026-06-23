%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function taking in the interpolated default boundary 'BoundInterp' and  %
% computing the DD correlation accross trees A and B for each simulations %
% assuming that the boundary stays fixed (static) at b(0.5)               %
% NOTE: This only works in the symmetric tree case                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CorDD,DDAsim,DDBsim] = SimulatedCorrelationDDstat(xA,xB,sims,DefaultA,DefaultB,Nt,Nsim,sig,sigB,BoundInterp)

%This computes the simulated values of DD for stochastic boundary
for j=1:Nsim
    dDDAsim(1,j)=0;
    dDDBsim(1,j)=0;
    BoundA(j) = BoundInterp(sims(1,j));
    BoundB(j) = BoundInterp(1-sims(1,j));
    DDAsim(1,j) = log(xA(1,j)/BoundA(j))/sig;
    DDBsim(1,j) = log(xB(1,j)/BoundB(j))/sigB;
    i=2;
    while i<Nt+1 & DefaultA(i,j)==0 & DefaultB(i,j)==0
        DDAsim(i,j) = log(xA(i,j)/BoundA(j))/sig;
        DDBsim(i,j) = log(xB(i,j)/BoundB(j))/sigB;
        dDDAsim(i,j) = DDAsim(i,j)-DDAsim(i-1,j);
        dDDBsim(i,j) = DDBsim(i,j)-DDBsim(i-1,j);
        i=i+1;
    end
    imax(j)=i-1; %The last time both firms were alive in this simulation
end

for j=1:Nsim
    HH = corrcoef(dDDAsim(2:imax(j),j),dDDBsim(2:imax(j),j));
    CorDD(j) = HH(1,2);
end