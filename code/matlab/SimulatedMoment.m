%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function taking in an interpolated function InterpF and computing the %
% values of this function for trees A and B along the simulation paths  %
% NOTE: This only works in the symmetric tree case                      %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [FAsim,FBsim] = SimulatedMoment(xA,xB,sims,DefaultA,DefaultB,Nt,Nsim,Ny,Ns,y,InterpF)

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
    FAsim(1,j) = FInterp(log(xA(1,j)),sims(1,j));
    FBsim(1,j) = FInterp(log(xB(1,j)),1-sims(1,j));
    i=2;
    while i<Nt+1 & DefaultA(i,j)==0 & DefaultB(i,j)==0
        FAsim(i,j) = FInterp(log(xA(i,j)),sims(i,j));
        FBsim(i,j) = FInterp(log(xB(i,j)),1-sims(i,j));
        i=i+1;
    end
    imax(j)=i-1; %The last time both firms were alive in this simulation
end