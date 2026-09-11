function [res, all_opt_log] = giano_run_continuation(other, lb, ub, tol_con, ...
                                    i_payload, x_nom, engine, copts, warm_state_in)
% GIANO_RUN_CONTINUATION  Loop multi-stadio del ratchet di continuazione
%   (rif. giano-design.md Gate 5c-3), porting di
%   real_case/run_continuation.m SENZA alcun file (rif. CON-001/H12):
%   `warm_start.mat` e' sostituito da 'warm_state_in' in ingresso e
%   'res.warm_state' in uscita -- la persistenza fra chiamate successive
%   di giano() e' responsabilita' del chiamante (rif. header giano.m).
%
%   Compone i pezzi gia' validati indipendentemente:
%     giano_eval_feasibility.m / giano_push_to_wall.m  (Gate 5c-1)
%     giano_continuation_stage.m                       (Gate 5c-2)
%   Qui vive SOLO l'orchestrazione: seeding iniziale da warm_state_in,
%   loop sugli stadi, raccolta di stage_log/opt_log, esito finale.
%
%   Nessuna stampa a console (a differenza dell'originale, che usa
%   fprintf per il progresso): giano.m e' pensato per essere incorporato
%   in un programma piu' grande, che decide da solo come/se riportare
%   l'avanzamento (rif. header giano.m). La diagnostica completa resta
%   comunque disponibile in all_opt_log e in res.stage_log.
%
%   INPUT
%     other      struct "pristine" (giano_build_other.m) + ang_idx/
%                log_level gia' impostati (SENZA opt_bounds: viene
%                impostato qui e per-stadio da giano_continuation_stage.m)
%     lb, ub     10x1, bounds fisici di base (NON ratchettati)
%     tol_con    3x1, tolleranze assolute per-vincolo
%     i_payload  indice del payload dentro x (rif.
%                giano_build_design_vectors.m)
%     x_nom      10x1, punto nominale/di partenza se non c'e' un seed
%                feasible (cfg.design_variables.*.x0, rif. Gate 3)
%     engine     @solver o @solver_de (rif. Gate 5a/5b)
%     copts      struct con le opzioni di continuazione, TUTTE
%                obbligatorie (nessun default silenzioso qui: i default
%                vivono in giano.m/cfg.opts, rif. Gate 7):
%                  .n_stage .stage_eval .stage_iter .max_restarts
%                  .vary_seed .seed .verbose .sigma0_cold .sigma0_warm
%                  .explore_every .back_off .x0_retreat .min_gain
%                  .patience .push_max .ratio_safety .bisect_tol
%                  .bisect_max .ratio_guess
%     warm_state_in   [] oppure struct('x_best_phys', 10x1, 'ratio', r) --
%                     stato restituito da una chiamata precedente di
%                     giano() (rif. cfg.warm_state in giano.m)
%
%   OUTPUT
%     res            struct: .x (10x1) .Mpayload .f_best .g .h .prop_res
%                    .feasible .n_eval .n_stage_run .stop_reason
%                    .stage_log (matrice Sx6: rif. giano_continuation_stage.m)
%                    .warm_state (struct da riportare in cfg.warm_state
%                    alla chiamata successiva, oppure [] se non c'e'
%                    nulla di certificato da persistere)
%     all_opt_log    cell array, log di TUTTE le valutazioni (seed +
%                    ogni stadio + verifica finale), ciascun record
%                    taggato con .stage (0=seed, 1..n_stage, -1=verifica
%                    finale) per poterle distinguere -- rif.
%                    giano_eval_log.m per il formato di ogni record

    n_eval_tot = 0;
    all_opt_log = {};

    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;

    % === stato iniziale del ratchet =====================================
    state = struct('lb_pl', lb(i_payload), 'x_warm', x_nom, 'best_x', [], ...
                    'best_pl', -Inf, 'ratio', copts.ratio_guess, 'n_stall', 0);

    giano_eval_log('reset');
    if ~isempty(warm_state_in) && isfield(warm_state_in, 'x_best_phys')
        x_seed = warm_state_in.x_best_phys(:);
        feas_s = giano_eval_feasibility(x_seed, other, tol_con);
        n_eval_tot = n_eval_tot + 1;
        if feas_s
            if isfield(warm_state_in, 'ratio') && ~isempty(warm_state_in.ratio) ...
                    && isfinite(warm_state_in.ratio) && warm_state_in.ratio > 0
                state.ratio = warm_state_in.ratio;
            end
            push_opts = struct('push_max', copts.push_max, 'ratio_safety', copts.ratio_safety, ...
                                'bisect_tol', copts.bisect_tol, 'bisect_max', copts.bisect_max);
            [best_x, best_pl, ratio_new, n_push] = giano_push_to_wall( ...
                x_seed, other, tol_con, ub(i_payload), state.ratio, i_payload, push_opts);
            n_eval_tot = n_eval_tot + n_push;
            state.best_x  = best_x;
            state.best_pl = best_pl;
            state.ratio   = ratio_new;
            state.lb_pl   = max(lb(i_payload), best_pl - copts.back_off);
            state.x_warm  = best_x;
            state.x_warm(i_payload) = max(state.lb_pl + copts.bisect_tol, best_pl - copts.x0_retreat);
        end
        % Seed presente ma non feasible: ignorato, si parte cold (stessa
        % semantica dell'originale -- nessun errore, solo nessun vantaggio).
    end
    seed_log = giano_eval_log('get');
    all_opt_log = [all_opt_log, local_tag_stage(seed_log, 0)];

    % === loop sugli stadi ================================================
    ev = giano_stage_vec(copts.stage_eval, copts.n_stage);
    it = giano_stage_vec(copts.stage_iter, copts.n_stage);

    stage_log = zeros(0, 6);
    stop_reason = 'max_stage';
    n_stage_run = 0;

    for s = 1:copts.n_stage
        stage_budget = struct('max_eval', ev(s), 'max_iter', it(s));
        [state, stopped, why, n_eval_stage, log_row] = giano_continuation_stage( ...
            s, state, other, lb, ub, tol_con, i_payload, engine, stage_budget, copts);

        stage_log = [stage_log; log_row]; %#ok<AGROW>
        n_eval_tot = n_eval_tot + n_eval_stage;
        n_stage_run = n_stage_run + 1;

        stage_opt_log = giano_eval_log('get');
        all_opt_log = [all_opt_log, local_tag_stage(stage_opt_log, s)]; %#ok<AGROW>

        if stopped
            stop_reason = why;
            break;
        end
    end

    % === esito ============================================================
    res = struct();
    res.n_eval      = n_eval_tot;
    res.n_stage_run = n_stage_run;
    res.stop_reason = stop_reason;
    res.stage_log   = stage_log;
    res.ratio       = state.ratio;

    if isempty(state.best_x)
        res.x         = [];
        res.Mpayload  = NaN;
        res.f_best    = NaN;
        res.g         = [];
        res.h         = [];
        res.prop_res  = NaN;
        res.feasible  = false;
        res.warm_state = [];
        return;
    end

    giano_eval_log('reset');
    [feas_end, ci_end, ce_end, pr_end] = giano_eval_feasibility(state.best_x, other, tol_con);
    n_eval_tot = n_eval_tot + 1;
    res.n_eval = n_eval_tot;
    final_log = giano_eval_log('get');
    all_opt_log = [all_opt_log, local_tag_stage(final_log, -1)];

    res.x        = state.best_x;
    res.Mpayload = state.best_pl;
    res.f_best   = -state.best_pl;
    res.g        = ci_end;
    res.h        = ce_end;
    res.prop_res = pr_end;
    res.feasible = feas_end;

    if feas_end
        res.warm_state = struct('x_best_phys', state.best_x, 'ratio', state.ratio);
    else
        res.warm_state = [];
    end

end


function tagged = local_tag_stage(log_cell, stage_idx)
% Aggiunge il campo .stage a ogni record del log (0=seed, 1..n=stadio,
% -1=verifica finale) -- necessario perche' giano_eval_log.m viene
% resettato a ogni fase (seed/stadio/verifica) e i suoi eval_id
% ripartono da 1 in ognuna: senza questo tag sarebbero ambigui una volta
% concatenati in un unico all_opt_log.
    tagged = log_cell;
    for k = 1:numel(tagged)
        tagged{k}.stage = stage_idx;
    end
end
