function [state, stopped, why, n_eval_stage, log_row] = giano_continuation_stage( ...
        stage_idx, state, other, lb, ub, tol_con, i_payload, engine, stage_budget, copts)
% GIANO_CONTINUATION_STAGE  Corpo di UN SOLO stadio del ratchet di
%   continuazione (rif. giano-design.md Gate 5c-2), porting del corpo del
%   ciclo `for s = 1:opt.n_stage` in
%   real_case/run_continuation.m (righe 184-321), isolato come function
%   pura per essere testabile indipendentemente dal loop multi-stadio
%   (Gate 5c-3) e senza alcuna stampa a console (diagnostica lasciata al
%   chiamante, rif. sotto).
%
%   Un solo stadio: (1) lancia 'engine' (solver.m o solver_de.m) sul
%   budget dello stadio con lo stato attuale del ratchet (lb(i_payload)
%   sostituito da state.lb_pl, punto iniziale state.x_warm); (2) valuta
%   la feasibility del risultato; (3) se feasible, applica il predictor-
%   corrector (giano_push_to_wall.m) per spingerlo al proprio muro; (4)
%   aggiorna stallo/patience e, se lo stadio non si ferma qui, il nuovo
%   lb_pl/x_warm per lo stadio successivo (stesso ordine di operazioni
%   dell'originale: il ratchet si aggiorna SOLO quando il loop
%   continuerebbe, mai su uno stadio che si ferma).
%
%   INPUT
%     stage_idx     indice 1-based dello stadio corrente (solo per il
%                   seed variabile e per log_row, nessun'altra logica ne
%                   dipende)
%     state         struct con lo stato del ratchet PRIMA di questo
%                   stadio:
%                     .lb_pl    lower bound corrente del payload [kg]
%                     .x_warm   10x1, punto di partenza per il motore
%                     .best_x   10x1 o [], miglior punto certificato finora
%                     .best_pl  scalare o -Inf, miglior payload certificato
%                     .ratio    rateo appreso (rif. giano_push_to_wall.m)
%                                o [] se non ancora stimato
%                     .n_stall  stadi consecutivi senza guadagno finora
%     other         struct "pristine" + ang_idx/log_level (SENZA
%                   opt_bounds: viene impostato qui dentro per lo stadio)
%     lb, ub        10x1, bounds FISICI di base (non ratchettati: questa
%                   function sostituisce lb(i_payload) con state.lb_pl)
%     tol_con       3x1, tolleranze assolute per-vincolo
%     i_payload     indice del payload dentro x (rif.
%                   giano_build_design_vectors.m)
%     engine        function handle @solver o @solver_de (rif.
%                   giano.m Gate 5a/5b, stesso contratto per entrambi)
%     stage_budget  struct .max_eval (scalare) .max_iter (scalare o Inf,
%                   rif. giano-design.md n_stage/stage_eval/stage_iter)
%     copts         struct con le opzioni di continuazione (rif.
%                   real_case/optimizer_settings.csv):
%                     .max_restarts .vary_seed .seed .verbose
%                     .sigma0_cold .sigma0_warm .explore_every
%                     .back_off .x0_retreat .min_gain .patience
%                     .push_max .ratio_safety .bisect_tol .bisect_max
%
%   OUTPUT
%     state         stato aggiornato (rif. sopra); INVARIATO se stopped
%                   e' true per un motivo diverso da un guadagno accettato
%                   (best_x/best_pl/ratio riflettono comunque l'ultimo
%                   push riuscito, se ce n'e' stato uno in questo stadio
%                   -- solo lb_pl/x_warm/n_stall restano quelli
%                   pre-stadio quando si ferma, stessa semantica
%                   dell'originale: il ratchet per LO STADIO SUCCESSIVO
%                   non viene calcolato se non c'e' un stadio successivo)
%     stopped       true se il loop chiamante deve fermarsi dopo questo
%                   stadio
%     why           '' | 'no_feasible' | 'patience' | 'ub_reached'
%     n_eval_stage  valutazioni spese in questo stadio (motore + verifica
%                   + push-to-wall)
%     log_row       1x6 = [stage_idx, lb_pl_usato, x0_pl_usato,
%                   pl_stadio, pl_dopo_push, feasible_stadio] (stesso
%                   formato di stage_log in real_case/run_continuation.m)

    n_eval_stage = 0;
    why = '';

    bounds = struct();
    bounds.lb = lb;
    bounds.ub = ub;
    bounds.lb(i_payload) = state.lb_pl;

    other.opt_bounds.lb = bounds.lb;
    other.opt_bounds.ub = bounds.ub;

    x0 = state.x_warm;
    x0(i_payload) = min(max(x0(i_payload), bounds.lb(i_payload)), bounds.ub(i_payload));

    solver_opts = struct();
    solver_opts.other        = other;
    solver_opts.x0           = x0;
    solver_opts.max_time     = Inf;
    if copts.vary_seed
        solver_opts.seed = copts.seed + stage_idx - 1;
    else
        solver_opts.seed = copts.seed;
    end
    solver_opts.verbose      = copts.verbose;
    solver_opts.tol_con      = tol_con;
    solver_opts.max_eval     = stage_budget.max_eval;
    solver_opts.max_restarts = copts.max_restarts;
    if isfinite(stage_budget.max_iter)
        solver_opts.max_iter = stage_budget.max_iter;
    end

    % Stadio ESPLORATIVO vs CALDO vs cold-start: stessa logica
    % dell'originale (rif. header per il razionale misurato). I campi
    % sigma0/restart_mode sono CMA-ES-specifici: solver_de li ignora
    % senza errori (stesso meccanismo gia' verificato in Gate 5b).
    explore = isempty(state.best_x) || ...
              (copts.explore_every > 0 && mod(stage_idx, copts.explore_every) == 0);
    if isempty(state.best_x)
        solver_opts.sigma0       = copts.sigma0_cold;
        solver_opts.restart_mode = 'sobol';
    elseif explore
        solver_opts.sigma0       = copts.sigma0_warm;
        solver_opts.restart_mode = 'sobol';
    else
        solver_opts.sigma0       = copts.sigma0_warm;
        solver_opts.restart_mode = 'auto';
    end

    giano_eval_log('reset');
    result = engine(@giano_traj_cost, bounds, solver_opts);
    n_eval_stage = n_eval_stage + result.n_eval;
    % NOTA: giano_eval_log viene resettato a ogni stadio (un solo motore
    % alla volta e' mai in volo, rif. limite dichiarato in
    % giano_eval_log.m); il chiamante (Gate 5c-3) e' responsabile di
    % raccogliere out.opt_log PRIMA del prossimo reset se lo vuole
    % per-stadio, oppure di accumularlo esternamente.

    xb = result.x_best_phys;
    feas = giano_eval_feasibility(xb, other, tol_con);
    n_eval_stage = n_eval_stage + 1;

    if ~feas
        log_row = [stage_idx, state.lb_pl, x0(i_payload), xb(i_payload), state.best_pl, 0];
        stopped = true;
        why = 'no_feasible';
        return;
    end

    push_opts = struct('push_max', copts.push_max, 'ratio_safety', copts.ratio_safety, ...
                        'bisect_tol', copts.bisect_tol, 'bisect_max', copts.bisect_max);
    [x_cand, pl_cand, ratio_new, n_push] = giano_push_to_wall( ...
        xb, other, tol_con, ub(i_payload), state.ratio, i_payload, push_opts);
    n_eval_stage = n_eval_stage + n_push;
    state.ratio = ratio_new;

    log_row = [stage_idx, state.lb_pl, x0(i_payload), xb(i_payload), pl_cand, 1];

    gain = pl_cand - state.best_pl;
    if pl_cand > state.best_pl
        state.best_x  = x_cand;
        state.best_pl = pl_cand;
    end

    % Guadagno vero -> accettato SEMPRE (gia' fatto sopra); min_gain
    % governa solo QUANDO fermarsi (stessa correzione gia' applicata
    % nell'originale, rif. header run_continuation.m).
    if isfinite(gain) && gain < copts.min_gain
        state.n_stall = state.n_stall + 1;
        if state.n_stall >= copts.patience
            stopped = true;
            why = 'patience';
            return;
        end
    else
        state.n_stall = 0;
    end

    if state.best_pl >= ub(i_payload) - copts.min_gain
        stopped = true;
        why = 'ub_reached';
        return;
    end

    % Ratchet + warm start per lo stadio successivo (solo se si continua).
    state.lb_pl  = max(lb(i_payload), state.best_pl - copts.back_off);
    state.x_warm = state.best_x;
    state.x_warm(i_payload) = max(state.lb_pl + copts.bisect_tol, state.best_pl - copts.x0_retreat);

    stopped = false;

end
