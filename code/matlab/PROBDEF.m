%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function calculates the probability of default for a given boundary 'Bound' %
% on an Nx by Ns grid for Nt timesteps (over Tmax) with the given inputs using the %
% PSOR finite-difference method                                                    %
% Note: the input Q should be 0 for probability under P and 1 for under Q          %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [v] = PROBDEF(Bound,Ny,Ns,Nt,Tmax,ymin,ymax,sig,sigB,rho,mu,muB,omega0,Q)

%definition
y=linspace(ymin,ymax,Ny); %This solves on the grid that starts at the boundary for Bound(s=0)
s=linspace(0,1,Ns);
t=linspace(0,Tmax,Nt);
dy=y(2)-y(1);
ds=s(2)-s(1);
dt=t(2)-t(1);

%s(1)=0.0000001; %This to stop expression blowing up at s=0

%Inputs
eta=sqrt(sig*sig+sigB*sigB-2*rho*sig*sigB);
tol=0.000001;
rhoparam1=100000; %This was 100000 in Yerkin's work
rhoparam2=100/tol;
lambda=0; %There is no discounting in probably problem but it is in the FD for fucture proofing

%Input functions
A=zeros(Ny,Ns);
B=zeros(Ny,Ns);
C=zeros(Ny,Ns);
F=zeros(Ny,Ns);
G=zeros(Ny,Ns);
H=zeros(Ny,Ns);
Cpp=zeros(Ny,Ns);
Cp0=zeros(Ny,Ns);
Cpm=zeros(Ny,Ns);
C0p=zeros(Ny,Ns);
C00=zeros(Ny,Ns);
C0m=zeros(Ny,Ns);
Cmp=zeros(Ny,Ns);
Cm0=zeros(Ny,Ns);
Cmm=zeros(Ny,Ns);
Dvk=zeros(Ny,Ns);

%This is the stencil for Crank Nicholson finite difference with time derivative (there is a 1/dt and coefficients are half of what they are in the perpetual case)
for j=1:Ns
    for i=1:Ny
        if Q == 1 
            A(i,j)=0.5*sig*sig;
            B(i,j)=0.5*eta*eta*s(j)*s(j)*(1-s(j))*(1-s(j));
            C(i,j)=sig*(sig-rho*sigB)*s(j)*(1-s(j));
            F(i,j)=mu-rho*sig*sigB-0.5*sig*sig-sig*(sig-rho*sigB)*s(j); %This extra 0.5*sig*sig is for the transform to y=log(x)
            G(i,j)=s(j)*(1-s(j))*(mu-muB-sig*sig*s(j)+sigB*sigB*(1-s(j))+2*(s(j)-0.5)*rho*sig*sigB+eta*eta*(1-s(j))-sig*(sig-rho*sigB));
        else
            %The below is the diffusion under the physical probability measure (above it is the RN)
            A(i,j)=0.5*sig*sig;
            B(i,j)=0.5*eta*eta*s(j)*s(j)*(1-s(j))*(1-s(j));
            C(i,j)=sig*(sig-rho*sigB)*s(j)*(1-s(j));
            F(i,j)=mu-0.5*sig*sig; %This extra 0.5*sig*sig is for the transform to y=log(x)
            G(i,j)=s(j)*(1-s(j))*(mu-muB-sig*sig*s(j)+sigB*sigB*(1-s(j))+2*(s(j)-0.5)*rho*sig*sigB);
        end
        Cpp(i,j)=C(i,j)/(8*dy*ds);
        Cp0(i,j)=A(i,j)/(2*dy*dy)+F(i,j)/(4*dy);
        Cpm(i,j)=-C(i,j)/(8*dy*ds);
        C0p(i,j)=B(i,j)/(2*ds*ds)+G(i,j)/(4*ds);
        C00(i,j)=1/dt+A(i,j)/(dy*dy)+B(i,j)/(ds*ds)+lambda/2; %This is corrected for in the interior loop (to adjust for penalty due to boundary)
        C0m(i,j)=B(i,j)/(2*ds*ds)-G(i,j)/(4*ds);
        Cmp(i,j)=-C(i,j)/(8*dy*ds);
        Cm0(i,j)=A(i,j)/(2*dy*dy)-F(i,j)/(4*dy);
        Cmm(i,j)=C(i,j)/(8*dy*ds);
    end
end

%Creates the terminal solution, defaulted if x<b(s). This also sets the
%boundary conditions at i=Ny and j=Ns since we do not update these in the
%iteration
for j=1:Ns
    for i=1:Ny
        if exp(y(i))>Bound(j)
            v(i,j) = 0;
        else
            v(i,j) = 1;
        end
    end
end

%This computes the PD for the limiting cases s=0 and s=1 from PDEs (it gives the same results as the analytical solution below
%omega=1.8;
%[v0] = PROBDEF1D(Bound(1),Ny,Nt,Tmax,ymin,ymax,mu,sig,omega); %This computes the physical probabilty of default
%[v1] = PROBDEF1D(Bound(Ns),Ny,Nt,Tmax,ymin,ymax,mu,sig,omega); %This computes the physical probabilty of default

%This is the expression for the default probability as s->0 and s->1, based on Eq. (3.3.3) in JYC2008
for k=1:Nt
    for i=1:Ny
        if Q==1
            %This is under Q
            v0(k,i) = min(normcdf((log(Bound(1))-y(i)-(mu-0.5*sig*sig-rho*sig*sigB)*t(k))/(sig*sqrt(t(k))))+((Bound(1)/exp(y(i)))^((2*mu/(sig*sig))-1-(2*rho*sigB/sig)))*normcdf(((mu-0.5*sig*sig-rho*sig*sigB)*t(k)+log(Bound(1))-y(i))/(sig*sqrt(t(k)))),1);
            v1(k,i) = min(normcdf((log(Bound(Ns))-y(i)-(mu-0.5*sig*sig-sig*sig)*t(k))/(sig*sqrt(t(k))))+((Bound(Ns)/exp(y(i)))^((2*mu/(sig*sig))-3))*normcdf(((mu-0.5*sig*sig-sig*sig)*t(k)+log(Bound(Ns))-y(i))/(sig*sqrt(t(k)))),1);
        else
            %This is under P
            v0(k,i) = min(normcdf((log(Bound(1))-y(i)-(mu-0.5*sig*sig)*t(k))/(sig*sqrt(t(k))))+((Bound(1)/exp(y(i)))^((2*mu/(sig*sig))-1))*normcdf(((mu-0.5*sig*sig)*t(k)+log(Bound(1))-y(i))/(sig*sqrt(t(k)))),1);
            v1(k,i) = min(normcdf((log(Bound(Ns))-y(i)-(mu-0.5*sig*sig)*t(k))/(sig*sqrt(t(k))))+((Bound(Ns)/exp(y(i)))^((2*mu/(sig*sig))-1))*normcdf(((mu-0.5*sig*sig)*t(k)+log(Bound(Ns))-y(i))/(sig*sqrt(t(k)))),1);
        end
    end
end

%This loops over time
for k=1:Nt
   
    for i=1:Ny
        v(i,1) = v0(k,i); %This defines the boundary condition at s=0 (which changes every timestep)
        v(i,Ns) = v1(k,i); %This defines the boundary condition at s=1 (which changes every timestep)
    end
    
    %this sets vstar and vtemp to the previous timestep (only at the interior since boundary condition is fixed)
    for j=1:Ns
        for i=1:Ny
            vstar(i,j) = v(i,j);
        end 
    end
    
    %This defines the penalty for probability of default
    for j=1:Ns
        for i=1:Ny
            %rhohat(i,j)=0;
            rhohat(i,j)=rhoparam2/(1+exp(rhoparam1*(exp(y(i))-Bound(j))));
            H(i,j)=rhohat(i,j);
        end
    end
    
    %This defines the required values at the previous timestep
    for j=2:Ns-1
        for i=2:Ny-1
            Dvyyk(i,j)=(v(i+1,j)-2*v(i,j)+v(i-1,j))/(dy*dy);
            Dvssk(i,j)=(v(i,j+1)-2*v(i,j)+v(i,j-1))/(ds*ds);
            Dvysk(i,j)=(v(i+1,j+1)-v(i+1,j-1)-v(i-1,j+1)+v(i-1,j-1))/(4*dy*ds);
            Dvyk(i,j)=(v(i+1,j)-v(i-1,j))/(2*dy);
            Dvsk(i,j)=(v(i,j+1)-v(i,j-1))/(2*ds);
            delvk(i,j)=0.5*(A(i,j)*Dvyyk(i,j)+B(i,j)*Dvssk(i,j)+C(i,j)*Dvysk(i,j)+F(i,j)*Dvyk(i,j)+G(i,j)*Dvsk(i,j)-(lambda-(2/dt))*v(i,j));
        end
    end
               
    
    %Loop over iterations
    err=1;
    iter=0;
    while (err > tol)
    
        if iter<500
            omega=1.5;
        else
            omega=omega0;
        end
      
        %Loop over interior grid points
        err=0;
        for j=2:Ns-1            %Loop over s-direction, skipping first and last grid points
            for i=2:Ny-1        %Loop over x-direction, skipping first and last grid points
                vtemp(i,j)=vstar(i,j);
                vstar(i,j)=(Cpp(i,j)*vstar(i+1,j+1)+Cp0(i,j)*vstar(i+1,j)+Cpm(i,j)*vstar(i+1,j-1)+C0p(i,j)*vstar(i,j+1)+C0m(i,j)*vstar(i,j-1)+Cmp(i,j)*vstar(i-1,j+1)+Cm0(i,j)*vstar(i-1,j)+Cmm(i,j)*vstar(i-1,j-1)+H(i,j)+delvk(i,j))/(C00(i,j)+rhohat(i,j));
                vstar(i,j)=vtemp(i,j)+omega*(vstar(i,j)-vtemp(i,j)); %This is the SOR bit in PSOR
                %The following stops noise in the solution at y=0
                if vstar(i,j) > 1
                    vstar(i,j) = 1;
                end
                err=err+abs(vstar(i,j)-vtemp(i,j));
                
            end
        end
        
        iter=iter+1;
        if mod(100000,iter)==0
            %fprintf('Error is %s with %d iterations\n',err,iter); %prints error each iteration
        end
    end
    
    %this defines v as the (converged) vstar
    for j=1:Ns
        for i=1:Ny
            v(i,j) = vstar(i,j);
        end
    end
  
    fprintf('Timestep %d: converged with error %s in %d iterations\n',k,err,iter); 
    
end

end