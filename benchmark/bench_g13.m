function [f, cineq, ceq] = bench_g13(x, ~)
% BENCH_G13  Problema CEC2006 g13, 3 uguaglianze non-lineari (rif. CLAUDE.md S8 Fase A, S10).
%   Firma compatibile con traj_cost: [f, cineq, ceq] = bench_g13(x, other).
%   n=5, cineq=[] (solo uguaglianze -- struttura piu' simile al caso reale, S9).
%   f* noto = 0.053942, x* = [-1.717143; 1.595709; 1.827247; -0.7636413; -0.7636450].
%
%   Fonte (rif. CLAUDE.md S10, decisione utente su licenza non dichiarata,
%   rif. memoria license_risk_arch_cec2006): porting da
%   franciscorafaelsr/cec2006-benchmarks, code/matlab/g13.m e problems/g13.md.
    f = exp(x(1) * x(2) * x(3) * x(4) * x(5));
    cineq = [];
    ceq = [ ...
        sum(x.^2) - 10; ...
        x(2) * x(3) - 5 * x(4) * x(5); ...
        x(1)^3 + x(2)^3 + 1 ...
    ];
end
