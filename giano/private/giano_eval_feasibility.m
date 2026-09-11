function [feas, cineq, ceq, prop_residual] = giano_eval_feasibility(x, other, tol_con)
% GIANO_EVAL_FEASIBILITY  Valuta un punto e ne determina la feasibility
%   per-vincolo, porting di real_case/run_continuation.m::local_eval.
%   Usa giano_traj_cost.m (Gate 4, zero file I/O) invece di
%   real_case/traj_cost.m, prendendone anche il 4o output
%   (prop_residual), necessario al predittore di continuazione (rif.
%   giano_push_to_wall.m).
%
%   Stessa definizione di feasible usata in solver.m/cmaes_core.m:
%   cineq<=0 e |ceq|<=tol_con, per-vincolo, nessuna aggregazione scalare.
%
%   INPUT  : x        10x1, variabili di design (unita' miste, stessa
%                     convenzione di giano_traj_cost.m)
%            other    struct "pristine" + opt_bounds/ang_idx/log_level
%            tol_con  3x1, tolleranze assolute per-vincolo
%   OUTPUT : feas            true/false
%            cineq, ceq      rif. giano_traj_cost.m
%            prop_residual   propellente residuo stadio 2 [kg]

    [~, cineq, ceq, prop_residual] = giano_traj_cost(x, other);
    feas = all(cineq <= 0) && all(abs(ceq) <= tol_con(:));

end
