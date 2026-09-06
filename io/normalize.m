function xn = normalize(x_phys, bounds)
% NORMALIZE  Mapping spazio fisico -> [0,1] (rif. CLAUDE.md S4, S3.1).
%   Dimension-agnostic: opera su n = numel(bounds.lb). Vettorizzato: x_phys
%   puo' essere n x 1 (un punto) o n x k (piu' colonne, es. popolazione).
    lb = bounds.lb(:);
    ub = bounds.ub(:);
    range = ub - lb;
    assert(all(range > 0), 'normalize:badBounds', 'bounds.ub deve essere > bounds.lb su ogni componente.');
    xn = (x_phys - lb) ./ range;
end
