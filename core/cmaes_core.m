function result = cmaes_core(fun_norm, n, opts, fun_ranked)
% CMAES_CORE  Loop CMA-ES esteso da purecmaes (rif. CLAUDE.md S5.1, S3.1).
%   Responsabilita': ask -> valuta -> ranking (delegato a fun_ranked) -> tell.
%   Espone la popolazione PRIMA della selezione (necessario per ARCH, Fase 2).
%   Base: purecmaes.m (rif. CLAUDE.md S10). Loop esplicito invece del ciclo
%   monolitico originale, per poter iniettare un ranking esterno.
%
%   INPUT  : fun_norm   handle f in spazio normalizzato [0,1]:
%                        [f, cineq, ceq] = fun_norm(xn), xn colonna n x 1
%            n          dimensione (runtime, non cablata)
%            opts       opzioni gia' validate da parse_opts
%            fun_ranked (opzionale) handle di ranking ARCH, DUE output:
%                        [order, state] = fun_ranked(f, cineq, ceq, state)
%                       lo state restituito puo' portare campi opachi propri
%                       del ranking (es. state.arch.alpha, Fase 2) che /core
%                       non interpreta, solo plumba (rif. CLAUDE.md S3).
%                       Se assente/vuoto: fallback su ranking banale
%                       sull'obiettivo (order = argsort(f)), l'unico caso
%                       gestibile senza /constraints (rif. CLAUDE.md S7:
%                       nessuna logica di vincoli qui, solo il fallback
%                       "nessun ranking esterno disponibile").
%   OUTPUT : result     struct (best-feasible, storia, n_eval, ...)
%
% STATO: Fase 3 — gate M4 verde (rif. CLAUDE.md S11). Ranking ARCH agganciato
% in Fase 2 (gate M3). Fix Fase 3: il criterio tol_fun usava f_hist/iter
% GLOBALI (mai azzerati da un restart IPOP all'altro), facendo scattare
% "convergenza" alla primissima generazione di ogni restart successivo al
% primo -- i restart non cercavano mai davvero. Introdotto tracking
% SEGMENT-LOCAL (iter_seg/f_hist_seg/f_best_feas_seg, azzerato a ogni
% restart) usato solo da tol_fun; f_hist/f_best_feas globali restano per
% l'output (vedi commenti inline sotto).

    if nargin < 4
        fun_ranked = [];
    end

    rng(opts.seed);

    xmean0 = init_mean(opts, n);
    state = init_state(xmean0, opts.sigma0, n);

    max_iter = opts.max_iter;
    max_eval = opts.max_eval;
    max_time = opts.max_time;
    tol_fun_win = 20;   % finestra interna per il criterio tol_fun (non e' un opts.*, S6)
    sigma_diverge = 1e2;   % soglia interna di sicurezza (non e' un opts.*, S6):
    % dominio normalizzato [0,1], sigma oltre 100x quella scala e' segno di
    % divergenza, non di ricerca legittima (vedi nota sul criterio sotto).

    t_start = tic;

    % f_best/x_best: miglior candidato per RANKING (order(1) di ogni generazione).
    % Senza vincoli coincide col best-feasible (ogni punto e' vacuously feasible).
    % Con ARCH attivo NON e' affidabile come output finale: un punto fortemente
    % infeasible puo' avere f artificiosamente basso (rif. CLAUDE.md S6: la
    % feasibility si valuta per-vincolo, nessuna aggregazione che la nasconda).
    % f_best_feas/x_best_feas: miglior candidato VERO feasible (per-vincolo,
    % entro opts.tol_con) mai osservato in tutta la popolazione di ogni
    % generazione -- e' l'output primario del solver quando esistono vincoli.
    f_best = Inf;
    x_best = xmean0;
    f_best_feas = Inf;
    x_best_feas = [];

    sigma_hist = zeros(max_iter, 1);
    f_hist = zeros(max_iter, 1);

    % f_hist_seg/iter_seg/f_best_feas_seg: versione SEGMENT-LOCAL (azzerata a
    % ogni restart IPOP) usata SOLO dal criterio di stop tol_fun -- bug trovato
    % in Fase 3 durante la calibrazione su bench_rosenbrock_con (rif. CLAUDE.md
    % S11): usare il running-min GLOBALE (f_best_feas/f_hist, mai decrescente
    % da un restart all'altro) come segnale di plateau rendeva tol_fun vero fin
    % dalla primissima generazione di OGNI restart successivo al primo, non
    % appena il best globale smetteva di migliorare -- indipendentemente da
    % quanto la nuova distribuzione (xmean/sigma/C appena reinizializzati da
    % ipop_restart.m) avesse effettivamente esplorato. Misurato: su
    % bench_rosenbrock_con tutti i restart 1..9 duravano ESATTAMENTE 1
    % iterazione (10/10 seed), mentre il primo segmento convergeva
    % genuinamente in ~170 iterazioni -- i restart non avevano mai la
    % possibilita' di cercare. f_hist/f_best_feas restano globali per
    % l'OUTPUT (result.f_hist, tracking del best-feasible su tutto il run,
    % S6/S7); il criterio di plateau va invece valutato sulla traiettoria del
    % segmento CORRENTE, come i criteri ill_conditioned/tol_x (gia' impliciti
    % in state.D/state.sigma/state.C, che ipop_restart.m reinizializza).
    f_best_feas_seg = Inf;
    f_hist_seg = zeros(max_iter, 1);
    iter_seg = 0;

    iter = 0;
    stop_reason = '';

    while true
        iter = iter + 1;
        iter_seg = iter_seg + 1;

        X = cmaes_ask(state);
        lambda_cur = size(X, 2);

        % NOTA (rif. CLAUDE.md S7, gap noto NON risolto in Fase 2): X non e'
        % vincolata a [0,1]^n qui (cmaes_ask.m non clippa, per l'invarianza
        % affine di S5.2, come purecmaes.m). E' stato provato un clip della
        % sola valutazione (Xc = min(max(X,0),1) passato a fun_norm, X intatta
        % per cmaes_tell) ma e' stato scartato: misurato su g13 introduce un
        % nuovo fallimento (popolazione intrappolata su un angolo del dominio
        % quando molti campioni vi si clippano identici, azzerando il gradiente
        % di ritorno) che PEGGIORA il tasso di feasibility rispetto a non
        % clippare affatto (regressione su 2/3 seed testati, anche a budget
        % maggiorato). Lasciato cosi' come da decisione utente ("nessuna
        % modifica ora"): il floor di alpha=1.0 (arch_rank.m) resta l'unico
        % argine, indiretto, alle fughe fuori dominio.
        f = zeros(1, lambda_cur);
        cineq_cell = cell(1, lambda_cur);
        ceq_cell = cell(1, lambda_cur);
        for k = 1:lambda_cur
            [f(k), cineq_cell{k}, ceq_cell{k}] = fun_norm(X(:, k));
        end
        state.counteval = state.counteval + lambda_cur;

        if isempty(fun_ranked)
            [~, order] = sort(f);
        else
            % fun_ranked puo' restituire anche uno state aggiornato (Fase 2:
            % arch_rank porta un campo opaco state.arch per l'alpha adattivo;
            % /core non lo interpreta, lo plumba soltanto -- rif. CLAUDE.md S3).
            [order, state] = fun_ranked(f, cineq_cell, ceq_cell, state);
        end

        if f(order(1)) < f_best
            f_best = f(order(1));
            x_best = X(:, order(1));
        end

        % scan dell'intera popolazione (gia' valutata, nessuna simulazione
        % aggiuntiva) per il best-feasible VERO, dimension-agnostic su n_eq/n_ineq
        for k = 1:lambda_cur
            feas_k = true;
            if ~isempty(cineq_cell{k})
                feas_k = feas_k && all(cineq_cell{k} <= 0);
            end
            if ~isempty(ceq_cell{k})
                feas_k = feas_k && all(abs(ceq_cell{k}) <= opts.tol_con(:));
            end
            if feas_k && f(k) < f_best_feas
                f_best_feas = f(k);
                x_best_feas = X(:, k);
            end
            if feas_k && f(k) < f_best_feas_seg
                f_best_feas_seg = f(k);
            end
        end

        state = cmaes_tell(state, X, order);
        state.iter = iter;

        sigma_hist(iter) = state.sigma;
        % f_hist guida il criterio tol_fun (plateau): usa f_best_feas, non
        % f_best (running-min sul ranking) -- quest'ultimo puo' congelarsi su
        % un punto fortemente infeasible con f artificiosamente basso (vedi
        % nota sopra), causando una falsa convergenza precoce. Finche' nessun
        % punto feasible e' stato trovato, f_hist resta Inf: (Inf-Inf)=NaN,
        % NaN < tol_fun e' sempre falso, quindi il criterio non scatta mai
        % a vuoto (rif. CLAUDE.md S6: nessuna convergenza dichiarata senza
        % un vero segnale di feasibility).
        f_hist(iter) = f_best_feas;
        f_hist_seg(iter_seg) = f_best_feas_seg;

        if opts.verbose >= 2
            fprintf('iter %d: f_best=%.6g sigma=%.4g lambda=%d n_restarts=%d\n', ...
                iter, f_best, state.sigma, state.lambda, state.n_restarts);
        end

        % --- criteri di stop (rif. CLAUDE.md S6: almeno uno sempre attivo) ---
        budget_exhausted = false;
        converged = false;

        if state.counteval >= max_eval
            budget_exhausted = true; stop_reason = 'max_eval';
        elseif iter >= max_iter
            budget_exhausted = true; stop_reason = 'max_iter';
        elseif toc(t_start) >= max_time
            budget_exhausted = true; stop_reason = 'max_time';
        elseif max(state.D) > 1e7 * min(state.D)
            converged = true; stop_reason = 'ill_conditioned';
        elseif state.sigma > sigma_diverge
            % Salvaguardia (rif. CLAUDE.md S7, nota Fase 2): sigma non
            % dovrebbe crescere oltre l'ordine di grandezza del dominio
            % normalizzato [0,1]. Osservato in test su g13 con ranking ARCH:
            % sigma puo' divergere (fino a ~1e19) quando il ranking sulla
            % violazione diventa ipersensibile vicino a una tolleranza molto
            % stretta (eps_eq -> tol_con). Root cause NON completamente
            % risolta (segnalata all'utente, gate M3); questa soglia e' un
            % contenimento robusto generico (non specifico ad ARCH: si applica
            % anche senza vincoli) che forza un restart IPOP invece di
            % continuare a sprecare budget in un regime instabile.
            converged = true; stop_reason = 'diverged_sigma';
        elseif iter_seg > tol_fun_win && ...
                (max(f_hist_seg(iter_seg - tol_fun_win + 1:iter_seg)) - min(f_hist_seg(iter_seg - tol_fun_win + 1:iter_seg))) < opts.tol_fun
            % Segment-local (rif. nota sopra su f_hist_seg): plateau della
            % traiettoria del restart CORRENTE, non del best globale.
            converged = true; stop_reason = 'tol_fun';
        elseif state.sigma * max(sqrt(diag(state.C))) < opts.tol_x
            converged = true; stop_reason = 'tol_x';
        end

        if budget_exhausted
            break
        elseif converged
            if opts.restart_ipop && state.n_restarts < opts.max_restarts
                state = ipop_restart(state, opts);
                iter_seg = 0;
                f_best_feas_seg = Inf;
                continue
            else
                break
            end
        end
    end

    % output primario: best-feasible se esiste, altrimenti fallback esplicito
    % sul best-per-ranking (mai feasible in tutto il run -- flag result.feasible
    % lo segnala, nessuna finzione di successo, rif. CLAUDE.md S6/S7).
    result.feasible = ~isinf(f_best_feas);
    if result.feasible
        result.x_best = x_best_feas;
        result.f_best = f_best_feas;
    else
        result.x_best = x_best;
        result.f_best = f_best;
    end
    result.x_best_ranked = x_best;
    result.f_best_ranked = f_best;
    result.n_eval = state.counteval;
    result.n_iter = iter;
    result.n_restarts = state.n_restarts;
    result.sigma_final = state.sigma;
    result.stop_reason = stop_reason;
    result.sigma_hist = sigma_hist(1:iter);
    result.f_hist = f_hist(1:iter);

    if opts.verbose >= 1
        fprintf('cmaes_core: stop=%s f_best=%.6g feasible=%d n_eval=%d n_iter=%d n_restarts=%d\n', ...
            stop_reason, result.f_best, result.feasible, state.counteval, iter, state.n_restarts);
    end
end
