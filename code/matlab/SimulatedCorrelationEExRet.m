%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function taking in the interpolated equity value function and computing %
% the correlation between excess equity returns accross trees A and B     %
% NOTE: This only works in the symmetric tree case                        %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CorE,EAsim,EBsim] = SimulatedCorrelationEExRet(xA,xB,sims,DefaultA,DefaultB,Nt,Nsim,Ny,Ns,y,InterpE,r,tax,coupon,Tmax)

s=linspace(0,1,Ns);
dt=Tmax/Nt;

%Define (Y,S) grid
[Y,S] = ndgrid(y,s);

%This computes the Function surface of A (and B by symmetry)
for j=1:Ns
    for i=1:Ny
        E(i,j) = InterpE(y(i),s(j));
    end
end
EInterp = griddedInterpolant(Y,S,E,'makima','none');
rfInterp = griddedInterpolant(s,r,'makima','none');

%This computes the simulated values of E
for j=1:Nsim
    dEAsim(1,j)=0;
    dEBsim(1,j)=0;
    EAsim(1,j) = EInterp(log(xA(1,j)),sims(1,j));
    EBsim(1,j) = EInterp(log(xB(1,j)),1-sims(1,j));
    i=2;
    while i<Nt+1 & DefaultA(i,j)==0 & DefaultB(i,j)==0
        EAsim(i,j) = EInterp(log(xA(i,j)),sims(i,j));
        EBsim(i,j) = EInterp(log(xB(i,j)),1-sims(i,j));
        rEAsim(i,j) = ((EAsim(i,j)-EAsim(i-1,j)+(1-tax)*(xA(i,j)-coupon)*dt)/(EAsim(i-1,j)*dt))-rfInterp(sims(i,j));
        rEBsim(i,j) = ((EBsim(i,j)-EBsim(i-1,j)+(1-tax)*(xB(i,j)-coupon)*dt)/(EBsim(i-1,j)*dt))-rfInterp(sims(i,j));
        i=i+1;
    end
    imax(j)=i-1; %The last time both firms were alive in this simulation
end

for j=1:Nsim
    idxBothNonzero = xA(:,j) > 0 & xB(:,j) > 0;
    HHE = corrcoef(rEAsim(idxBothNonzero,j),rEBsim(idxBothNonzero,j),'rows','complete'); %The 2 here is since the first innovation is zero and imax(j) to only include the periods were both firms are alive. The 'complete' also only uses rows where there are both numbers (removing NaNs)
    if(isnan(HHE))
        CorE(j) = NaN;
    else
        CorE(j) = HHE(1,2);
    end
end