function metrics = run_benchmarks(opts)
% RUN_BENCHMARKS  Esegue la suite Fase A su piu' seed (rif. CLAUDE.md S6.1, S8, S11).
%   Raccoglie: budget di convergenza (n_eval al target), stabilita' di sigma,
%   success-rate. OUTPUT metrics -> usato per DERIVARE i default definitivi
%   (Gate M4, io/parse_opts.m). Finche' non eseguito, i default restano
%   PROVVISORI (CLAUDE.md S6 avviso).
%
%   Budget usato QUI per la misura e' volutamente GENEROSO e SVINCOLATO dalla
%   formula provvisoria di parse_opts.m (S6.1: non ha senso calibrare i default
%   misurando una run gia' limitata dagli stessi default da calibrare). I
%   default derivati verranno poi dimensionati con margine sopra il budget di
%   convergenza osservato qui.
%
%   INPUT  opts (opzionale): opts.n_seeds (default 10), opts.seeds (esplicito,
%          sovrascrive n_seeds), opts.budget_max_iter (default 5000),
%          opts.budget_max_eval (default 2e5), opts.verbose (default 0).
%   OUTPUT metrics: struct con un campo per benchmark (sphere, rosenbrock,
%          g13), ciascuno con i risultati per-seed e le aggregazioni
%          (success_rate, n_eval_conv mediano/max fra i successi, sigma_ok).

    if nargin < 1 || isempty(opts)
        opts = struct();
    end
    if ~isfield(opts, 'seeds') || isempty(opts.seeds)
        n_seeds = 10;
        if isfield(opts, 'n_seeds') && ~isempty(opts.n_seeds)
            n_seeds = opts.n_seeds;
        end
        seeds = 1:n_seeds;
    else
        seeds = opts.seeds;
    end
    budget_max_iter = 5000;
    if isfield(opts, 'budget_max_iter') && ~isempty(opts.budget_max_iter)
        budget_max_iter = opts.budget_max_iter;
    end
    budget_max_eval = 2e5;
    if isfield(opts, 'budget_max_eval') && ~isempty(opts.budget_max_eval)
        budget_max_eval = opts.budget_max_eval;
    end
    verbose = 0;
    if isfield(opts, 'verbose') && ~isempty(opts.verbose)
        verbose = opts.verbose;
    end

    specs = struct();

    specs.sphere.fun = @bench_sphere;
    specs.sphere.bounds.lb = -5 * ones(25, 1);
    specs.sphere.bounds.ub = 5 * ones(25, 1);
    specs.sphere.tol_con = [];
    specs.sphere.target_f = 1e-8;

    specs.rosenbrock.fun = @bench_rosenbrock_con;
    specs.rosenbrock.bounds.lb = [-1.5; -0.5];
    specs.rosenbrock.bounds.ub = [1.5; 2.5];
    specs.rosenbrock.tol_con = [];
    specs.rosenbrock.target_f = 1e-3;

    specs.g13.fun = @bench_g13;
    specs.g13.bounds.lb = [-2.3; -2.3; -3.2; -3.2; -3.2];
    specs.g13.bounds.ub = [2.3; 2.3; 3.2; 3.2; 3.2];
    specs.g13.tol_con = [1e-4; 1e-4; 1e-4];
    specs.g13.target_f = [];   % successo = feasibility per-vincolo (S6/S8), non ottimo globale

    names = fieldnames(specs);
    metrics = struct();

    for b = 1:numel(names)
        name = names{b};
        spec = specs.(name);
        n = numel(spec.bounds.lb);

        runs = struct('seed', {}, 'f_best', {}, 'feasible', {}, 'success', {}, ...
            'n_eval', {}, 'n_iter', {}, 'n_restarts', {}, 'stop_reason', {}, ...
            'n_eval_conv', {}, 'sigma_diverged', {});

        for si = 1:numel(seeds)
            run_opts = struct();
            run_opts.seed = seeds(si);
            run_opts.tol_con = spec.tol_con;
            run_opts.max_iter = budget_max_iter;
            run_opts.max_eval = budget_max_eval;
            run_opts.verbose = 0;

            result = solver(spec.fun, spec.bounds, run_opts);

            success = result.feasible;
            if ~isempty(spec.target_f)
                success = success && (result.f_best <= spec.target_f);
            end

            n_eval_conv = NaN;
            if success
                % soglia = target_f se dato, altrimenti il valore finale
                % raggiunto (g13, senza target esplicito, S8: successo =
                % feasibility, non ottimo globale). f_hist e' un running-min
                % gia' feasible-aware (f_best_feas, rif. core/cmaes_core.m):
                % il primo attraversamento e' un proxy diretto del budget di
                % convergenza, nessuna valutazione aggiuntiva.
                thr = result.f_best;
                if ~isempty(spec.target_f)
                    thr = spec.target_f;
                end
                idx = find(result.f_hist <= thr, 1, 'first');
                if isempty(idx)
                    idx = result.n_iter;
                end
                n_eval_conv = idx / result.n_iter * result.n_eval;
                % stima proporzionale valutazioni/iterazioni fino a idx (lambda
                % puo' variare con IPOP, ma solo ai restart: approssimazione
                % sufficiente per un ordine di grandezza di calibrazione, S6.1).
            end

            r.seed = seeds(si);
            r.f_best = result.f_best;
            r.feasible = result.feasible;
            r.success = success;
            r.n_eval = result.n_eval;
            r.n_iter = result.n_iter;
            r.n_restarts = result.n_restarts;
            r.stop_reason = result.stop_reason;
            r.n_eval_conv = n_eval_conv;
            r.sigma_diverged = strcmp(result.stop_reason, 'diverged_sigma');
            runs(si) = r;

            if verbose >= 1
                fprintf('[%s] seed=%d f_best=%.6g feasible=%d success=%d n_eval=%d n_iter=%d n_restarts=%d stop=%s\n', ...
                    name, r.seed, r.f_best, r.feasible, r.success, r.n_eval, r.n_iter, r.n_restarts, r.stop_reason);
            end
        end

        succ_mask = [runs.success];
        agg.n = n;
        agg.success_rate = sum(succ_mask) / numel(runs);
        conv_vals = [runs(succ_mask).n_eval_conv];
        if isempty(conv_vals)
            agg.n_eval_conv_median = NaN;
            agg.n_eval_conv_max = NaN;
        else
            agg.n_eval_conv_median = median(conv_vals);
            agg.n_eval_conv_max = max(conv_vals);
        end
        agg.any_sigma_diverged = any([runs.sigma_diverged]);
        agg.runs = runs;

        metrics.(name) = agg;

        if verbose >= 1
            fprintf('=== %s: success_rate=%.2f n_eval_conv median=%.0f max=%.0f sigma_diverged=%d ===\n\n', ...
                name, agg.success_rate, agg.n_eval_conv_median, agg.n_eval_conv_max, agg.any_sigma_diverged);
        end
    end
end
