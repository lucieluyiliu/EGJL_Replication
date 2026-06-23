%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function taking in the interpolated default boundary 'BoundInterp' and  %
% computing the DD correlation accross trees A and B for each simulations %
% NOTE: This only works in the symmetric tree case                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CorDD,DDAsim,DDBsim] = SimulatedCorrelationDD_nodef(xA,xB,sims,DefaultA,DefaultB,Nt,Nsim,sig,sigB,BoundInterp)

%This computes the simulated values of DD for stochastic boundary
for j=1:Nsim
    dDDAsim(1,j)=0;
    dDDBsim(1,j)=0;
    BoundA(1,j) = BoundInterp(sims(1,j));
    BoundB(1,j) = BoundInterp(1-sims(1,j));
    DDAsim(1,j) = log(xA(1,j)/BoundA(1,j))/sig;
    DDBsim(1,j) = log(xB(1,j)/BoundB(1,j))/sigB;
    i=2;
    while i<Nt+1 & DefaultA(i,j)==0 & DefaultB(i,j)==0
        BoundA(i,j) = BoundInterp(sims(i,j));
        BoundB(i,j) = BoundInterp(1-sims(i,j));
        DDAsim(i,j) = log(xA(i,j)/BoundA(i,j))/sig;
        DDBsim(i,j) = log(xB(i,j)/BoundB(i,j))/sigB;
        dDDAsim(i,j) = DDAsim(i,j)-DDAsim(i-1,j);
        dDDBsim(i,j) = DDBsim(i,j)-DDBsim(i-1,j);
        i=i+1;
    end
    imax(j)=i-1; %The last time both firms were alive in this simulation
end

for j=1:Nsim
    idxBothNonzero = DDAsim(:,j) > 0 & DDBsim(:,j) > 0; %This identifies the i values where both are nonzero
    HH = corrcoef(dDDAsim(idxBothNonzero,j),dDDBsim(idxBothNonzero,j),'rows','complete'); %The 2 here is since the first innovation is zero and imax(j) to only include the periods were both firms are alive. The 'complete' also only uses rows where there are both numbers (removing NaNs)
    if(isnan(HH))
        CorDD(j) = NaN;
    else
        CorDD(j) = HH(1,2);
    end
end