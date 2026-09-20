%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This function calculates the fixed-interest rate counterfactuals for the %
% debt and equity values on an Nx by Ns grid (via PSOR).                   %
% The counterfactual valuation keeps the risk-premium channel on but       % 
% replaces r(s) with a constant rbar. The default boundary is frozen at    %
% BoundX(s), supplied in x-space as the solution of the full problem.      %
% NOTE: rbarMode of 0 gives rbar = r(0) and 1 gives rbar = r(1)            %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [v,d,info] = Counterfactual(BoundX,Ny,Ns,ymin,ymax,sig,sigB,rho,del,mu,muB,phi,cost,c,m,p,omega0,q,rbarMode)
% Define the Grid
y  = linspace(ymin,ymax,Ny)';
s  = linspace(0,1,Ns);
dy = y(2)-y(1);
ds = s(2)-s(1);

BoundX = BoundX(:);
if length(BoundX) ~= Ns
    error('BoundX must have length Ns.');
end
BoundY = log(BoundX);

%Parameters
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

tol     = 1e-6;
maxIter = 200000;

% Auxiliary functions vc(s), vcr(s), vcrm(s) under constant rbar
[vc,vcr,vcrm] = compute_auxiliary_constant_rate();

% Allocate coefficient arrays
A     = zeros(Ny,Ns);
Bcoef = zeros(Ny,Ns);
C     = zeros(Ny,Ns);
F     = zeros(Ny,Ns);
G     = zeros(Ny,Ns);

Cpp = zeros(Ny,Ns);
Cp0 = zeros(Ny,Ns);
Cpm = zeros(Ny,Ns);
C0p = zeros(Ny,Ns);
C00 = zeros(Ny,Ns);
C0m = zeros(Ny,Ns);
Cmp = zeros(Ny,Ns);
Cm0 = zeros(Ny,Ns);
Cmm = zeros(Ny,Ns);

% Build finite-difference coefficients
for j = 1:Ns

    sj = s(j);

    for i = 1:Ny

        A(i,j)     = 0.5*sig^2;
        Bcoef(i,j) = 0.5*eta2*sj^2*(1-sj)^2;
        C(i,j)     = sig*(sig-rho*sigB)*sj*(1-sj);

        % Full-model risk-premium-adjusted y-drift.
        % Risk-premium channel remains ON.
        F(i,j) = mu - rho*sig*sigB - 0.5*sig^2 ...
               - sig*(sig-rho*sigB)*sj;

        % Full-model risk-premium-adjusted s-drift.
        % Risk-premium channel remains ON.
        G(i,j) = sj*(1-sj)*(mu-muB-sig^2*sj+sigB^2*(1-sj) ...
               + 2*(sj-0.5)*rho*sig*sigB ...
               + eta2*(1-sj) - sig*(sig-rho*sigB));

        Cpp(i,j) =  C(i,j)/(4*dy*ds);
        Cp0(i,j) =  A(i,j)/(dy^2) + F(i,j)/(2*dy);
        Cpm(i,j) = -C(i,j)/(4*dy*ds);
        C0p(i,j) =  Bcoef(i,j)/(ds^2) + G(i,j)/(2*ds);

        % Interest-rate channel OFF:
        % use constant rbar instead of r(s_j).
        C00(i,j) =  2*A(i,j)/(dy^2) + 2*Bcoef(i,j)/(ds^2) + rbar;

        C0m(i,j) =  Bcoef(i,j)/(ds^2) - G(i,j)/(2*ds);
        Cmp(i,j) = -C(i,j)/(4*dy*ds);
        Cm0(i,j) =  A(i,j)/(dy^2) - F(i,j)/(2*dy);
        Cmm(i,j) =  C(i,j)/(4*dy*ds);

    end
end

% Initial guess
v = zeros(Ny,Ns);
d = zeros(Ny,Ns);

[v,d] = apply_edge_bcs(v,d);

% Iteration
err  = 1;
iter = 0;

while err > tol && iter < maxIter

    if iter < 500
        omega = 1.5;
    else
        omega = omega0;
    end

    err = 0;

    % Re-impose edge boundary conditions before each sweep
    [v,d] = apply_edge_bcs(v,d);

    % Enforce fixed default boundary on interior s-columns only
    for j = 2:Ns-1
        iDef = find(y <= BoundY(j),1,'last');
        if ~isempty(iDef)
            v(1:iDef,j) = q*(1-phi)*exp(y(1:iDef))*vc(j);
            d(1:iDef,j) = (1-cost)*(1-phi)*exp(y(1:iDef))*vc(j);
        end
    end

    % Interior update
    for j = 2:Ns-1
        for i = 2:Ny-1

            if y(i) <= BoundY(j)
                continue
            end

            % Rollover equity/debt payoffs
            H  = (1-phi)*(exp(y(i))-c) + m*(d(i,j)-p);
            HD = c + m*p;

            v_old = v(i,j);
            d_old = d(i,j);

            v_new = ( Cpp(i,j)*v(i+1,j+1) + Cp0(i,j)*v(i+1,j) + Cpm(i,j)*v(i+1,j-1) ...
                    + C0p(i,j)*v(i,j+1)   + C0m(i,j)*v(i,j-1) ...
                    + Cmp(i,j)*v(i-1,j+1) + Cm0(i,j)*v(i-1,j) + Cmm(i,j)*v(i-1,j-1) ...
                    + H ) / C00(i,j);

            d_new = ( Cpp(i,j)*d(i+1,j+1) + Cp0(i,j)*d(i+1,j) + Cpm(i,j)*d(i+1,j-1) ...
                    + C0p(i,j)*d(i,j+1)   + C0m(i,j)*d(i,j-1) ...
                    + Cmp(i,j)*d(i-1,j+1) + Cm0(i,j)*d(i-1,j) + Cmm(i,j)*d(i-1,j-1) ...
                    + HD ) / (C00(i,j) + m);

            v(i,j) = v_old + omega*(v_new - v_old);
            d(i,j) = d_old + omega*(d_new - d_old);

            err = err + abs(v(i,j)-v_old) + abs(d(i,j)-d_old);

        end
    end

    % Re-impose edge boundary conditions after each sweep
    [v,d] = apply_edge_bcs(v,d);

    % Re-impose frozen default boundary after sweep
    for j = 2:Ns-1
        iDef = find(y <= BoundY(j),1,'last');
        if ~isempty(iDef)
            v(1:iDef,j) = q*(1-phi)*exp(y(1:iDef))*vc(j);
            d(1:iDef,j) = (1-cost)*(1-phi)*exp(y(1:iDef))*vc(j);
        end
    end

    iter = iter + 1;

    if mod(iter,1000)==0
        fprintf('Iter %d, err = %.12g\n',iter,err);
    end

    if err > 1e12
        warning('Counter_InterestOff_OneFunction: divergence detected.');
        break
    end

end

fprintf('Interest-off counterfactual converged with error %.12g in %d iterations\n',err,iter);

% Info struct
info.rbar       = rbar;
info.r0         = r0;
info.r1         = r1;
info.vc         = vc;
info.vcr        = vcr;
info.vcrm       = vcrm;
info.y          = y;
info.s          = s;
info.iterations = iter;
info.error      = err;

% Nested function: compute vc, vcr, vcrm under constant rbar
    function [vcOut,vcrOut,vcrmOut] = compute_auxiliary_constant_rate()

        ss = linspace(0,1,Ns)';
        dss = ss(2)-ss(1);

        Baux = 0.5*eta2.*ss.^2.*(1-ss).^2;

        Caux = sig*(sig-rho*sigB).*ss.*(1-ss);

        Gaux = ss.*(1-ss).*(mu-muB-sig^2.*ss+sigB^2.*(1-ss) ...
             + 2*(ss-0.5)*rho*sig*sigB ...
             + eta2*(1-ss) - sig*(sig-rho*sigB));

        mu_x = mu - rho*sig*sigB - sig*(sig-rho*sigB).*ss;

        mu_x0 = mu - rho*sig*sigB;
        mu_x1 = mu - sig^2;

        % vc solves:
        % Baux vc'' + (Gaux+Caux) vc' + (mu_x-rbar) vc + 1 = 0
        vc0 = 1/(rbar - mu_x0);
        vc1 = 1/(rbar - mu_x1);

        vcOut = solve_ode_1d_nested( ...
            ss, dss, Baux, Gaux+Caux, mu_x-rbar, -ones(Ns,1), vc0, vc1);

        % vcr solves:
        % Baux h'' + Gaux h' - rbar h + 1 = 0
        vcrOut = solve_ode_1d_nested( ...
            ss, dss, Baux, Gaux, -rbar*ones(Ns,1), -ones(Ns,1), 1/rbar, 1/rbar);

        % vcrm solves:
        % Baux h'' + Gaux h' - (rbar+m) h + 1 = 0
        vcrmOut = solve_ode_1d_nested( ...
            ss, dss, Baux, Gaux, -(rbar+m)*ones(Ns,1), -ones(Ns,1), ...
            1/(rbar+m), 1/(rbar+m));

    end

% Nested function: solve a one-dimensional ODE by finite differences
    function f = solve_ode_1d_nested(ss,dss,A2,A1,A0,rhs,leftValue,rightValue)
        % Solves:
        %   A2(s) f'' + A1(s) f' + A0(s) f = rhs(s)
        % with Dirichlet endpoints.

        n = Ns-2;

        lower = zeros(n,1);
        diagv = zeros(n,1);
        upper = zeros(n,1);
        bvec  = rhs(2:Ns-1);

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

        M = spdiags([[lower(2:end);0], diagv, [0;upper(1:end-1)]], [-1,0,1], n, n);

        fInterior = M\bvec;

        f = zeros(Ns,1);
        f(1) = leftValue;
        f(end) = rightValue;
        f(2:end-1) = fInterior;

    end

% Nested function: apply edge boundary conditions
    function [vIn,dIn] = apply_edge_bcs(vIn,dIn)

        % -------------------------------------------------
        % Left BC: y = ymin
        % Assume ymin is sufficiently far in the default region.
        % -------------------------------------------------
        iLeft = 1;
        for jj = 1:Ns
            vIn(iLeft,jj) = q*(1-phi)*exp(y(iLeft))*vc(jj);
            dIn(iLeft,jj) = (1-cost)*(1-phi)*exp(y(iLeft))*vc(jj);
        end

        % -------------------------------------------------
        % Bottom BC: s = 0
        % Risk-premium channel ON, constant rbar.
        % Boundary frozen at BoundX(1).
        % -------------------------------------------------
        mu_x0 = mu - rho*sig*sigB;
        [E0,D0] = endpoint_fixed_barrier_nested(BoundX(1),mu_x0);

        vIn(:,1) = E0;
        dIn(:,1) = D0;

        % -------------------------------------------------
        % Top BC: s = 1
        % Risk-premium channel ON, constant rbar.
        % Boundary frozen at BoundX(Ns).
        % -------------------------------------------------
        mu_x1 = mu - sig^2;
        [E1,D1] = endpoint_fixed_barrier_nested(BoundX(Ns),mu_x1);

        vIn(:,Ns) = E1;
        dIn(:,Ns) = D1;

        % -------------------------------------------------
        % Right BC: y = ymax, excluding corners
        % -------------------------------------------------
        iRight = Ny;
        for jj = 2:Ns-1
            vIn(iRight,jj) = (1-phi)*exp(y(iRight))*vc(jj) ...
                           + phi*c*vcr(jj) ...
                           - (c+m*p)*vcrm(jj);

            dIn(iRight,jj) = (c+m*p)*vcrm(jj);
        end

    end

% Nested function: endpoint fixed-barrier formula
    function [E,D] = endpoint_fixed_barrier_nested(BarrierX,mu_x)

        beta  = negative_root_nested(mu_x,rbar);
        betam = negative_root_nested(mu_x,rbar+m);

        vcEnd = 1/(rbar - mu_x);

        Pdebt = (c + m*p)/(rbar + m);
        RecoveryAtBarrier = (1-cost)*(1-phi)*BarrierX*vcEnd;

        E = zeros(Ny,1);
        D = zeros(Ny,1);

        for ii = 1:Ny
            x = exp(y(ii));

            if x > BarrierX

                D(ii) = Pdebt + (RecoveryAtBarrier - Pdebt)*(x/BarrierX)^betam;

                E(ii) = (1-phi)*x*vcEnd + phi*c/rbar ...
                      - Pdebt ...
                      - (phi*c/rbar + (cost-q)*(1-phi)*BarrierX*vcEnd)*(x/BarrierX)^beta ...
                      - (RecoveryAtBarrier - Pdebt)*(x/BarrierX)^betam;

            else

                E(ii) = q*(1-phi)*x*vcEnd;
                D(ii) = (1-cost)*(1-phi)*x*vcEnd;

            end
        end

    end

% Nested function: negative characteristic root
    function beta = negative_root_nested(mu_x,R)
        % Negative root of:
        %   0.5 sig^2 beta(beta-1) + mu_x beta - R = 0

        beta = (0.5*sig^2 - mu_x ...
              - sqrt(2*R*sig^2 + (mu_x - 0.5*sig^2)^2)) / sig^2;

    end

end