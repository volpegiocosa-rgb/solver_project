function order = giano_design_var_order()
% GIANO_DESIGN_VAR_ORDER  Ordine fisico fisso delle 10 variabili di design,
%   contratto con TSTO/source/traj_problem.m (rif. header di quel file:
%   x(1)=zkick, x(2)=pitch_over_starting, ..., x(10)=Mpayload).
%
%   FONTE UNICA di questo ordine: usato sia per validare cfg.design_variables
%   in giano.m (Gate 1) sia per assemblare i vettori x0/lb/ub in
%   giano_build_design_vectors.m (Gate 3), cosi' che l'elenco dei 10 nomi
%   esista in un solo punto invece di essere duplicato.
%
%   L'ordine con cui il CHIAMANTE di giano.m assegna i campi di
%   cfg.design_variables non ha alcun ruolo (accesso per nome, rif.
%   giano-design.md H10): questa function fissa solo l'ordine con cui
%   giano.m stessa deve LEGGERE quei campi per costruire il vettore x nella
%   sequenza che traj_problem.m si aspetta.
%
%   OUTPUT : order   cell array 1x10 di stringhe, ordine fisico fisso

    order = {'zkick', 'pitch_over_starting', 'pitch_c1', 'pitch_c2', ...
             'transition_starting', 'pitch_rate_transition', ...
             'insertion_starting', 'AoA_rate', 'plane_controller_kp', ...
             'Mpayload'};

end
