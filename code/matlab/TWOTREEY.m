%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function calculates the debt and equity value (with boundary) on an    %
% Nx by Ns grid with the given inputs using the PSOR finite-difference method %
% NOTE: Needs the function vcoch.m                                            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [v,d,Bound] = TWOTREEY(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost,c,m,p,omega0,q)

%definition
y=linspace(ymin,ymax,Ny);
s=linspace(0,1,Ns);
dy=y(2)-y(1);
ds=s(2)-s(1);

%computed parameters
eta=sqrt(sig*sig+sigB*sigB-2*rho*sig*sigB);
nu=muB-mu-0.5*sigB*sigB+0.5*sig*sig;
psi=sqrt(nu*nu+2*del*eta*eta);
thet=(nu+psi)/(eta*eta);
gamm=(nu-psi)/(eta*eta);

%Inputs
tol=0.000001;
rhoparam1=100000;
rhoparam2=100/tol;

%Input functions
Bound=zeros(Ns,1);
A=zeros(Ny,Ns);
B=zeros(Ny,Ns);
C=zeros(Ny,Ns);
F=zeros(Ny,Ns);
G=zeros(Ny,Ns);
H=zeros(Ny,Ns);
HD=zeros(Ny,Ns);
Cpp=zeros(Ny,Ns);
Cp0=zeros(Ny,Ns);
Cpm=zeros(Ny,Ns);
C0p=zeros(Ny,Ns);
C00=zeros(Ny,Ns);
C0m=zeros(Ny,Ns);
Cmp=zeros(Ny,Ns);
Cm0=zeros(Ny,Ns);
Cmm=zeros(Ny,Ns);
state=zeros(Ny,Ns);
lambda=zeros(Ns,1);

for j=1:Ns
    lambda(j)=del+mu*s(j)+muB*(1-s(j))-sig*sig*s(j)*s(j)-sigB*sigB*(1-s(j))*(1-s(j))-2*rho*sig*sigB*s(j)*(1-s(j));
    for i=1:Ny
        A(i,j)=0.5*sig*sig;
        B(i,j)=0.5*eta*eta*s(j)*s(j)*(1-s(j))*(1-s(j));
        C(i,j)=sig*(sig-rho*sigB)*s(j)*(1-s(j));
        F(i,j)=mu-rho*sig*sigB-0.5*sig*sig-sig*(sig-rho*sigB)*s(j); %This extra 0.5*sig*sig is for the transform to y=log(x)
        G(i,j)=s(j)*(1-s(j))*(mu-muB-sig*sig*s(j)+sigB*sigB*(1-s(j))+2*(s(j)-0.5)*rho*sig*sigB+eta*eta*(1-s(j))-sig*(sig-rho*sigB));
        Cpp(i,j)=C(i,j)/(4*dy*ds);
        Cp0(i,j)=A(i,j)/(dy*dy)+F(i,j)/(2*dy);
        Cpm(i,j)=-C(i,j)/(4*dy*ds);
        C0p(i,j)=B(i,j)/(ds*ds)+G(i,j)/(2*ds);
        C00(i,j)=2*A(i,j)/(dy*dy)+2*B(i,j)/(ds*ds)+lambda(j); %This is corrected for in the interior loop (to adjust for debt's different discount rate
        C0m(i,j)=B(i,j)/(ds*ds)-G(i,j)/(2*ds);
        Cmp(i,j)=-C(i,j)/(4*dy*ds);
        Cm0(i,j)=A(i,j)/(dy*dy)-F(i,j)/(2*dy);
        Cmm(i,j)=C(i,j)/(4*dy*ds);
    end
end

%Create an initial guess for the solution
v=zeros(Ny,Ns);
d=zeros(Ny,Ns);

%%Boundary conditions
%Left BC (y=ymin)
i=1;
for j=1:Ns
    v(i,j)=0;
    d(i,j)=0;
end

%Bottom BC (s=0)
rB=del+muB-sigB*sigB;
betarb=(0.5*sig*sig-(mu-rho*sig*sigB)-sqrt(2*rB*sig*sig+((mu-rho*sig*sigB)-0.5*sig*sig)*(((mu-rho*sig*sigB))-0.5*sig*sig)))/(sig*sig);
betarbm=(0.5*sig*sig-(mu-rho*sig*sigB)-sqrt(2*(rB+m)*sig*sig+((mu-rho*sig*sigB)-0.5*sig*sig)*(((mu-rho*sig*sigB))-0.5*sig*sig)))/(sig*sig);
v0=1/(del+nu-0.5*eta*eta);
B0=(1/((1-phi)*v0*(1-q-((cost-q)*betarb)-((1-cost)*betarbm))))*((phi*c*betarb/rB)-((c+m*p)*betarbm/(rB+m)));
j=1;
for i=1:Ny
    if exp(y(i))>B0
        v(i,j)=(1-phi)*exp(y(i))*v0+phi*c/rB-((phi*c/rB)+(cost-q)*(1-phi)*B0*v0)*(exp(y(i))/B0)^(betarb)-((c+m*p)/(rB+m))-((1-cost)*(1-phi)*B0*v0-((c+m*p)/(rB+m)))*(exp(y(i))/B0)^(betarbm);
        d(i,j)=(c+m*p)/(rB+m)+((1-cost)*(1-phi)*B0*v0-((c+m*p)/(rB+m)))*(exp(y(i))/B0)^(betarbm);
    else
        v(i,j)=q*(1-phi)*exp(y(i))*v0;
        d(i,j)=(1-cost)*(1-phi)*exp(y(i))*v0;
    end
end

%Top BC (s=1)
r=del+mu-sig*sig;
betar=(0.5*sig*sig-(mu-sig*sig)-sqrt(2*r*sig*sig+((mu-sig*sig)-0.5*sig*sig)*((mu-sig*sig)-0.5*sig*sig)))/(sig*sig);
betarm=(0.5*sig*sig-(mu-sig*sig)-sqrt(2*(r+m)*sig*sig+((mu-sig*sig)-0.5*sig*sig)*((mu-sig*sig)-0.5*sig*sig)))/(sig*sig);
B1=(del/((1-phi)*(1-q-(cost-q)*betar-(1-cost)*betarm)))*((phi*c*betar)/r-(c+m*p)*betarm/(r+m));
j=Ns;
for i=1:Ny
    if exp(y(i))>B1
        v(i,j)=(1-phi)*exp(y(i))/del+phi*c/r-(phi*c/r+(cost-q)*(1-phi)*B1/del)*(exp(y(i))/B1)^(betar)-((c+m*p)/(r+m))-((1-cost)*(1-phi)*B1/del-((c+m*p)/(r+m)))*(exp(y(i))/B1)^(betarm);
        d(i,j)=(c+m*p)/(r+m)+((1-cost)*(1-phi)*B1/del-((c+m*p)/(r+m)))*(exp(y(i))/B1)^(betarm);
    else
        v(i,j)=q*(1-phi)*exp(y(i))/del;
        d(i,j)=(1-cost)*(1-phi)*exp(y(i))/del;
    end
end


%Right BC (y=ymax)
nur=(muB-rho*sig*sigB)-(mu-sig*sig)-0.5*sigB*sigB+0.5*sig*sig;
psir=sqrt(nur*nur+2*r*eta*eta);
thetr=(nur+psir)/(eta*eta);
gammr=(nur-psir)/(eta*eta);

nurm=(muB-rho*sig*sigB)-(mu-sig*sig)-0.5*sigB*sigB+0.5*sig*sig;
psirm=sqrt(nurm*nurm+2*(r+m)*eta*eta);
thetrm=(nurm+psirm)/(eta*eta);
gammrm=(nurm-psirm)/(eta*eta);

vc=zeros(Ns,1);
vcr=zeros(Ns,1);
vcrm=zeros(Ns,1);

%This defines the v(s) function from Cochrane
[vc] = vcoch(Ns,del,gamm,nu,eta,thet,psi);
[vcr] = vcoch(Ns,r,gammr,nur,eta,thetr,psir);
[vcrm] = vcoch(Ns,r+m,gammrm,nurm,eta,thetrm,psirm);

i=Ny;
for j=1:Ns
    v(i,j)=(1-phi)*exp(y(i))*vc(j)+phi*c*vcr(j)-(c+m*p)*vcrm(j);
    d(i,j)=(c+m*p)*vcrm(j);
end

%Liebmann's method
%Loop over iterations
err=1;
iter=0;
while (err > tol)
    
    if iter<500
        omega=1.5;
    else
        omega=omega0;
    end
    
    %This defines the penalty for equity and debt
    for j=1:Ns
        for i=1:Ny
            H(i,j)=(1-phi)*(exp(y(i))-c)+m*(d(i,j)-p);
            rhohat(i,j)=rhoparam2/(1+exp(rhoparam1*(y(i)-Bound(j))));
            HD(i,j)=c+m*p+(1-cost)*(1-phi)*exp(y(i))*vc(j)*rhohat(i,j);
        end
    end
    
    %Loop over interior grid points
    err=0;
    for j=2:Ns-1            %Loop over s-direction, skipping first and last grid points
        for i=2:Ny-1        %Loop over x-direction, skipping first and last grid points
            vtemp(i,j)=v(i,j);
            v(i,j)=(Cpp(i,j)*v(i+1,j+1)+Cp0(i,j)*v(i+1,j)+Cpm(i,j)*v(i+1,j-1)+C0p(i,j)*v(i,j+1)+C0m(i,j)*v(i,j-1)+Cmp(i,j)*v(i-1,j+1)+Cm0(i,j)*v(i-1,j)+Cmm(i,j)*v(i-1,j-1)+H(i,j))/C00(i,j);
            v(i,j)=vtemp(i,j)+omega*(v(i,j)-vtemp(i,j)); %This is the SOR bit in PSOR
            dtemp(i,j)=d(i,j);
            d(i,j)=(Cpp(i,j)*d(i+1,j+1)+Cp0(i,j)*d(i+1,j)+Cpm(i,j)*d(i+1,j-1)+C0p(i,j)*d(i,j+1)+C0m(i,j)*d(i,j-1)+Cmp(i,j)*d(i-1,j+1)+Cm0(i,j)*d(i-1,j)+Cmm(i,j)*d(i-1,j-1)+HD(i,j))/(C00(i,j)+m+rhohat(i,j));
            d(i,j)=dtemp(i,j)+omega*(d(i,j)-dtemp(i,j)); %This is the SOR bit in PSOR
            if v(i,j)<q*(1-phi)*exp(y(i))*vc(j) %This is the P bit in PSOR
               v(i,j)=q*(1-phi)*exp(y(i))*vc(j);
               state(i,j)=0;
            else
               state(i,j)=1;
            end
            err=err+abs(v(i,j)-vtemp(i,j))+abs(d(i,j)-dtemp(i,j));
        end
    end
    
    %This finds the boundary for this iteration
    Bound(1)=log(B0);
    for j=2:Ns-1
        for i=1:Ny-2
            if v(i,j)==q*(1-phi)*exp(y(i))*vc(j)
            Bound(j)=y(i);
            %Bound(j)=x(i)+dx*((v(i+2,j)-2*v(i+1,j))/(v(i+2,j)-v(i+1,j))); %First order approximation (the 3 should be a 2  but works better with 3?!)
            end
        end
    end
    Bound(Ns)=log(B1);
    
    iter=iter+1;
    if mod(100000,iter)==0
        fprintf('%s: Error is %s with %d iterations\n',rho,err,iter);
    end
    
    %This exits if error blows up to 10E^12
    if err>1000000000000
        break
    end
end
fprintf('%s: Converged with error equal to %s in %d iterations\n',rho,err,iter); 

%This loop finds the boundary
for j=1:Ns
    for i=1:Ny-2
        if v(i,j)==q*(1-phi)*exp(y(i))*vc(j)
            Bound(j)=exp(y(i));
        end
    end
end

end