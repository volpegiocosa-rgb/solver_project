function x = giano_prepare_x(x, other)
% GIANO_PREPARE_X  Clip ai bounds fisici + conversione deg->rad sulle
%   componenti angolari, stessa convenzione di real_case/traj_cost.m
%   (rif. giano-design.md H4). Estratta da giano_traj_cost.m (Gate 4) in
%   un helper condiviso in Gate 6, perche' serve anche alla
%   ri-simulazione del punto migliore (giano_full_res.m) -- che deve
%   applicare la STESSA trasformazione prima di passare x a
%   TSTO/source/simulator.m, altrimenti il punto ri-simulato non
%   corrisponderebbe a quello effettivamente valutato durante
%   l'ottimizzazione.
%
%   INPUT  : x      10x1, variabili di design in unita' MISTE (native
%                   TSTO tranne le componenti in other.ang_idx, in gradi)
%            other  struct con other.opt_bounds.lb/.ub (opzionale) e
%                   other.ang_idx (opzionale)
%   OUTPUT : x      10x1, clippato e con le componenti angolari in
%                   radianti -- pronto per TSTO/source/traj_problem.m o
%                   TSTO/source/simulator.m

    x = x(:);
    if isfield(other, 'opt_bounds')
        x = min(max(x, other.opt_bounds.lb(:)), other.opt_bounds.ub(:));
    end
    if isfield(other, 'ang_idx') && ~isempty(other.ang_idx)
        x(other.ang_idx) = deg2rad(x(other.ang_idx));
    end

end
