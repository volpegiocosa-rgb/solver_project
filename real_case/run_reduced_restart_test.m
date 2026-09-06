% RUN_REDUCED_RESTART_TEST  Esperimento leva (b) (sessione "requisito 5 min",
%   CLAUDE.md S11 Fase 5): quanto ci si avvicina alla feasibility con un
%   budget di restart IPOP DELIBERATAMENTE limitato, invece di inseguire
%   l'ottimo globale (che su g13, Fase 3, e' costato fino a 431088 eval)?
%
%   Copia di real_case/run_real_case.m con SOLO gli opts di budget diversi
%   (script separato, non sovrascrive run_real_case.m, che resta la
%   configurazione "run a convergenza" in stand-by in attesa della
%   decisione DLL/porting). Stessa x0/bounds/tol_con/seed.
%
%   opts.max_restarts=3 -> lambda percorre al piu' 10,20,40,80 (vs fino a
%   5120 col default calibrato 9): costo minimo per il solo criterio
%   tol_fun (finestra 20 iter, rif. cmaes_core.m) = 20*(10+20+40+80) =
%   3000 eval; opts.max_eval=5000 lascia margine di ricerca oltre il
%   minimo. Obiettivo: dato numerico su "quanto ci si avvicina" a
%   feasible=1 con un budget cosi' contenuto, sull'Octave interpretato
%   ATTUALE (nessun porting DLL ancora) -- leva (b) isolata dalla leva (a).

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(here);
    addpath(fullfile(here, '..', 'TSTO', 'source'), '-end');

    tsto_input_dir = fullfile(here, '..', 'TSTO', 'input', 'reference_LV');
    other = interface(tsto_input_dir);

    n_design = 10;
    csv_path = fullfile(here, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_reduced_restart_test:noCsv', 'Impossibile aprire %s.', csv_path);
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
        error('run_reduced_restart_test:badCsv', ...
              ['%s: attese %d righe dati, trovate %d.'], csv_path, n_design, row);
    end

    bounds.lb = lb;
    bounds.ub = ub;

    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;

    opts = struct();
    opts.other    = other;
    opts.x0       = x_nom;
    opts.max_time = Inf;
    opts.seed     = 1;
    opts.verbose  = 1;

    opts.tol_con = 0.03 * [other.MIS.perigee_altitude_target; ...
                            other.MIS.apogee_altitude_target; ...
                            other.MIS.target_orbital_inclination];

    % === LEVA (b): budget di restart deliberatamente limitato ===========
    opts.max_restarts = 3;
    opts.max_eval      = 5000;

    result = solver(@traj_cost, bounds, opts);

    fprintf('f_best (=-Mpayload) = %.6g  ->  Mpayload = %.6g kg\n', result.f_best, -result.f_best);
    fprintf('feasible = %d\n', result.feasible);
    fprintf('n_eval = %d  n_iter = %d  n_restarts = %d  stop_reason = %s\n', ...
        result.n_eval, result.n_iter, result.n_restarts, result.stop_reason);
