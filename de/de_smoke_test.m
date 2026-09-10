% DE_SMOKE_TEST  Check interno di meccanica per il solver DE (rif. piano di sessione
%   "confronto DE vs CMA-ES+ARCH").
%
% NON un deliverable di validazione (CLAUDE.md S8 richiede la validazione della Fase A sulla
%   suite benchmark; per il solver DE l'utente ha scelto di validare/confrontare SOLO sul
%   caso reale TSTO, rif. piano di sessione). Questo script esiste per igiene implementativa:
%   catturare bug di meccanica (mutazione/crossover/bound-handling/selezione/integrazione con
%   parse_opts_de/feasibility_polish) con budget minuscoli e in pochi secondi, PRIMA di
%   spendere tempo di calcolo sul simulatore reale -- non riapre la decisione dell'utente.
%
% Riusa i problemi GIA' esistenti in /benchmark (nessun nuovo placeholder):
%   - bench_sphere   : nessun vincolo, meccanica base + riproducibilita' bit-esatta.
%   - bench_rosenbrock_con : sole disuguaglianze, esercita il ramo cineq di deb_select.m
%     (MAI esercitato dal caso reale, dove cineq=[] -- rif. real_case/traj_cost.m).
%   - bench_g13      : sole uguaglianze (n_eq=3, n_ineq=0), STESSA shape di vincoli del caso
%     reale -- lo smoke test piu' rappresentativo per il caso d'uso vero.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'io'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(here);
    addpath(fullfile(here, '..', 'benchmark'));

    n_fail = 0;

    % === 1) sphere: meccanica base + riproducibilita' bit-esatta =============
    fprintf('--- sphere (n=8, non vincolato) ---\n');
    bounds.lb = -5 * ones(8, 1);
    bounds.ub = 5 * ones(8, 1);
    opts = struct('seed', 1, 'pop_size', 30, 'max_iter', 50, 'verbose', 0);
    r1 = solver_de(@bench_sphere, bounds, opts);
    r2 = solver_de(@bench_sphere, bounds, opts);
    ok = r1.feasible && all(r1.x_best == r2.x_best) && (r1.f_best == r2.f_best) ...
        && all(diff(r1.f_hist) <= 0);
    fprintf('  f_best=%.6g feasible=%d n_eval=%d n_iter=%d stop=%s\n', ...
        r1.f_best, r1.feasible, r1.n_eval, r1.n_iter, r1.stop_reason);
    fprintf('  bit-esatta a seed fisso: %d | f_hist non-crescente: %d\n', ...
        all(r1.x_best == r2.x_best) && (r1.f_best == r2.f_best), all(diff(r1.f_hist) <= 0));
    if ~ok
        n_fail = n_fail + 1;
        fprintf('  *** FAIL ***\n');
    end

    % === 2) rosenbrock vincolata: ramo cineq di deb_select ====================
    fprintf('--- rosenbrock_con (n=2, sole disuguaglianze) ---\n');
    bounds.lb = [-1.5; -0.5];
    bounds.ub = [1.5; 2.5];
    opts = struct('seed', 1, 'pop_size', 20, 'max_iter', 200, 'verbose', 0);
    r = solver_de(@bench_rosenbrock_con, bounds, opts);
    fprintf('  f_best=%.6g feasible=%d n_eval=%d n_iter=%d stop=%s\n', ...
        r.f_best, r.feasible, r.n_eval, r.n_iter, r.stop_reason);
    if ~r.feasible
        n_fail = n_fail + 1;
        fprintf('  *** FAIL (nessun punto feasible trovato) ***\n');
    end

    % === 3) g13: sole uguaglianze, stessa shape di vincoli del caso reale =====
    fprintf('--- g13 (n=5, 3 uguaglianze) ---\n');
    bounds.lb = [-2.3; -2.3; -3.2; -3.2; -3.2];
    bounds.ub = [2.3; 2.3; 3.2; 3.2; 3.2];
    opts = struct('seed', 1, 'pop_size', 40, 'max_iter', 500, 'tol_con', [1e-3; 1e-3; 1e-3], 'verbose', 0);
    r = solver_de(@bench_g13, bounds, opts);
    fprintf('  f_best=%.6g feasible=%d n_eval=%d n_iter=%d stop=%s\n', ...
        r.f_best, r.feasible, r.n_eval, r.n_iter, r.stop_reason);
    if ~r.feasible
        n_fail = n_fail + 1;
        fprintf('  *** FAIL (nessun punto feasible entro tol_con) ***\n');
    end

    fprintf('\n=== de_smoke_test: %d fallimenti ===\n', n_fail);
