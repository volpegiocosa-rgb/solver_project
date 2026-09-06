function x_rep = arch_repair(x, con_fun, eps_eq, Cinv)
% ARCH_REPAIR  Repair operator di ARCH (rif. CLAUDE.md S5.2, S3.1, S10 codice autori).
%   Proietta un candidato infeasible x verso il punto feasible piu' vicino (in
%   metrica di Mahalanobis rispetto a Cinv, o euclidea se Cinv omessa) risolvendo
%   un sotto-problema di ottimo vincolato via SQP. Applicabile perche' i vincoli
%   sono economici (rif. CLAUDE.md S4).
%
%   ECCEZIONE A CLAUDE.md S2 (decisione utente, rif. octave_toolbox_required.md):
%   il repair generale (con cineq futuri, non solo uguaglianze) richiede un
%   risolutore NLP vincolato generico, non riproducibile con un semplice
%   Gauss-Newton. Su Octave si usa sqp() (funzione CORE, nessun pacchetto
%   opzionale). Su MATLAB si usa fmincon('Algorithm','sqp'), che richiede
%   l'Optimization Toolbox (NON verificato sull'ambiente dell'utente).
%
%   DESIGN (guess dichiarato, rif. CLAUDE.md S7): le uguaglianze NON sono passate
%   al solver come vincoli di uguaglianza esatti. Sono trasformate via eq_to_ineq
%   (g_k = |h_k| - eps_eq_k <= 0, S5.2 punto 1) e trattate come disuguaglianze,
%   esattamente come cineq. Questo lega il target di precisione del repair allo
%   STESSO schedule eps_eq usato per il ranking (S5.2): repair via via piu'
%   esigente quando eps_eq_k si restringe verso tol_con_k. In Fase 4
%   (feasibility-polish) si richiama con eps_eq = tol_con per la precisione finale.
%
%   INPUT  x       : punto candidato, n x 1, spazio normalizzato [0,1]
%          con_fun : handle [cineq, ceq] = con_fun(x) (NON restituisce f: separazione
%                    dei ruoli, riuso cache lato chiamante per evitare doppia
%                    simulazione tra obiettivo e repair, rif. CLAUDE.md S4)
%          eps_eq  : vettore n_eq x 1 (soglie correnti, da eps_schedule) o []
%          Cinv    : (opzionale) inversa della covarianza CMA-ES corrente, n x n,
%                    per la metrica di Mahalanobis (rif. S5.2 invarianza affine).
%                    Default: identita' (metrica euclidea) se omessa -- caso d'uso
%                    fuori dal loop CMA (es. feasibility_polish, Fase 4).
%   OUTPUT x_rep   : punto riparato, n x 1, in [0,1]. Se x e' gia' feasible entro
%                    eps_eq, x_rep = x invariato (nessuna chiamata al solver).
    x = x(:);
    n = numel(x);
    if nargin < 4 || isempty(Cinv)
        Cinv = eye(n);
    end

    [cineq0, ceq0] = con_fun(x);
    g0 = eq_to_ineq(ceq0, eps_eq);
    if (isempty(cineq0) || all(cineq0 <= 0)) && (isempty(g0) || all(g0 <= 0))
        x_rep = x;
        return
    end

    lb = zeros(n, 1);
    ub = ones(n, 1);
    x0_init = min(max(x, 0), 1);

    if exist('OCTAVE_VERSION', 'builtin')
        phi = {@(y) local_obj(y, x, Cinv), @(y) local_grad(y, x, Cinv)};
        h_octave = @(y) -local_all_ineq(y, con_fun, eps_eq);   % sqp: h(x)>=0 feasible
        maxiter = 200;
        tol = 1e-10;
        [y_sol, ~, ~] = sqp(x0_init, phi, [], h_octave, lb, ub, maxiter, tol);
    else
        options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'off', ...
            'SpecifyObjectiveGradient', true, 'MaxIterations', 200);
        objfun = @(y) local_obj_grad(y, x, Cinv);
        nonlcon = @(y) deal(local_all_ineq(y, con_fun, eps_eq), []);
        y_sol = fmincon(objfun, x0_init, [], [], [], [], lb, ub, nonlcon, options);
    end

    x_rep = min(max(y_sol(:), 0), 1);
end

function f = local_obj(y, x, Cinv)
    d = y - x;
    f = d' * Cinv * d;
end

function g = local_grad(y, x, Cinv)
    d = y - x;
    g = 2 * Cinv * d;
end

function [f, g] = local_obj_grad(y, x, Cinv)
    f = local_obj(y, x, Cinv);
    g = local_grad(y, x, Cinv);
end

function c = local_all_ineq(y, con_fun, eps_eq)
% Vincoli aggregati in convenzione c<=0 (cineq + uguaglianze via eq_to_ineq).
    [cineq, ceq] = con_fun(y);
    g = eq_to_ineq(ceq, eps_eq);
    c = [cineq(:); g(:)];
end
