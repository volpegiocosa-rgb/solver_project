% RUN_FEASIBILITY_FLOOR_PROBE  Run diagnostico SENZA vincolo di 5 minuti
%   (decisione utente, sessione "requisito 5 minuti", opzione "a": misurare
%   il floor reale di valutazioni-per-feasibility sul problema vero, ora
%   che il porting Fortran (eom_native/phase_event_native/minimal_output)
%   rende un budget grande economico in TEMPO (minuti/ore, non piu'
%   giorni), anche se ancora sopra il tetto di 5 minuti.
%
%   Motivazione (rif. CLAUDE.md S11 Fase 5): il run calibrato a
%   opts.max_eval=12000 (real_case/run_real_case.m) ha impiegato 8m58s
%   (44.9ms/eval reale durante CMA-ES, non 17ms della calibrazione su
%   campioni casuali) e NON ha trovato feasibility (feasible=0,
%   Mpayload bloccato al tetto 6000kg, ZERO restart IPOP in 1200
%   iterazioni). Non si sa se il problema e' "serve piu' budget" o
%   qualcos'altro -- questo script raccoglie il dato mancante.
%
%   Differenze rispetto a run_real_case.m: stesso x0/bounds/tol_con/seed
%   (comparabilita' diretta), opts.max_eval molto piu' ampio,
%   opts.verbose=2 (traccia iter/f_best/sigma/lambda/n_restarts ad OGNI
%   iterazione, gia' implementata in cmaes_core.m ma mai attivata finora
%   -- utile per capire se sigma si sta riducendo, cioe' se la ricerca e'
%   ancora viva o gia' di fatto ferma).

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(here);
    addpath(fullfile(here, '..', 'TSTO', 'source'), '-end');
    addpath(fullfile(here, '..', 'TSTO', 'source', 'native'), '-end');

    tsto_input_dir = fullfile(here, '..', 'TSTO', 'input', 'reference_LV');
    other = interface(tsto_input_dir);
    % traj_cost.m richiede other.log_level esplicito (nessun default
    % silenzioso, merge 3.0.0): 1 = START/END bufferizzati.
    other.log_level = 1;

    n_design = 10;
    csv_path = fullfile(here, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_feasibility_floor_probe:noCsv', 'Impossibile aprire %s.', csv_path);
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
        error('run_feasibility_floor_probe:badCsv', ...
              '%s: attese %d righe dati, trovate %d.', csv_path, n_design, row);
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
    opts.verbose  = 2;   % traccia iter/f_best/sigma/lambda/n_restarts

    opts.tol_con = 0.03 * [other.MIS.perigee_altitude_target; ...
                            other.MIS.apogee_altitude_target; ...
                            other.MIS.target_orbital_inclination];

    % === Budget ampio, SENZA vincolo di 5 minuti (decisione utente) =====
    % opts.max_restarts NON sovrascritto: resta il default calibrato (9),
    % cosi' se un punto feasible viene trovato i restart possono comunque
    % scattare. A ~45ms/eval (misurato su un vero run CMA-ES, non su
    % campioni casuali) 200000 eval ~ 150 min (~2.5h) su questa macchina.
    opts.max_eval = 200000;

    result = solver(@traj_cost, bounds, opts);

    fprintf('f_best (=-Mpayload) = %.6g  ->  Mpayload = %.6g kg\n', result.f_best, -result.f_best);
    fprintf('feasible = %d\n', result.feasible);
    fprintf('n_eval = %d  n_iter = %d  n_restarts = %d  stop_reason = %s\n', ...
        result.n_eval, result.n_iter, result.n_restarts, result.stop_reason);
