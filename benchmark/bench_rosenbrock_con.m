function [f, cineq, ceq] = bench_rosenbrock_con(x, ~)
% BENCH_ROSENBROCK_CON  Rosenbrock vincolata, DISUGUAGLIANZE (rif. CLAUDE.md S8 Fase A).
%   Valida la gestione di cineq (placeholder attuale su traj_cost, S4). ceq = [].
%   Firma compatibile con traj_cost: [f, cineq, ceq] = bench_rosenbrock_con(x, other).
%
%   Formulazione standard "constrained Rosenbrock cubic-and-line" (n=2, letteratura
%   CMA-ES vincolato, es. Runarsson & Yao 2000-2005): problema fisso, non
%   dimension-agnostic per costruzione (e' un benchmark puntuale, non il solver -
%   rif. CLAUDE.md S1: la genericita' vincola /core e /constraints, non i singoli
%   problemi di validazione in /benchmark).
%
%   f(x1,x2)  = (1-x1)^2 + 100*(x2-x1^2)^2
%   c1(x1,x2) = (x1-1)^3 - x2 + 1        <= 0
%   c2(x1,x2) = x1 + x2 - 2              <= 0
%
%   Ottimo noto: x* = (1,1), f* = 0, entrambi i vincoli attivi (c1=c2=0 in x*).
%   Bounds tipici in letteratura: x1 in [-1.5,1.5], x2 in [-0.5,2.5].

    assert(numel(x) == 2, 'bench_rosenbrock_con:badDim', ...
        'problema fisso a n=2 (formulazione standard cubic-and-line).');

    x1 = x(1);
    x2 = x(2);

    f = (1 - x1)^2 + 100 * (x2 - x1^2)^2;
    cineq = [(x1 - 1)^3 - x2 + 1; x1 + x2 - 2];
    ceq = [];
end
