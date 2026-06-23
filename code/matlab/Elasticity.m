%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function to estimate the slope (elasticity) of the default boundary at a given point %
% NOTE: Needs the function polyfix.m                                                   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [Bprime BprimeFit,jmin,jmax,F] = Elasticity(B,Ns,smin,smax,jdelfit,jdel,order)

s=linspace(0,1,Ns);
ds=s(2)-s(1);

jmin = round(smin/ds)+1; 
jmax = round(smax/ds)+1; 

%This fits a polynomial of order 'order' to the points between +/- jdelfit
%and then computes derivative from +/- jdel
for j=jmin:jmax
    p = polyfix(s(j-jdelfit:j+jdelfit),B(j-jdelfit:j+jdelfit),order,[s(j)],[B(j)]);
    BFit = polyval(p,s);
    BprimeFit(j) = (BFit(j+jdel)-BFit(j-jdel))/(2*jdel*ds);
    F(j) = -s(j)*(1-s(j))*BprimeFit(j)/BFit(j);
end

%This numerically computes the derivative of the boundary from +/- jdel
%(without any fitting)
for j=jmin:jmax
    Bprime(j) = (B(j+jdel)-B(j-jdel))/(2*jdel*ds);
end


%plot(s(jmin:jmax),Bprime(jmin:jmax),'.')
%hold on
%plot(s(jmin:jmax),BprimeFit(jmin:jmax))
