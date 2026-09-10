% RUN_REAL_CASE_DE  Mirror di real_case/run_real_case.m per il solver alternativo DE +
%   Deb's rule (rif. piano di sessione "confronto DE vs CMA-ES+ARCH"). Stesso dataset,
%   stessi bounds/x0 (da design_variables.csv), stesso tol_con, stesso seed/max_time/
%   max_eval di run_real_case.m -- unica differenza: chiama solver_de invece di solver.
%
%   Vedi real_case/run_real_case.m per il razionale completo di ogni scelta (dataset
%   validation_test_2, bounds Mpayload [4000,30000], tol_con 3% del target di missione,
%   max_eval=12000): NON ripetuto qui, questo script esiste solo per il confronto
%   (rif. real_case/compare_real_case.m), deve restare un mirror fedele, non una
%   riformulazione indipendente.

    % Stesso ordine di addpath di run_real_case.m: TSTO/source e TSTO/source/native
    % vanno in coda ('-end') per la collisione di nome init_state.m (vedi run_real_case.m).
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(fullfile(here, '..', 'de'));
    addpath(here);
    addpath(fullfile(here, '..', 'TSTO', 'source'), '-end');
    addpath(fullfile(here, '..', 'TSTO', 'source', 'native'), '-end');

    tsto_input_dir = fullfile(here, '..', 'TSTO', 'input', 'validation_test_2');
    other = interface(tsto_input_dir);
    % traj_cost.m richiede other.log_level esplicito (nessun default
    % silenzioso, merge 3.0.0): 1 = START/END bufferizzati.
    other.log_level = 1;

    n_design = 10;
    csv_path = fullfile(here, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_real_case_de:noCsv', 'Impossibile aprire %s.', csv_path);
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
        error('run_real_case_de:badCsv', ...
              ['%s: attese %d righe dati, trovate %d -- verificare che ' ...
               'idx/riga siano allineati 1..%d (rif. real_case/design_' ...
               'variables.csv).'], csv_path, n_design, row, n_design);
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

    opts.max_eval = 12000;   % stesso budget di run_real_case.m (confronto a parita' di budget)

    result = solver_de(@traj_cost, bounds, opts);

    fprintf('f_best (=-Mpayload) = %.6g  ->  Mpayload = %.6g kg\n', result.f_best, -result.f_best);
    fprintf('feasible = %d\n', result.feasible);
    fprintf('n_eval = %d  n_iter = %d  n_restarts = %d (N/A, DE vanilla)  stop_reason = %s\n', ...
        result.n_eval, result.n_iter, result.n_restarts, result.stop_reason);
