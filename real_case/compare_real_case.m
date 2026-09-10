% COMPARE_REAL_CASE  Confronto onesto (risultato + velocita') fra CMA-ES+ARCH (solver.m) e
%   DE+Deb's rule (solver_de.m) sul caso reale TSTO (rif. piano di sessione "confronto DE vs
%   CMA-ES+ARCH"). Stesso dataset, stessi bounds/x0/tol_con/max_eval, seed accoppiati fra i
%   due solver -- l'unica differenza fra le due run di ogni seed e' l'algoritmo.
%
%   Output: results/de_vs_cmaes_real_case.csv (una riga per solver x seed) e
%   results/de_vs_cmaes_real_case.md (tabella + aggregati + limiti dichiarati).
%
%   PRE-FLIGHT: verifica che i .oct nativi (TSTO/source/native) esistano PRIMA di
%   cronometrare qualunque cosa -- senza, si misurerebbe il path interpretato
%   (~500-800x piu' lento), rendendo il confronto di velocita' disonesto.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(fullfile(here, '..', 'de'));
    addpath(here);
    addpath(fullfile(here, '..', 'TSTO', 'source'), '-end');
    addpath(fullfile(here, '..', 'TSTO', 'source', 'native'), '-end');

    % === pre-flight: fast-path nativo presente? =============================
    native_dir = fullfile(here, '..', 'TSTO', 'source', 'native');
    native_files = {'eom_native.oct', 'phase_event_native.oct', 'tsto_phases16_native.oct'};
    for k = 1:numel(native_files)
        fp = fullfile(native_dir, native_files{k});
        % NOTA: exist(fp,'file') restituisce 3 (non 2) per un .oct -- Octave lo classifica
        % come mex/oct-file anche quando il secondo argomento restringe la ricerca a 'file'.
        % Confronto corretto: 0 = non trovato, qualunque altro codice = trovato (bug trovato
        % eseguendo questo script la prima volta, non solo per ispezione).
        if exist(fp, 'file') == 0
            error('compare_real_case:nativeMissing', ...
                ['Fast-path nativo mancante: %s. Il confronto di velocita'' sarebbe ' ...
                 'disonesto senza (path interpretato ~500-800x piu'' lento). Ricompilare ' ...
                 'con mkoctfile (rif. %s/README.md) prima di rilanciare.'], fp, native_dir);
        end
    end
    fprintf('Pre-flight OK: fast-path nativo presente (%s).\n\n', native_dir);

    % === setup identico a run_real_case.m / run_real_case_de.m =============
    tsto_input_dir = fullfile(here, '..', 'TSTO', 'input', 'validation_test_2');
    other = interface(tsto_input_dir);
    % traj_cost.m richiede other.log_level esplicito (nessun default
    % silenzioso, merge 3.0.0): 1 = START/END bufferizzati.
    other.log_level = 1;

    n_design = 10;
    csv_path = fullfile(here, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('compare_real_case:noCsv', 'Impossibile aprire %s.', csv_path);
    end
    fgetl(fid);
    x_nom = zeros(n_design, 1);
    lb    = zeros(n_design, 1);
    ub    = zeros(n_design, 1);
    row = 0;
    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        line = strtrim(line);
        if isempty(line)
            continue;
        end
        row = row + 1;
        tok = strsplit(line);
        x_nom(row) = str2double(tok{4});
        lb(row)    = str2double(tok{5});
        ub(row)    = str2double(tok{6});
    end
    fclose(fid);
    if row ~= n_design
        error('compare_real_case:badCsv', ...
              '%s: attese %d righe dati, trovate %d.', csv_path, n_design, row);
    end

    bounds.lb = lb;
    bounds.ub = ub;
    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;

    base_opts = struct();
    base_opts.other    = other;
    base_opts.x0       = x_nom;
    base_opts.max_time = Inf;
    base_opts.verbose  = 0;
    base_opts.tol_con  = 0.03 * [other.MIS.perigee_altitude_target; ...
                                  other.MIS.apogee_altitude_target; ...
                                  other.MIS.target_orbital_inclination];
    base_opts.max_eval = 12000;   % stesso budget per entrambi i solver (parita', S0)

    % base_opts e' condiviso as-is fra solver() e solver_de(): sicuro per costruzione,
    % entrambi i parser (io/parse_opts.m, io/parse_opts_de.m) leggono solo i propri campi
    % noti e riempiono il resto con i propri default (nessuna contaminazione fra CMA-ES-only
    % e DE-only, rif. piano di sessione).

    seeds = 1:5;
    solvers = {'cmaes_arch', 'de_deb'};
    fun_handles = {@solver, @solver_de};

    n_rows = numel(seeds) * numel(solvers);
    rows = struct('solver', cell(1, n_rows), 'seed', cell(1, n_rows), ...
        'f_best', cell(1, n_rows), 'mpayload', cell(1, n_rows), ...
        'feasible', cell(1, n_rows), 'resid_perigee', cell(1, n_rows), ...
        'resid_apogee', cell(1, n_rows), 'resid_inclination', cell(1, n_rows), ...
        'n_eval', cell(1, n_rows), 'n_iter', cell(1, n_rows), ...
        'n_restarts', cell(1, n_rows), 'stop_reason', cell(1, n_rows), ...
        'wall_clock_s', cell(1, n_rows));

    r_idx = 0;
    for si = 1:numel(seeds)
        for sj = 1:numel(solvers)
            r_idx = r_idx + 1;
            opts = base_opts;
            opts.seed = seeds(si);

            fprintf('=== %s, seed=%d ===\n', solvers{sj}, seeds(si));
            t0 = tic;
            result = fun_handles{sj}(@traj_cost, bounds, opts);
            wall_clock_s = toc(t0);

            % Rivalutazione dei residui sul punto finale, FUORI dalla regione cronometrata
            % (reporting-only, non conta contro il budget/tempo di nessuno dei due solver).
            [~, ~, ceq_r] = traj_cost(result.x_best_phys, other);

            rows(r_idx).solver = solvers{sj};
            rows(r_idx).seed = seeds(si);
            rows(r_idx).f_best = result.f_best;
            rows(r_idx).mpayload = -result.f_best;
            rows(r_idx).feasible = result.feasible;
            rows(r_idx).resid_perigee = abs(ceq_r(1));
            rows(r_idx).resid_apogee = abs(ceq_r(2));
            rows(r_idx).resid_inclination = abs(ceq_r(3));
            rows(r_idx).n_eval = result.n_eval;
            rows(r_idx).n_iter = result.n_iter;
            rows(r_idx).n_restarts = result.n_restarts;
            rows(r_idx).stop_reason = result.stop_reason;
            rows(r_idx).wall_clock_s = wall_clock_s;

            fprintf('  Mpayload=%.6g kg  feasible=%d  n_eval=%d  wall_clock=%.1fs  stop=%s\n\n', ...
                rows(r_idx).mpayload, rows(r_idx).feasible, rows(r_idx).n_eval, ...
                wall_clock_s, rows(r_idx).stop_reason);
        end
    end

    % === output CSV ==========================================================
    results_dir = fullfile(here, '..', 'results');
    csv_out = fullfile(results_dir, 'de_vs_cmaes_real_case.csv');
    fid = fopen(csv_out, 'w');
    fprintf(fid, 'solver,seed,f_best,mpayload_kg,feasible,resid_perigee_m,resid_apogee_m,resid_inclination_rad,n_eval,n_iter,n_restarts,stop_reason,wall_clock_s\n');
    for k = 1:n_rows
        fprintf(fid, '%s,%d,%.6g,%.6g,%d,%.6g,%.6g,%.6g,%d,%d,%d,%s,%.3f\n', ...
            rows(k).solver, rows(k).seed, rows(k).f_best, rows(k).mpayload, rows(k).feasible, ...
            rows(k).resid_perigee, rows(k).resid_apogee, rows(k).resid_inclination, ...
            rows(k).n_eval, rows(k).n_iter, rows(k).n_restarts, rows(k).stop_reason, ...
            rows(k).wall_clock_s);
    end
    fclose(fid);
    fprintf('CSV scritto: %s\n', csv_out);

    % === output Markdown ====================================================
    md_out = fullfile(results_dir, 'de_vs_cmaes_real_case.md');
    fid = fopen(md_out, 'w');
    fprintf(fid, '# Confronto DE+Deb''s rule vs CMA-ES+ARCH -- caso reale TSTO\n\n');
    fprintf(fid, 'Dataset `validation_test_2`, n=10, 3 uguaglianze (perigeo/apogeo/inclinazione), ');
    fprintf(fid, 'cineq=[] (placeholder, nessuna disuguaglianza definita in TSTO). ');
    fprintf(fid, 'Stesso `bounds`/`x0`/`tol_con`/`max_eval=12000` per entrambi i solver, seed accoppiati 1..%d.\n\n', numel(seeds));

    fprintf(fid, '| solver | seed | Mpayload [kg] | feasible | resid perigeo [m] | resid apogeo [m] | resid inclinazione [rad] | n_eval | n_iter | n_restarts | stop_reason | wall_clock [s] |\n');
    fprintf(fid, '|---|---|---|---|---|---|---|---|---|---|---|---|\n');
    for k = 1:n_rows
        n_restarts_str = num2str(rows(k).n_restarts);
        if strcmp(rows(k).solver, 'de_deb')
            n_restarts_str = 'N/A (DE vanilla, nessun restart per design)';
        end
        fprintf(fid, '| %s | %d | %.6g | %d | %.4g | %.4g | %.4g | %d | %d | %s | %s | %.1f |\n', ...
            rows(k).solver, rows(k).seed, rows(k).mpayload, rows(k).feasible, ...
            rows(k).resid_perigee, rows(k).resid_apogee, rows(k).resid_inclination, ...
            rows(k).n_eval, rows(k).n_iter, n_restarts_str, rows(k).stop_reason, rows(k).wall_clock_s);
    end
    fprintf(fid, '\n');

    for sj = 1:numel(solvers)
        mask = strcmp({rows.solver}, solvers{sj});
        mp = [rows(mask).mpayload];
        wc = [rows(mask).wall_clock_s];
        fe = [rows(mask).feasible];
        fprintf(fid, '## Aggregato: %s\n\n', solvers{sj});
        fprintf(fid, '- Mpayload: mediana=%.6g kg, media=%.6g kg, min=%.6g kg, max=%.6g kg\n', ...
            median(mp), mean(mp), min(mp), max(mp));
        fprintf(fid, '- feasible: %d/%d seed\n', sum(fe), numel(fe));
        fprintf(fid, '- wall clock: mediana=%.1fs, media=%.1fs, min=%.1fs, max=%.1fs\n\n', ...
            median(wc), mean(wc), min(wc), max(wc));
    end

    fprintf(fid, '## Limiti dichiarati (non nascosti)\n\n');
    fprintf(fid, '- **DE vanilla, nessun restart** (decisione utente): a differenza di CMA-ES+ARCH ');
    fprintf(fid, '(restart IPOP, popolazione raddoppiata), il DE qui non ha un meccanismo per ');
    fprintf(fid, 'ripartire se la ricerca stagna. Uno svantaggio su eventuali bacini multimodali ');
    fprintf(fid, 'non e'' compensato, e'' un limite noto del confronto, non un difetto di ');
    fprintf(fid, 'implementazione.\n');
    fprintf(fid, '- **Gap di scala per-vincolo su cineq** (ereditato da ARCH, mai risolto, rif. ');
    fprintf(fid, 'constraints/arch_rank.m): NON esercitato da questo confronto, dato che il caso ');
    fprintf(fid, 'reale ha cineq=[] (nessuna disuguaglianza attiva in TSTO). Esercitato solo dallo ');
    fprintf(fid, 'smoke test interno (de/de_smoke_test.m, bench_rosenbrock_con).\n');
    fprintf(fid, '- **x0 diluito in DE**: nel solver DE, `opts.x0` e'' 1 membro su pop_size della ');
    fprintf(fid, 'popolazione iniziale; in CMA-ES e'' il 100%% del peso iniziale (xmean). Differenza ');
    fprintf(fid, 'strutturale accettata fra un algoritmo a singolo punto e uno a popolazione.\n');
    fprintf(fid, '- **eval_log.csv**: `real_case/traj_cost.m` logga ogni valutazione in ');
    fprintf(fid, '`real_case/eval_log.csv`, che qui interlaccia le chiamate di ENTRAMBI i solver e ');
    fprintf(fid, 'tutti i seed nella stessa sessione -- non e'' una traccia di un solo run. Il CSV ');
    fprintf(fid, 'di questo script e'' il record autorevole per-run.\n');
    fclose(fid);
    fprintf('Markdown scritto: %s\n', md_out);
