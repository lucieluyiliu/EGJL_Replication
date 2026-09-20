%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function computes the unlevered equity/asset value for the % 
% interest-rate counterfactual.                                   %
% NOTE: rbarMode of 0 gives rbar = r(0) and 1 gives rbar = r(1).  %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [U_count, rbar] = UnleveredEquity_count(Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,rbarMode)

   % If rbarMode is omitted, default to r(0)
   if nargin < 12
       rbarMode = 0;
   end

   % Grids
   y  = linspace(ymin,ymax,Ny)';
   x  = exp(y);
   ss = linspace(0,1,Ns)';
   dss = ss(2)-ss(1);

   % Parameters
   eta2 = sig^2 + sigB^2 - 2*rho*sig*sigB;

   r0 = del + muB - sigB^2;
   r1 = del + mu  - sig^2;

   if rbarMode == 0
       rbar = r0;
   elseif rbarMode == 1
       rbar = r1;
   else
       rbar = rbarMode;
   end

   % Counterfactual vc(s)
   %
   % vc solves:
   %
   %   Baux vc'' + (Gaux + Caux) vc'
   %   + (mu_x - rbar) vc + 1 = 0
   %
   % equivalently:
   %
   %   Baux vc'' + (Gaux + Caux) vc'
   %   + (mu_x - rbar) vc = -1
  
   Baux = 0.5*eta2.*ss.^2.*(1-ss).^2;

   Caux = sig*(sig-rho*sigB).*ss.*(1-ss);

   Gaux = ss.*(1-ss).*(mu-muB-sig^2.*ss+sigB^2.*(1-ss) ...
        + 2*(ss-0.5)*rho*sig*sigB ...
        + eta2*(1-ss) - sig*(sig-rho*sigB));

   mu_x = mu - rho*sig*sigB - sig*(sig-rho*sigB).*ss;

   mu_x0 = mu - rho*sig*sigB;
   mu_x1 = mu - sig^2;

   % Endpoint conditions
   vc0 = 1/(rbar - mu_x0);
   vc1 = 1/(rbar - mu_x1);

   vc_count = solve_ode_1d_nested( ...
       ss, dss, Baux, Gaux+Caux, mu_x-rbar, -ones(Ns,1), vc0, vc1);

   % Construct U_count(x,s)
   U_count = zeros(Ny,Ns);

   for j = 1:Ns
       U_count(:,j) = (1-phi) * x * vc_count(j);
   end

   % Nested finite-difference ODE solver
   function f = solve_ode_1d_nested(ss,dss,A2,A1,A0,rhs,leftValue,rightValue)
        % Solves:
        %
        %   A2(s) f'' + A1(s) f' + A0(s) f = rhs(s)
        %
        % with Dirichlet boundary conditions:
        %
        %   f(0) = leftValue
        %   f(1) = rightValue

        n = length(ss)-2;

        lower = zeros(n,1);
        diagv = zeros(n,1);
        upper = zeros(n,1);
        bvec  = rhs(2:end-1);

        for kk = 1:n
            jj = kk+1;

            ajm =  A2(jj)/dss^2 - A1(jj)/(2*dss);
            aj0 = -2*A2(jj)/dss^2 + A0(jj);
            ajp =  A2(jj)/dss^2 + A1(jj)/(2*dss);

            lower(kk) = ajm;
            diagv(kk) = aj0;
            upper(kk) = ajp;
        end

        % Boundary adjustments
        bvec(1)   = bvec(1)   - lower(1)*leftValue;
        bvec(end) = bvec(end) - upper(end)*rightValue;

        M = spdiags([[lower(2:end);0], diagv, [0;upper(1:end-1)]], ...
                    [-1,0,1], n, n);

        fInterior = M\bvec;

        f = zeros(length(ss),1);
        f(1) = leftValue;
        f(end) = rightValue;
        f(2:end-1) = fInterior;
   end

end