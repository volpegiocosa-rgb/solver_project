function x_phys = denormalize(xn, bounds)
% DENORMALIZE  Mapping [0,1] -> spazio fisico (rif. CLAUDE.md S4, S3.1).
%   Dimension-agnostic: opera su n = numel(bounds.lb). Vettorizzato: xn
%   puo' essere n x 1 (un punto) o n x k (piu' colonne, es. popolazione).
    lb = bounds.lb(:);
    ub = bounds.ub(:);
    x_phys = lb + xn .* (ub - lb);
end
