function [f, cineq, ceq] = bench_sphere(x, ~)
% BENCH_SPHERE  Sanity check del motore, nessun vincolo (rif. CLAUDE.md S8 Fase A).
%   Firma compatibile con traj_cost: [f, cineq, ceq] = bench_sphere(x, other).
%   Dimension-agnostic: opera su n = numel(x), nessun valore cablato.
    f = sum(x.^2);
    cineq = [];
    ceq = [];
end
