%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to take in the given simulations of trees A and B and to      %
% compute the default times and default rates of the simulations.        %
% It also comutes theses quantites for a static boundary for comparison. %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [DefRateA,DefRateB,JDefRate,DefRateAstat,DefRateBstat,JDefRatestat,DefRateRatio,DefTimeA,DefTimeB,DefTimeAstat,DefTimeBstat] = DefaultTimes(t,DefA,DefB,DefAstat,DefBstat,Nsim)

%Calculating the default time and joint default indicator for the full boundary
for j=1:Nsim
    if max(DefA(:,j))==0
        DefTimeA(j) = NaN;
    else
        DefTimeA(j) = t(find(DefA(:,j),1,'first'));
    end
    if max(DefB(:,j))==0
        DefTimeB(j) = NaN;
    else
        DefTimeB(j) = t(find(DefB(:,j),1,'first'));
    end
    if max(DefA(:,j))>0 & max(DefB(:,j))>0
        JointDef(j) = 1;
    else
        JointDef(j) = 0;
    end
end

for k=1:10
    DefRateA(k) = (sum(DefTimeA(:)>0)-sum(DefTimeA(:)>k))/Nsim; %k-year default rate for A
    DefRateB(k) = (sum(DefTimeB(:)>0)-sum(DefTimeB(:)>k))/Nsim; %k-year default rate for B
end

JDefRate = sum(JointDef)/Nsim;


%Calculating default time and joint default indicator for a fixed boundary
for j=1:Nsim
    if max(DefAstat(:,j))==0
        DefTimeAstat(j) = NaN;
    else
        DefTimeAstat(j) = t(find(DefAstat(:,j),1,'first'));
    end
    if max(DefBstat(:,j))==0
        DefTimeBstat(j) = NaN;
    else
        DefTimeBstat(j) = t(find(DefBstat(:,j),1,'first'));
    end
    if max(DefAstat(:,j))>0 & max(DefBstat(:,j))>0
        JointDefstat(j) = 1;
    else
        JointDefstat(j) = 0;
    end
end

for k=1:10
    DefRateAstat(k) = (sum(DefTimeAstat(:)>0)-sum(DefTimeAstat(:)>k))/Nsim; %k-year default rate for A
    DefRateBstat(k) = (sum(DefTimeBstat(:)>0)-sum(DefTimeBstat(:)>k))/Nsim; %k-year default rate for B
end

JDefRatestat = sum(JointDefstat)/Nsim;

DefRateRatio = JDefRate/JDefRatestat; %This computes the relate ratio of the joint default rate with increasing boundary