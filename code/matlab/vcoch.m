%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Function computing the value V^i(s_t) in Equation 8 %
% and given by Equation A.5 in the online Appendix    %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [v] = vcoch(Ns,del,gamm,nu,eta,thet,psi)

%definitions
s=linspace(0,1,Ns);
ds=s(2)-s(1);

fun1 = @(y,g,w) (1-y).*w.^(-g)./(1-y+y.*w);
fun2 = @(y,t,w) y.*w.^(t-1)./(y+(1-y).*w);

v=zeros(Ns,1);
v(1)=1/(del+nu-0.5*eta*eta);
for j=2:Ns-1
    v(j)=integral(@(w) fun1(s(j),gamm,w),0,1)/(psi*(1-s(j)))+integral(@(w) fun2(s(j),thet,w),0,1)/(psi*s(j));
end
v(Ns)=1/del;