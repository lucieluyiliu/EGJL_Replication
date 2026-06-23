%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function taking in an interpolated function InterpF and computing the %
% correlation accross trees A and B values of F for each simulations    %
% NOTE: This only works in the symmetric tree case                      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [CorF,FAsim,FBsim] = SimulatedCorrelation(xA,xB,sims,DefaultA,DefaultB,Nt,Nsim,Ny,Ns,y,InterpF)

s=linspace(0,1,Ns);

%Define (Y,S) grid
[Y,S] = ndgrid(y,s);

%This computes the Function surface of A (and B by symmetry)
for j=1:Ns
    for i=1:Ny
        F(i,j) = InterpF(y(i),s(j));
    end
end
FInterp = griddedInterpolant(Y,S,F,'makima','none');

%This computes the simulated values of F
for j=1:Nsim
    dFAsim(1,j)=0;
    dFBsim(1,j)=0;
    FAsim(1,j) = FInterp(log(xA(1,j)),sims(1,j));
    FBsim(1,j) = FInterp(log(xB(1,j)),1-sims(1,j));
    i=2;
    while i<Nt+1 & DefaultA(i,j)==0 & DefaultB(i,j)==0
        FAsim(i,j) = FInterp(log(xA(i,j)),sims(i,j));
        FBsim(i,j) = FInterp(log(xB(i,j)),1-sims(i,j));
        dFAsim(i,j) = FAsim(i,j)-FAsim(i-1,j);
        dFBsim(i,j) = FBsim(i,j)-FBsim(i-1,j);
        i=i+1;
    end
    imax(j)=i-1; %The last time both firms were alive in this simulation
end

for j=1:Nsim
    idxBothNonzero = FAsim(:,j) > 0 & FBsim(:,j) > 0;
    HH = corrcoef(dFAsim(idxBothNonzero,j),dFBsim(idxBothNonzero,j),'rows','complete'); %The 2 here is since the first innovation is zero and imax(j) to only include the periods were both firms are alive. The 'complete' also only uses rows where there are both numbers (removing NaNs)
    if(isnan(HH))
        CorF(j) = NaN;
    else
        CorF(j) = HH(1,2);
    end
end