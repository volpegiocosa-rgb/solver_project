% RUN_REAL_CASE  Script di lancio del caso reale (Fase 5, CLAUDE.md S11,
%   gate M5): aggancia solver.m al simulatore TSTO (repository esterno
%   ../../TSTO) tramite l'adapter real_case/traj_cost.m.
%
% Decisioni applicative (conferma utente, sessione di integrazione con TSTO):
%   - x (10 variabili di design): rif. header TSTO/source/traj_problem.m e
%     real_case/traj_cost.m. pitch_at_transition RIMOSSA in una sessione
%     successiva (conferma utente): non e' un assetto libero, coincide per
%     costruzione con l'assetto di fine fase 2 -- ora derivata
%     automaticamente in TSTO/source/simulator.m, non piu' in x.
%   - bounds/x0: letti da real_case/design_variables.csv (colonne x0/lb/ub),
%     decisione utente (sessione successiva): sostituisce la precedente
%     derivazione +-50% dal nominale TSTO. Il CSV e' quindi ora fonte di
%     verita' per lo spazio di ricerca, non solo un riferimento
%     documentale. Le 4 componenti angolari (pitch_c1, pitch_c2,
%     pitch_rate_transition, AoA_rate; colonna unit = deg_s2/deg_s) sono
%     gia' in gradi nel file -- nessuna conversione qui, coerente con la
%     conversione deg -> rad fatta in real_case/traj_cost.m appena prima
%     di traj_problem.m (che si aspetta radianti nativi TSTO).
%   - tol_con: 3% del target di missione, per-vincolo (perigeo/apogeo/
%     inclinazione, stesso ordine di TSTO/source/eval_fgh.m OPT.h).
%   - max_time: Inf (nessun limite di wall-clock in questa fase di sviluppo,
%     esplicito). Restano attivi max_iter/max_eval CALIBRATI (Fase 3,
%     CLAUDE.md S11 Gate M4) come criteri di stop effettivi.

    % NOTA: addpath antepone in testa al path (l'ultima chiamata vince sui
    % conflitti di nome). TSTO/source va aggiunta con '-end' (in coda): esiste
    % una collisione di nome, TSTO/source/init_state.m (inizializzazione
    % massa/stato del simulatore) vs core/init_state.m (stato CMA-ES) --
    % senza '-end' la seconda viene oscurata dalla prima, con errore a runtime
    % in cmaes_core.m ("init_state: function called with too many inputs").
    % Nessun'altra collisione di nome tra TSTO/source e /core,/constraints,
    % /io,/real_case (verificato).
    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(here);
    addpath(fullfile(here, '..', '..', 'TSTO', 'source'), '-end');
    addpath(fullfile(here, '..', '..', 'TSTO', 'source', 'native'), '-end');

    tsto_input_dir = fullfile(here, '..', '..', 'TSTO', 'input', 'reference_LV');
    other = interface(tsto_input_dir);

    % === variabili di design: x0/lb/ub letti da design_variables.csv
    %     (decisione utente, vedi header). Colonne attese (spazio-
    %     separate): idx name unit x0 lb ub overwrites note. Righe attese
    %     in ordine di idx 1..10, stesso ordine di traj_cost.m /
    %     TSTO/source/traj_problem.m. ===
    n_design = 10;
    csv_path = fullfile(here, 'design_variables.csv');
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_real_case:noCsv', ...
              'Impossibile aprire %s.', csv_path);
    end
    fgetl(fid);   % scarta la riga di intestazione
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
        error('run_real_case:badCsv', ...
              ['%s: attese %d righe dati, trovate %d -- verificare che ' ...
               'idx/riga siano allineati 1..%d (rif. real_case/design_' ...
               'variables.csv).'], csv_path, n_design, row, n_design);
    end

    bounds.lb = lb;
    bounds.ub = ub;

    % === other.opt_bounds: SOLO per il clip di sicurezza in traj_cost.m
    %     (rif. traj_cost.m per il perche': CMA-ES campiona senza clip a
    %     [0,1] normalizzato, un x fisico fuori da [lb,ub] qui e' privo di
    %     senso fisico, non solo "subottimale") ===
    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;

    % === opts ===
    opts = struct();
    opts.other    = other;
    opts.x0       = x_nom;
    opts.max_time = Inf;
    opts.seed     = 1;
    opts.verbose  = 1;

    % tol_con: 3% del target di missione, per-vincolo, stesso ordine di
    % eval_fgh.m OPT.h (perigeo, apogeo, inclinazione)
    opts.tol_con = 0.03 * [other.MIS.perigee_altitude_target; ...
                            other.MIS.apogee_altitude_target; ...
                            other.MIS.target_orbital_inclination];

    % === RUN CALIBRATO SUL REQUISITO "5 MINUTI SUL PC TARGET" (decisione
    %     utente, sessione "requisito 5 minuti", rif. CLAUDE.md S11 Fase 5;
    %     sostituisce il precedente opts.max_eval=50000, stimato ~1 giorno
    %     di calcolo quando la simulazione era ancora interpretata) ========
    % Porting Fortran di eom.m+guidance.m (native/eom_core.f90+eom_oct.cc,
    % 412.9x) e di phase_event.m (native/phase_event_oct.cc, 44.9x) piu'
    % l'eliminazione del ricalcolo di reporting ridondante in
    % create_output.m durante l'ottimizzazione (config.minimal_output in
    % simulator.m: eval_fgh.m legge solo 4 scalari finali, non l'intera
    % storia per-punto) hanno abbattuto il costo per-valutazione: misurato
    % su 30 candidati casuali entro i bounds, media 17ms/eval (mediana
    % 12.9ms, max 93.9ms) -- da ~7.47s/eval originale. => ~17600
    % valutazioni entro 300s su QUESTA macchina di sviluppo (N100, non la
    % Xeon target -- ci si aspetta piu' veloce li', non piu' lento).
    % opts.max_eval sotto e' un margine di sicurezza sotto quella stima
    % (non il tetto teorico) per lasciare spazio a variabilita' reale
    % durante l'ottimizzazione (CMA-ES non campiona uniformemente come il
    % test casuale usato per calibrare). opts.max_iter/opts.max_restarts
    % NON vengono sovrascritti: restano i default CALIBRATI di
    % parse_opts.m (Fase 3, Gate M4), ampi a sufficienza da non diventare
    % il criterio vincolante prima di opts.max_eval.
    opts.max_eval = 12000;

    result = solver(@traj_cost, bounds, opts);

    fprintf('f_best (=-Mpayload) = %.6g  ->  Mpayload = %.6g kg\n', result.f_best, -result.f_best);
    fprintf('feasible = %d\n', result.feasible);
    fprintf('n_eval = %d  n_iter = %d  n_restarts = %d  stop_reason = %s\n', ...
        result.n_eval, result.n_iter, result.n_restarts, result.stop_reason);
