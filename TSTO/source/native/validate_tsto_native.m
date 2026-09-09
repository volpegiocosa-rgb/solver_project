% validate_tsto_native.m -- validazione persistente del fast-path nativo
%   tsto_phases16_native (porting Fortran di simulator.m S3 fasi 1-6 +
%   rk5.m + kinematic_step.m, rif. CLAUDE.md S11 Fase 5, sessione "TSTO
%   libreria standalone"). Confronta, su una batteria di 'x', l'output
%   end-to-end di real_case/traj_cost.m con il fast-path attivo contro
%   lo stesso con il fast-path assente (fallback al path interpretato,
%   che a sua volta usa eom_native/phase_event_native se disponibili).
%
%   A DIFFERENZA della validazione precedente di eom_native/
%   phase_event_native (mai salvata come script, gap notato in
%   sessione): questo file e' persistente e ripetibile, non ad-hoc.
%
%   Metodo: per confrontare i due path nella STESSA sessione Octave
%   servirebbe rimuovere/rinominare tsto_phases16_native.oct a runtime,
%   rischioso (cache interna di Octave sulle funzioni gia' risolte).
%   Si usano invece DUE processi 'octave' separati (via system()),
%   uno col file .oct presente (nativo) e uno con lo stesso file
%   temporaneamente spostato (interpretato) -- nessuna ambiguita' di
%   cache, ciascun processo vede lo stato del filesystem al proprio
%   avvio. Risultati salvati in .mat, poi confrontati qui.
%
%   Tolleranza: 1e-6 relativo su f/cineq/ceq/prop_residual. Piu' larga
%   della parita' sui kernel fisici (~1e-14, verificata in sessione
%   confrontando formula per formula guidance.m/eom.m/phase_event.m
%   contro eom_core.f90): qui si accumulano centinaia/migliaia di passi
%   RK5, e piccole differenze di ordine delle operazioni in virgola
%   mobile tra "una chiamata Fortran che itera le fasi 1-6" e "loop
%   Octave che ri-marshalla scalars ad ogni fase" si accumulano. Lo
%   'status'/fase raggiunta invece NON ha tolleranza: una divergenza di
%   fase e' un bug bloccante, non un errore numerico.

if isempty(getenv('TSTO_VALIDATE_WORKER'))
    % ============================== ORCHESTRATORE ==============================
    here = fileparts(mfilename('fullpath'));
    tsto_source = fullfile(here, '..');
    oct_path    = fullfile(here, 'tsto_phases16_native.oct');
    oct_backup  = fullfile(here, 'tsto_phases16_native.oct.hidden_for_validation');

    if exist(oct_path, 'file') ~= 3
        error('validate_tsto_native:missingOct', ...
              'tsto_phases16_native.oct non trovato in %s: compilarlo prima (vedi README.md).', here);
    end

    result_native = fullfile(tempdir(), 'tsto_validate_native.mat');
    result_interp = fullfile(tempdir(), 'tsto_validate_interp.mat');
    if exist(result_native, 'file'), delete(result_native); end
    if exist(result_interp, 'file'), delete(result_interp); end

    this_file = mfilename('fullpath');

    printf('=== validate_tsto_native: passata NATIVA ===\n');
    cmd_native = sprintf(['octave --no-gui -qf --eval "setenv(''TSTO_VALIDATE_WORKER'',''1''); ' ...
                           'setenv(''TSTO_VALIDATE_OUT'',''%s''); run(''%s'');"'], ...
                          result_native, this_file);
    status1 = system(cmd_native);

    printf('=== validate_tsto_native: passata INTERPRETATA (file .oct nascosto) ===\n');
    movefile(oct_path, oct_backup);
    cmd_interp = sprintf(['octave --no-gui -qf --eval "setenv(''TSTO_VALIDATE_WORKER'',''1''); ' ...
                           'setenv(''TSTO_VALIDATE_OUT'',''%s''); run(''%s'');"'], ...
                          result_interp, this_file);
    status2 = system(cmd_interp);
    movefile(oct_backup, oct_path);   % ripristinare SEMPRE, anche se status2 fallisce

    if status1 ~= 0 || status2 ~= 0
        error('validate_tsto_native:workerFailed', ...
              'Una delle due passate worker e'' fallita (status native=%d, interp=%d).', status1, status2);
    end

    Rn = load(result_native);
    Ri = load(result_interp);

    n = numel(Rn.cases);
    if n ~= numel(Ri.cases)
        error('validate_tsto_native:mismatchedCaseCount', ...
              'Numero di casi diverso tra le due passate (%d vs %d).', n, numel(Ri.cases));
    end

    tol_rel = 1e-6;
    n_pass = 0;
    printf('\n%-28s %8s %10s %14s %14s %14s %14s\n', ...
           'caso', 'status', 'f_ok', 'reldiff_f', 'reldiff_g', 'reldiff_h', 'reldiff_prop');
    for i = 1:n
        cn = Rn.cases(i);
        ci = Ri.cases(i);
        ok_status = isequal(cn.f == Inf, ci.f == Inf);   % entrambi feasible/entrambi crashati
        reldiff = @(a, b) abs(a - b) / max(abs(a), max(abs(b), 1e-12));
        if isfinite(cn.f) && isfinite(ci.f)
            rf = reldiff(cn.f, ci.f);
        else
            rf = NaN;
        end
        rg = max(abs(cn.g(:) - ci.g(:)) ./ max(abs(ci.g(:)), 1e-12));
        if isempty(rg), rg = 0; end
        rh = max(abs(cn.h(:) - ci.h(:)) ./ max(abs(ci.h(:)), 1e-9));
        rp = reldiff(cn.prop, ci.prop);

        case_ok = ok_status && (~isfinite(rf) || rf < tol_rel) && ...
                  (rg < tol_rel) && (rh < 1e-3) && (~isfinite(rp) || rp < tol_rel);
        % NOTA su rh: tolleranza assoluta-relativa mista (1e-9 al
        % denominatore) perche' ceq puo' essere vicino a zero (target
        % quasi centrato): un residuo relativo puro esploderebbe per
        % rumore numerico su valori gia' minuscoli (ordine mm su target
        % di centinaia di km). 1e-3 di soglia finale e' comunque 3-4
        % ordini di grandezza sotto tol_con (3% del target).
        n_pass = n_pass + case_ok;

        printf('%-28s %8s %10s %14.3e %14.3e %14.3e %14.3e\n', cn.name, ...
               mat2str(ok_status), mat2str(case_ok), rf, rg, rh, rp);
    end
    printf('\n%d/%d casi PASS (tol_rel=%.0e su f/cineq/ceq/prop_residual, status sempre identico)\n', ...
           n_pass, n, tol_rel);
    if n_pass < n
        error('validate_tsto_native:someCasesFailed', '%d/%d casi FALLITI.', n - n_pass, n);
    end
    printf('validate_tsto_native: TUTTI I CASI PASS.\n');

else
    % ================================= WORKER ==================================
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(here);
    real_case_dir = fullfile(here, '..', '..', '..', 'real_case');
    addpath(real_case_dir);

    datasets = {'reference_LV', 'validation_test', 'validation_test_2'};

    % bounds/x0 da design_variables.csv (stesso parsing di run_real_case.m)
    n_design = 10;
    csv_path = fullfile(real_case_dir, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    fgetl(fid);
    x_nom = zeros(n_design, 1); lb = zeros(n_design, 1); ub = zeros(n_design, 1);
    row = 0;
    while true
        line = fgetl(fid);
        if ~ischar(line), break; end
        line = strtrim(line);
        if isempty(line), continue; end
        row = row + 1;
        tok = strsplit(line);
        x_nom(row) = str2double(tok{4});
        lb(row)    = str2double(tok{5});
        ub(row)    = str2double(tok{6});
    end
    fclose(fid);

    other_v2 = interface(fullfile(here, '..', '..', 'input', 'validation_test_2'));
    other_v2.opt_bounds = struct('lb', lb, 'ub', ub);

    rand('seed', 42);   %#ok<RAND> % riproducibilita' della batteria random
    cases = struct('name', {}, 'x', {}, 'other', {});

    % 1) nominali sui 3 dataset (x_nom identico per tutti: GUIDANCE_VARS.csv
    %    invariate tra i dataset, solo i target di missione cambiano)
    for k = 1:numel(datasets)
        oth = interface(fullfile(here, '..', '..', 'input', datasets{k}));
        oth.opt_bounds = struct('lb', lb, 'ub', ub);
        cases(end+1) = struct('name', ['nominal_' datasets{k}], 'x', x_nom, 'other', oth); %#ok<AGROW>
    end

    % 2) random-in-bounds (15 punti, seed fisso, dataset validation_test_2)
    for k = 1:15
        xr = lb + rand(n_design, 1) .* (ub - lb);
        cases(end+1) = struct('name', sprintf('random_%02d', k), 'x', xr, 'other', other_v2); %#ok<AGROW>
    end

    % 3) vicino/sui bordi
    cases(end+1) = struct('name', 'at_lb', 'x', lb, 'other', other_v2); %#ok<AGROW>
    cases(end+1) = struct('name', 'at_ub', 'x', ub, 'other', other_v2); %#ok<AGROW>

    % 4) caso patologico noto: pitch_rate_transition=0 (idx 6, esattamente il
    %    suo lb -- rif. CLAUDE.md S11 Fase 5, causa dell'hang ODE pre-rk5.m),
    %    resto al nominale.
    x_patho = x_nom; x_patho(6) = 0;
    cases(end+1) = struct('name', 'pitch_rate_transition_zero', 'x', x_patho, 'other', other_v2); %#ok<AGROW>

    % 5) punto feasible noto dalla continuazione 2.0.0 (RELEASE 2.0.0,
    %    24655.3 kg, seed 1) -- x approssimato dal log della sessione: se non
    %    disponibile esattamente, un punto a meta' bounds con payload alto
    %    serve da proxy ragionevole (documentato, non spacciato per il punto
    %    esatto della continuazione).
    x_mid = (lb + ub) / 2;
    x_mid(10) = 24655.3;
    cases(end+1) = struct('name', 'mid_bounds_high_payload', 'x', x_mid, 'other', other_v2); %#ok<AGROW>

    results = struct('name', {}, 'f', {}, 'g', {}, 'h', {}, 'prop', {});
    for i = 1:numel(cases)
        c = cases(i);
        try
            [f, g, h, prop] = traj_cost(c.x, c.other);
        catch err
            printf('  caso %s: ECCEZIONE %s\n', c.name, err.message);
            f = NaN; g = NaN; h = [NaN; NaN; NaN]; prop = NaN;
        end
        results(i) = struct('name', c.name, 'f', f, 'g', g, 'h', h, 'prop', prop);
        printf('  [%s] %-28s f=%.6f g=%s h=[%.4e %.4e %.4e] prop=%.4f\n', ...
               getenv('TSTO_VALIDATE_MODE_LABEL'), c.name, f, mat2str(g), h(1), h(2), h(3), prop);
    end

    out_path = getenv('TSTO_VALIDATE_OUT');
    save(out_path, 'results');
    % rinominare 'results' in 'cases' per l'orchestratore (evita collisione
    % col nome locale 'cases' usato sopra)
    cases = results; %#ok<NASGU>
    save(out_path, 'cases');
end
