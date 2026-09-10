function result = de_core(fun_box, n, opts, select_fun)
% DE_CORE  Loop generazionale DE (rif. piano di sessione "confronto DE vs CMA-ES+ARCH").
%   Mirror di core/cmaes_core.m ma generazionale/pairwise invece che per-ranking: ask
%   (de/de_ask.m) -> valuta -> selezione pairwise (select_fun iniettato) -> sostituzione
%   sincrona. NESSUN restart (DE vanilla, decisione utente esplicita: confronto piu'
%   semplice/onesto contro CMA-ES+ARCH; eventuale svantaggio su aspetti multimodali e' un
%   limite noto, non compensato).
%
%   INPUT  fun_box    : handle [f,cineq,ceq] = fun_box(xb), xb colonna n x 1 in [0,1]^n.
%                       A DIFFERENZA di core/cmaes_core.m/fun_norm: qui NON c'e' un
%                       bound_transform a monte -- DE resta sempre dentro [0,1]^n via
%                       de_reflect_bounds (rif. de/de_ask.m), non serve lo spazio non
%                       vincolato che CMA-ES usa per l'invarianza affine.
%          n          : dimensione (runtime, mai cablata)
%          opts       : opzioni gia' validate da io/parse_opts_de.m (pop_size, F, CR,
%                       max_iter, max_eval, max_time, tol_con, tol_fun, tol_x, seed, x0)
%          select_fun : handle Deb's-rule (o altro comparatore compatibile) iniettato dal
%                       chiamante (rif. solver_de.m): winner_is_trial = select_fun(f_trial,
%                       cineq_trial, ceq_trial, f_target, cineq_target, ceq_target),
%                       vettorizzato su popolazione. /de resta ignaro della regola
%                       specifica (genericita', CLAUDE.md S1/S3), esattamente come /core
%                       resta ignaro di ARCH.
%   OUTPUT result     : struct (best-feasible, storia, n_eval, stop_reason, ...)

    rng(opts.seed);

    pop_size = opts.pop_size;
    F_de = opts.F;
    CR = opts.CR;
    max_iter = opts.max_iter;
    max_eval = opts.max_eval;
    max_time = opts.max_time;
    tol_fun_win = 20;   % finestra interna per il criterio tol_fun, stessa costante di
                        % core/cmaes_core.m (comparabilita' diretta fra i due motori)

    t_start = tic;

    X = de_population_init(n, pop_size, opts);

    f = zeros(1, pop_size);
    Cineq = cell(1, pop_size);
    Ceq = cell(1, pop_size);
    for k = 1:pop_size
        [f(k), ci, ce] = fun_box(X(:, k));
        Cineq{k} = ci;
        Ceq{k} = ce;
    end
    n_eval = pop_size;

    Cineq_mat = local_cell2mat(Cineq, pop_size);
    Ceq_mat = local_cell2mat(Ceq, pop_size);

    % x_best_feas/f_best_feas: vero best FEASIBLE (per-vincolo contro opts.tol_con, S6) --
    % l'unico output affidabile quando esistono vincoli (rif. core/cmaes_core.m per lo
    % stesso ragionamento: un punto fortemente infeasible puo' avere f artificiosamente
    % basso, nessuna aggregazione scalare deve nasconderlo).
    f_best_feas = Inf;
    x_best_feas = [];
    [x_best_feas, f_best_feas] = local_scan_feasible(X, f, Cineq_mat, Ceq_mat, opts.tol_con, x_best_feas, f_best_feas);

    % x_best_ranked/f_best_ranked: incumbent "per regola" (possibilmente infeasible),
    % aggiornato via select_fun -- sottoprodotto delle chiamate gia' necessarie, nessuna
    % valutazione extra. Analogo di order(1) per ARCH.
    x_best_ranked = [];
    f_best_ranked = Inf;
    cineq_best_ranked = [];
    ceq_best_ranked = [];
    [x_best_ranked, f_best_ranked, cineq_best_ranked, ceq_best_ranked] = local_fold_incumbent( ...
        X, f, Cineq_mat, Ceq_mat, x_best_ranked, f_best_ranked, cineq_best_ranked, ceq_best_ranked, select_fun);

    f_hist = zeros(max_iter, 1);
    iter = 0;
    stop_reason = '';

    while true
        if n_eval >= max_eval
            stop_reason = 'max_eval';
            break
        end
        if iter >= max_iter
            stop_reason = 'max_iter';
            break
        end
        if toc(t_start) >= max_time
            stop_reason = 'max_time';
            break
        end

        iter = iter + 1;

        V = de_ask(X, F_de, CR);

        f_trial = zeros(1, pop_size);
        Cineq_trial = cell(1, pop_size);
        Ceq_trial = cell(1, pop_size);
        for k = 1:pop_size
            [f_trial(k), ci, ce] = fun_box(V(:, k));
            Cineq_trial{k} = ci;
            Ceq_trial{k} = ce;
        end
        n_eval = n_eval + pop_size;

        Cineq_trial_mat = local_cell2mat(Cineq_trial, pop_size);
        Ceq_trial_mat = local_cell2mat(Ceq_trial, pop_size);

        % Selezione sincrona/generazionale: tutti i confronti usano la popolazione della
        % generazione PRECEDENTE come target (non trial gia' accettati nella stessa
        % generazione) -- DE classico, non steady-state (rif. header).
        winner_is_trial = select_fun(f_trial, Cineq_trial_mat, Ceq_trial_mat, f, Cineq_mat, Ceq_mat);

        X(:, winner_is_trial) = V(:, winner_is_trial);
        f(winner_is_trial) = f_trial(winner_is_trial);
        if ~isempty(Cineq_mat)
            Cineq_mat(:, winner_is_trial) = Cineq_trial_mat(:, winner_is_trial);
        end
        if ~isempty(Ceq_mat)
            Ceq_mat(:, winner_is_trial) = Ceq_trial_mat(:, winner_is_trial);
        end

        [x_best_ranked, f_best_ranked, cineq_best_ranked, ceq_best_ranked] = local_fold_incumbent( ...
            V, f_trial, Cineq_trial_mat, Ceq_trial_mat, ...
            x_best_ranked, f_best_ranked, cineq_best_ranked, ceq_best_ranked, select_fun);

        [x_best_feas, f_best_feas] = local_scan_feasible(X, f, Cineq_mat, Ceq_mat, opts.tol_con, x_best_feas, f_best_feas);

        % running-min, Inf finche' non esiste un feasible -- stessa protezione
        % Inf-Inf=NaN di core/cmaes_core.m per il criterio tol_fun sotto.
        f_hist(iter) = f_best_feas;

        % --- collasso spread popolazione: analogo diretto di sigma*max(sqrt(diag(C))) di
        %     CMA-ES, qui sulla popolazione grezza (DE vanilla non deriva un sigma/C proprio)
        if max(std(X, 0, 2)) < opts.tol_x
            stop_reason = 'tol_x';
            break
        end

        % --- plateau del best-feasible su una finestra interna (stessa costante W di
        %     core/cmaes_core.m, per comparabilita' diretta fra i due motori)
        if iter > tol_fun_win
            window = f_hist(iter - tol_fun_win + 1:iter);
            if (max(window) - min(window)) < opts.tol_fun
                stop_reason = 'tol_fun';
                break
            end
        end
    end

    result.feasible = ~isempty(x_best_feas);
    if result.feasible
        result.x_best = x_best_feas;
        result.f_best = f_best_feas;
    else
        result.x_best = x_best_ranked;
        result.f_best = f_best_ranked;
    end
    result.x_best_ranked = x_best_ranked;
    result.f_best_ranked = f_best_ranked;
    result.n_eval = n_eval;
    result.n_iter = iter;
    result.n_restarts = 0;   % sempre 0 per design (DE vanilla, nessun restart, decisione
                              % utente) -- non un fallimento, rif. piano di sessione
    result.stop_reason = stop_reason;
    result.f_hist = f_hist(1:iter);
end

function [x_best, f_best, cineq_best, ceq_best] = local_fold_incumbent( ...
        X, f, Cineq_mat, Ceq_mat, x_best, f_best, cineq_best, ceq_best, select_fun)
% Aggiorna l'incumbent "per regola" confrontandolo colonna per colonna con la popolazione
% data (usata sia per inizializzare, con x_best=[], sia per ripiegare i trial di ogni
% generazione). Nessuna valutazione aggiuntiva: opera solo su punti gia' valutati.
    pop_size = size(X, 2);
    for k = 1:pop_size
        cand_ci = local_col(Cineq_mat, k);
        cand_ce = local_col(Ceq_mat, k);
        if isempty(x_best)
            x_best = X(:, k);
            f_best = f(k);
            cineq_best = cand_ci;
            ceq_best = cand_ce;
            continue
        end
        cand_wins = select_fun(f(k), cand_ci, cand_ce, f_best, cineq_best, ceq_best);
        if cand_wins
            x_best = X(:, k);
            f_best = f(k);
            cineq_best = cand_ci;
            ceq_best = cand_ce;
        end
    end
end

function [x_best_feas, f_best_feas] = local_scan_feasible(X, f, Cineq_mat, Ceq_mat, tol_con, x_best_feas, f_best_feas)
% Scansiona la popolazione per il vero best FEASIBLE (per-vincolo, S6): stessa definizione
% usata in core/cmaes_core.m e solver.m (cineq<=0 e |ceq|<=tol_con, nessuna aggregazione
% scalare che nasconda la violazione di un singolo vincolo).
    pop_size = size(X, 2);
    for k = 1:pop_size
        ok = true;
        if ~isempty(Cineq_mat)
            ok = ok && all(Cineq_mat(:, k) <= 0);
        end
        if ~isempty(Ceq_mat)
            ok = ok && all(abs(Ceq_mat(:, k)) <= tol_con(:));
        end
        if ok && f(k) < f_best_feas
            f_best_feas = f(k);
            x_best_feas = X(:, k);
        end
    end
end

function c = local_col(M, k)
% Estrae la colonna k, o [] se M e' vuota (n_ineq=0 o n_eq=0).
    if isempty(M)
        c = [];
    else
        c = M(:, k);
    end
end

function M = local_cell2mat(C, pop_size)
% Converte una cell 1 x pop_size di vettori colonna (tutti stessa lunghezza, o tutti vuoti)
% in una matrice n_dim x pop_size, o [] se n_dim=0. Stesso pattern di
% constraints/arch_rank.m::local_cell2mat (duplicato qui: helper di 10 righe, non vale
% un'astrazione condivisa fra /constraints e /de per un solo riuso, rif. CLAUDE.md S7).
    if isempty(C) || all(cellfun(@isempty, C))
        M = [];
        return
    end
    n_dim = numel(C{1});
    M = zeros(n_dim, pop_size);
    for k = 1:pop_size
        M(:, k) = C{k}(:);
    end
end
