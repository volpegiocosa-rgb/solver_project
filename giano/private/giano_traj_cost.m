function [f, cineq, ceq, prop_residual] = giano_traj_cost(x, other)
% GIANO_TRAJ_COST  Wrapper obiettivo per il motore di ottimizzazione
%   (solver.m/solver_de.m si aspettano [f,cineq,ceq]=fun(x,other), rif.
%   CLAUDE.md S4), porting di real_case/traj_cost.m SENZA alcuna
%   scrittura su file (rif. giano-design.md CON-001/H6): la diagnostica
%   per-valutazione va in memoria via giano_eval_log.m invece che in
%   real_case/eval_log.csv.
%
%   Stessa logica di clip+conversione di real_case/traj_cost.m (estratta
%   in giano_prepare_x.m, Gate 6: riusata tale e quale dalla
%   ri-simulazione del punto migliore in giano_full_res.m), ma i dati di
%   supporto (bounds, indici delle variabili angolari, livello di log)
%   viaggiano dentro 'other' invece che essere letti da un CSV o cablati:
%     other.opt_bounds.lb / .ub   bounds fisici (10x1), per il clip di
%                                 sicurezza -- rif. giano_build_design_vectors.m
%     other.ang_idx               indici (dentro 1:10) delle variabili in
%                                 gradi da convertire in radianti -- rif.
%                                 giano_build_design_vectors.m (H4)
%     other.log_level              0-3, verbosita' di giano_eval_log.m
%                                 (H6). NESSUN default silenzioso: se
%                                 assente, errore esplicito.
%   Tutti e tre impostati da giano.m (Gate 5) prima di lanciare
%   l'ottimizzazione, invariati per l'intero run (stessa 'other'
%   pristine passata a ogni valutazione).
%
%   Livelli di log (rif. giano_eval_log.m):
%     0 = nessun record accumulato (zero overhead)
%     1 = {eval_id, f, elapsed_s}
%     2 o 3 = come 1 + {x (post clip+deg2rad), cineq, ceq, prop_residual}
%             (la distinzione 2 vs 3 di real_case/traj_cost.m era
%             fopen/fflush per sopravvivere a un crash: non si applica
%             qui, non essendoci alcun file -- 3 e' quindi un alias di 2
%             in memoria, dichiarato esplicitamente, non un
%             comportamento nascosto)
%
%   INPUT  : x      10x1, variabili di design, STESSA convenzione di
%                   real_case/traj_cost.m: unita' fisiche native TSTO
%                   tranne le componenti in other.ang_idx (gradi)
%            other  struct "pristine" di giano_build_other.m + i tre
%                   campi sopra
%   OUTPUT : f              -Mpayload [kg]
%            cineq          [] (placeholder, nessuna disuguaglianza in TSTO)
%            ceq            3x1, residui perigeo/apogeo/inclinazione
%            prop_residual  propellente residuo stadio 2 [kg] (4o output,
%                           OPZIONALE lato chiamante: solver.m/solver_de.m
%                           ne richiedono solo 3 e questo resta
%                           semplicemente non assegnato, nessun errore --
%                           stesso pattern gia' in uso in traj_problem.m/
%                           traj_cost.m. Usato invece dal predittore di
%                           continuazione, Gate 5c-1, che ha bisogno del
%                           propellente residuo per stimare il muro del
%                           payload -- rif. giano_push_to_wall.m)

    if ~isfield(other, 'log_level')
        error('giano:missingLogLevel', ...
            'other.log_level non impostato (0-3): deve arrivare da cfg.opts.log_level via giano.m.');
    end
    log_level = other.log_level;

    x = giano_prepare_x(x, other);

    t_eval = tic;
    if isfield(other, 'sim_opts')
        % Passthrough opzionale (rif. giano-design.md H11): tmax_phase/
        % tmin/tmax, se forniti da cfg.opts via giano.m (AbsTol/RelTol
        % deliberatamente esclusi, mai letti da simulator.m dopo il
        % passaggio a rk5.m -- rif. giano.m per la verifica).
        [f, cineq, ceq, prop_residual] = traj_problem(x, other, other.sim_opts);
    else
        [f, cineq, ceq, prop_residual] = traj_problem(x, other);
    end
    elapsed_s = toc(t_eval);

    if log_level >= 1
        record = struct('f', f, 'elapsed_s', elapsed_s);
        if log_level >= 2
            record.x             = x;
            record.cineq         = cineq;
            record.ceq           = ceq;
            record.prop_residual = prop_residual;
        end
        giano_eval_log('append', record);
    end

end
