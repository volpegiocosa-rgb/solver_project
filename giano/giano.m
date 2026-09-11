function out = giano(cfg)
% GIANO  Interface function per l'uso di solver_project v3.0.0 (CMA-ES+ARCH
%   / DE+Deb + simulatore TSTO) dentro un programma Matlab piu' grande.
%
% VERSIONE: 1.0.0
%
% STATO (Gate 1-7 completati, rif. giano-design.md): implementazione
%   completa. Espone entrambi i motori (CMA-ES+ARCH, DE+Deb) ed entrambe
%   le modalita' (single-run, continuation-ratchet self-contained in
%   memoria) gia' presenti in solver_project v3.0.0, senza alcuna lettura
%   o scrittura su file (verificato ripetutamente con snapshot
%   filesystem prima/dopo, rif. giano-design.md per il dettaglio di ogni
%   gate). Non ancora fatto: packaging dello zip di release e
%   compilazione dei .mexw64 su Windows (Gate 8-10, rif. GAP-001 --
%   nessun MATLAB Windows disponibile nell'ambiente di sviluppo; il
%   fallback interpretato Octave/MATLAB funziona comunque senza alcun
%   passo aggiuntivo).
%
% REGOLA VINCOLANTE (rif. road-to-3-1-0.md, giano-design.md CON-001):
%   giano.m NON legge ne' scrive file. Tutti i dati che nella pipeline
%   originale (solver_project/real_case/*.m, TSTO/source/interface.m)
%   venivano letti da CSV arrivano qui GIA' come struct/sub-struct di
%   'cfg'. Ogni file CSV originario diventa una sub-struct di 'cfg' e ogni
%   RIGA del CSV diventa un CAMPO NOMINATO di quella sub-struct (accesso
%   per nome, mai per posizione/ordine -- rif. giano-design.md H10).
%
% =====================================================================
% INPUT: cfg (struct, un unico argomento aggregatore)
% =====================================================================
%
% --- Sub-struct che rispecchiano i CSV originari di TSTO/input/<dataset> ---
% (mapping identico a TSTO/interface_specification.md S2, TSTO/source/
%  interface.m -- qui per struct, non per file)
%
%   cfg.LV               (ex LV.csv, veicolo, valori per singolo motore)
%       .Sref, .Mfairing, .M0, .Minert1, .Minert2, .MProp1, .MProp2,
%       .Thrust1, .Thrust2, .MR1, .MR2, .Aexit1, .Aexit2,
%       .n_engine1, .n_engine2, .Mpayload
%       (Mpayload qui e' il valore NOMINALE di LV.csv; il valore
%       effettivamente usato in ottimizzazione e' quello di
%       cfg.design_variables.Mpayload, che lo sovrascrive -- stesso
%       comportamento di traj_problem.m oggi)
%
%   cfg.ENV              (ex ENV.csv, ambiente)
%       .Req, .Rpole, .f, .omega_E, .mu, .lat, .lon, .hpad
%
%   cfg.atmosphere        (ex atmosphere.csv, tabellare vs quota)
%       .altitude, .PAtm, .rho, .Vsound   (vettori colonna, stessa lunghezza)
%
%   cfg.aero_ascent        (ex aero_ascent.csv, griglia 2D)
%       .Mach   (vettore, righe)
%       .AoA    (vettore, colonne, gradi)
%       .Cd     (matrice Cd(Mach,AoA), per interp2)
%
%   cfg.GUID               (ex GUID.csv, guida non ottimizzata)
%       .AZ, .timeHS_Sep_control, .flux_HS_Sep
%
%   cfg.GUIDANCE_VARS       (ex GUIDANCE_VARS.csv, baseline "pristine")
%       .zkick, .pitch_over_starting, .pitch_c1, .pitch_c2,
%       .transition_starting, .pitch_rate_transition,
%       .pitch_at_transition, .insertion_starting, .AoA_rate,
%       .plane_controller_kp, .plane_controller_kd, .plane_controller_ki
%       (baseline prima della sovrascrittura da parte delle variabili di
%       design; plane_controller_kd/ki e pitch_at_transition NON sono
%       variabili di design e restano fissi a questi valori -- rif.
%       giano-design.md H9)
%
%   cfg.MIS                 (ex MIS.csv, missione)
%       .apogee_altitude_target, .perigee_altitude_target,
%       .target_orbital_inclination
%
% --- Variabili di design (ex real_case/design_variables.csv) ---
%
%   cfg.design_variables   (struct con ESATTAMENTE i 10 campi sotto,
%                           accesso per NOME -- rif. giano-design.md H10:
%                           l'ordine con cui i campi compaiono in 'cfg'
%                           non conta, la corrispondenza fisica e' per
%                           nome del campo, non per posizione)
%       Ciascun campo e' a sua volta una struct con .x0 .lb .ub
%       (opzionale .unit, solo documentale, NON usato per la conversione
%       deg->rad: quella e' dedotta a runtime dal nome del campo, vedi
%       Gate 3 / giano-design.md H4):
%         .zkick                 [m]
%         .pitch_over_starting   [s]
%         .pitch_c1              [deg/s^2]
%         .pitch_c2              [deg/s]
%         .transition_starting   [s]
%         .pitch_rate_transition [deg/s]
%         .insertion_starting    [s]
%         .AoA_rate              [deg/s]
%         .plane_controller_kp   [-]
%         .Mpayload              [kg]
%       Questo insieme di 10 nomi e' un CONTRATTO FISSO con
%       TSTO/source/traj_problem.m (stesso ordine fisico di oggi, rif.
%       header traj_problem.m): giano.m assembla il vettore x guardando
%       questi campi per nome, non riprendendo l'ordine di inserimento
%       in cfg.design_variables.
%
% --- Opzioni di ottimizzazione/continuazione/log (ex optimizer_settings.csv
%     + valori oggi cablati in real_case/run_real_case.m e
%     real_case/run_continuation.m, rif. giano-design.md audit H1-H12) ---
%
%   cfg.opts
%       .solver_choice   1 = CMA-ES+ARCH (solver.m, default) |
%                        2 = DE+Deb (solver_de.m)
%       .mode            'single' = un solo run (ex run_real_case.m) |
%                        'continuation' = ratchet multi-stadio in memoria
%                        (ex run_continuation.m, SENZA warm_start.mat su
%                        disco -- rif. cfg.warm_state / out.warm_state
%                        sotto, giano-design.md H12)
%       .tol_con         vettore 3x1 ASSOLUTO (perigeo, apogeo,
%                        inclinazione), OBBLIGATORIO se n_eq>0 (nessun
%                        default 3% implicito -- rif. H1)
%       .seed, .verbose, .log_level (0-3, verbosita' di out.opt_log)
%       .max_iter, .max_eval, .max_time, .tol_fun, .tol_x, .sigma0,
%       .init_mode, .multistart, .restart_ipop, .max_restarts,
%       .restart_mode, .restart_jitter, .polish_opt
%           (rif. io/parse_opts.m per semantica e default CALIBRATI;
%           campi mancanti ricadono sugli stessi default di solver.m)
%       .pop_size, .F, .CR
%           (solo se solver_choice=2, rif. io/parse_opts_de.m)
%       .n_stage, .stage_eval, .stage_iter, .vary_seed, .explore_every,
%       .back_off, .ratio_guess, .ratio_safety, .push_max, .bisect_tol,
%       .bisect_max, .min_gain, .patience, .x0_retreat
%           (solo se mode='continuation', rif.
%           real_case/optimizer_settings.csv per semantica e default)
%       .tmax_phase, .tmin, .tmax, .step_frac
%           (opzionali, passthrough a simulator.m/rk5.m/kinematic_step.m,
%           default = quelli attuali del simulatore se assenti -- H11.
%           NON .AbsTol/.RelTol: verificato che nessun punto del codice
%           li legge piu' da quando ode45 e' stato sostituito da rk5.m,
%           rif. sotto)
%
% --- Stato di continuazione (opzionale, solo mode='continuation') ---
%
%   cfg.warm_state   (opaco, struct restituita da una chiamata precedente
%                    in out.warm_state; assente/[] alla prima chiamata.
%                    giano.m non lo persiste mai su disco: la
%                    persistenza fra chiamate successive e' responsabilita'
%                    del chiamante -- rif. giano-design.md H12)
%
% =====================================================================
% OUTPUT: out (struct)
% =====================================================================
%
%   out.RES           struct completa (TSTO/interface_specification.md
%                     S3), ottenuta con UNA ri-simulazione aggiuntiva del
%                     solo punto migliore a fine ottimizzazione (rif. H8:
%                     durante il loop principale si usa sempre
%                     config.minimal_output=true, RES completa non e' mai
%                     calcolata li'). [] se mode='continuation' e nessun
%                     punto feasible e' mai stato certificato.
%   out.opt_log       diagnostica del processo di ottimizzazione, dettaglio
%                     dipendente da cfg.opts.log_level (0-3, stessa
%                     semantica di real_case/traj_cost.m ma accumulata in
%                     memoria, mai su file -- rif. H6). NOTA (verificata
%                     in Gate 5a): numel(out.opt_log) puo' essere
%                     leggermente MAGGIORE di out.n_eval -- il secondo
%                     conta solo le valutazioni del loop principale
%                     (cmaes_core.m), il primo registra OGNI chiamata
%                     all'obiettivo, incluse quelle del feasibility-polish
%                     finale (arch_repair.m, rif. solver.m). Non e' un
%                     disallineamento: sono due conteggi con scopo diverso.
%   out.x_best        struct con i 10 campi di cfg.design_variables
%                     valorizzati al punto migliore trovato (stessi nomi,
%                     accesso per nome coerente con l'input)
%   out.f_best        valore dell'obiettivo (= -Mpayload) al punto migliore
%   out.Mpayload      = -out.f_best, comodo alias (rif. OPT.f in
%                     TSTO/interface_specification.md S5.1)
%   out.feasible      true/false, per-vincolo entro cfg.opts.tol_con
%   out.n_eval, out.n_iter, out.stop_reason
%                     mode='single': rif. campi analoghi di result in
%                     solver.m/solver_de.m. mode='continuation': n_eval e'
%                     il totale su seed+stadi+verifica finale, n_iter e'
%                     il numero di STADI eseguiti (non generazioni), rif.
%                     out.stage_log per il dettaglio per-stadio.
%   out.n_restarts    mode='single': rif. result.n_restarts. mode=
%                     'continuation': [] -- ogni stadio lancia il motore
%                     scelto con i propri restart interni, nessun totale
%                     univoco significativo (rif. out.stage_log/opt_log
%                     per il dettaglio), dichiarato invece di un numero
%                     fuorviante.
%   out.stage_log     SOLO mode='continuation': matrice Sx6, una riga per
%                     stadio eseguito = [stadio, lb_pl_usato, x0_pl_usato,
%                     pl_stadio, pl_dopo_push, feasible_stadio] (stesso
%                     formato di real_case/run_continuation.m)
%   out.warm_state    stato aggiornato del ratchet (solo mode='continuation';
%                     [] altrimenti) -- rif. cfg.warm_state sopra
%   out.giano_version '1.0.0'
%
% =====================================================================
% Traceability: rif. giano-design.md (Gate 1-10) per il piano completo,
% road-to-3-1-0.md per la specifica originale.

    out = struct();
    out.giano_version = '1.0.0';

    % === guard di base: presenza dei campi di primo livello di cfg =======
    % Nessuna logica oltre questo punto in Gate 1 (rif. giano-design.md,
    % piano per gate): qui si verifica solo che il chiamante abbia
    % fornito la forma attesa del contratto, cosi' un uso prematuro di
    % questa function fallisce con un messaggio leggibile invece che con
    % un errore di campo mancante profondo dentro la pipeline.
    if nargin < 1 || ~isstruct(cfg)
        error('giano:noConfig', ...
            'giano(cfg): cfg deve essere una struct (rif. header giano.m per il contratto completo).');
    end

    required_top_level = {'LV', 'ENV', 'atmosphere', 'aero_ascent', ...
                           'GUID', 'GUIDANCE_VARS', 'MIS', ...
                           'design_variables', 'opts'};
    missing = required_top_level(~isfield(cfg, required_top_level));
    if ~isempty(missing)
        error('giano:missingField', ...
            'cfg manca dei campi obbligatori: %s (rif. header giano.m).', ...
            strjoin(missing, ', '));
    end

    % Ordine/elenco delle 10 variabili di design: fonte unica in
    % giano_design_var_order.m (Gate 3), non piu' duplicato qui (rif.
    % giano-design.md H10).
    required_design_vars = giano_design_var_order();
    missing_dv = required_design_vars(~isfield(cfg.design_variables, required_design_vars));
    if ~isempty(missing_dv)
        error('giano:missingDesignVariable', ...
            ['cfg.design_variables manca dei campi obbligatori: %s -- ' ...
             'contratto fisso con TSTO/source/traj_problem.m, rif. ' ...
             'giano_design_var_order.m e giano-design.md H10.'], strjoin(missing_dv, ', '));
    end

    % === tol_con esplicito (rif. giano-design.md H1: nessun default 3%) ==
    % TSTO produce SEMPRE 3 vincoli di uguaglianza (perigeo/apogeo/
    % inclinazione, rif. TSTO/interface_specification.md S5.1): non e' un
    % numero da parametrizzare, e' una proprieta' strutturale fissa
    % dell'applicazione che giano.m avvolge (stesso ruolo di
    % real_case/traj_cost.m oggi).
    if ~isfield(cfg.opts, 'tol_con') || isempty(cfg.opts.tol_con)
        error('giano:missingTolCon', ...
            ['cfg.opts.tol_con obbligatorio (vettore 3x1 ASSOLUTO: ' ...
             'perigeo, apogeo, inclinazione) -- nessun default implicito ' ...
             '(rif. giano-design.md H1). L''implementazione di riferimento ' ...
             '(real_case/run_real_case.m) usava il 3%% dei target come ' ...
             'esempio, non come default incorporato qui.']);
    end
    if numel(cfg.opts.tol_con) ~= 3
        error('giano:badTolCon', ...
            'cfg.opts.tol_con deve avere 3 componenti (perigeo,apogeo,inclinazione), ricevute %d.', ...
            numel(cfg.opts.tol_con));
    end
    if any(cfg.opts.tol_con(:) <= 0)
        error('giano:badTolCon', 'cfg.opts.tol_con deve avere tutte le componenti > 0.');
    end

    % === adapter variabili di design (Gate 3): assemblaggio per nome ====
    [x0, lb, ub, ang_idx, i_payload] = giano_build_design_vectors(cfg.design_variables);

    % === adapter fisico (Gate 2): CSV->other, zero file I/O ==============
    other = giano_build_other(cfg);

    % --- supporto per giano_traj_cost.m (Gate 4): bounds/ang_idx/log_level
    %     viaggiano dentro 'other', invariati per l'intero run (stessa
    %     convenzione di real_case/traj_cost.m -> other.opt_bounds) -------
    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;
    other.ang_idx        = ang_idx;
    if isfield(cfg.opts, 'log_level') && ~isempty(cfg.opts.log_level)
        other.log_level = cfg.opts.log_level;
    else
        other.log_level = 0;
        % Default silenzioso ma A BASSO RISCHIO (diverso da H1/tol_con):
        % log_level cambia solo il DETTAGLIO della diagnostica restituita
        % in out.opt_log, mai il risultato numerico dell'ottimizzazione --
        % quindi un default qui non nasconde un'assunzione che altera il
        % comportamento, dichiarato comunque esplicitamente.
    end

    % --- passthrough opzionale a simulator.m/rk5.m/kinematic_step.m (H11):
    %     other.STEP.frac e' letto DIRETTAMENTE da kinematic_step.m (via
    %     other), tmax_phase/tmin/tmax viaggiano invece come 3o argomento
    %     di traj_problem.m (rif. giano_traj_cost.m) o come config.* per
    %     la ri-simulazione diretta (rif. giano_full_res.m). AbsTol/RelTol
    %     ESCLUSI deliberatamente: verificato (grep su TSTO/source) che
    %     ode45 e' stato sostituito da rk5.m (integratore a passo fisso
    %     cinematico, non a controllo d'errore) e nessun punto del codice
    %     legge piu' config.AbsTol/RelTol -- traj_problem.m li accetta e
    %     inoltra SOLO per compatibilita' con vecchi chiamanti, ma
    %     simulator.m non li consulta mai (confermato: le uniche
    %     occorrenze in simulator.m sono commenti, nessuna lettura di
    %     config.AbsTol/RelTol). Esporli qui sarebbe un'opzione che non fa
    %     nulla: eliminata invece di documentata come "senza effetto".
    %     Nessun campo impostato se il chiamante non fornisce
    %     tmax_phase/tmin/tmax: restano i default interni di simulator.m
    %     (0.05/2/1000 s, frac 0.05, TODO PROVVISORIO in quel file, non
    %     calibrati qui ne' altrove). --
    if isfield(cfg.opts, 'step_frac') && ~isempty(cfg.opts.step_frac)
        other.STEP.frac = cfg.opts.step_frac;
    end
    sim_opts_fields = {'tmax_phase', 'tmin', 'tmax'};
    sim_opts = struct();
    for k = 1:numel(sim_opts_fields)
        fname = sim_opts_fields{k};
        if isfield(cfg.opts, fname) && ~isempty(cfg.opts.(fname))
            sim_opts.(fname) = cfg.opts.(fname);
        end
    end
    if ~isempty(fieldnames(sim_opts))
        other.sim_opts = sim_opts;
    end

    % === selezione motore/modalita' (rif. cfg.opts.solver_choice/.mode) ==
    if isfield(cfg.opts, 'mode') && ~isempty(cfg.opts.mode)
        run_mode = cfg.opts.mode;
    else
        run_mode = 'single';
    end
    if isfield(cfg.opts, 'solver_choice') && ~isempty(cfg.opts.solver_choice)
        solver_choice = cfg.opts.solver_choice;
    else
        solver_choice = 1;
    end
    if ~(solver_choice == 1 || solver_choice == 2)
        error('giano:badSolverChoice', ...
            'cfg.opts.solver_choice deve essere 1 (CMA-ES+ARCH) o 2 (DE+Deb), ricevuto %d.', ...
            solver_choice);
    end

    if ~(strcmp(run_mode, 'single') || strcmp(run_mode, 'continuation'))
        error('giano:badMode', ...
            'cfg.opts.mode deve essere ''single'' o ''continuation'', ricevuto ''%s''.', run_mode);
    end

    bounds = struct();
    bounds.lb = lb;
    bounds.ub = ub;

    if solver_choice == 1
        engine = @solver;
    else
        engine = @solver_de;
    end

    order = giano_design_var_order();

    if strcmp(run_mode, 'single')
        % =================================================================
        % Gate 5a/5b: single-run, CMA-ES+ARCH o DE+Deb (porting di
        % real_case/run_real_case.m / run_real_case_de.m, zero file I/O,
        % zero valori cablati -- tutti gli opts arrivano da cfg.opts, rif.
        % giano-design.md audit H1-H7/H11). Stesso identico bounds/
        % wrapper/assemblaggio di out per entrambi i motori: solver.m e
        % solver_de.m condividono contratto di chiamata e forma di
        % 'result' (rif. solver_de.m header "mirror strutturale di
        % solver.m"), quindi non serve duplicare la logica per motore.
        % =================================================================

        % opts per solver.m/solver_de.m: si parte da cfg.opts cosi' com'e'
        % -- i campi specifici dell'altro motore/della continuazione/
        % log_level/mode/solver_choice che contiene sono IGNORATI in modo
        % innocuo da parse_opts.m/parse_opts_de.m (iterano solo su
        % fieldnames(defaults), non su fieldnames(opts), rif. io/
        % parse_opts_de.m per la nota gia' verificata su quel layer).
        solver_opts = cfg.opts;
        solver_opts.other = other;
        solver_opts.x0    = x0;

        giano_eval_log('reset');
        result = engine(@giano_traj_cost, bounds, solver_opts);
        opt_log = giano_eval_log('get');

        out.x_best = struct();
        for k = 1:numel(order)
            out.x_best.(order{k}) = result.x_best_phys(k);
        end
        out.f_best    = result.f_best;
        out.Mpayload  = -result.f_best;
        out.feasible  = result.feasible;
        out.n_eval    = result.n_eval;
        out.n_iter    = result.n_iter;
        out.n_restarts = result.n_restarts;
        out.stop_reason = result.stop_reason;
        out.opt_log   = opt_log;
        out.warm_state = [];   % mode='single': nessun ratchet, nessuno stato da riportare

        % === Gate 6: RES completo sul solo punto migliore ================
        out.RES = giano_full_res(result.x_best_phys, other);

    else
        % =================================================================
        % Gate 5c: continuation-ratchet self-contained in memoria (porting
        % di real_case/run_continuation.m, zero file I/O -- warm_start.mat
        % sostituito da cfg.warm_state/out.warm_state, rif. H12). Logica
        % di orchestrazione in giano_run_continuation.m (Gate 5c-3), che
        % compone giano_continuation_stage.m (5c-2) e
        % giano_push_to_wall.m/giano_eval_feasibility.m (5c-1).
        % =================================================================

        % --- default dei campi di continuazione (rif.
        %     real_case/optimizer_settings.csv per la derivazione/misura
        %     di ciascun valore, cronologia in CLAUDE.md S11 Fase 5,
        %     sessioni "continuazione sul payload"/"RELEASE 2.0.0";
        %     campi mancanti in cfg.opts ricadono su questi -- stesso
        %     principio di rischio-basso gia' usato per log_level sopra:
        %     valori di TUNING della ricerca, non un'assunzione come
        %     tol_con che altererebbe silenziosamente cosa viene accettato
        %     come soluzione) ---
        copts_defaults = struct( ...
            'n_stage', 8, 'stage_eval', 2500, 'stage_iter', Inf, ...
            'max_restarts', 3, 'sigma0_cold', 0.3, 'sigma0_warm', 0.03, ...
            'explore_every', 2, 'back_off', 1000, 'ratio_guess', [], ...
            'ratio_safety', 1.0, 'push_max', 3, 'bisect_tol', 50, ...
            'bisect_max', 8, 'min_gain', 100, 'patience', 3, ...
            'x0_retreat', 500, 'vary_seed', true, 'seed', 1, 'verbose', 0);
        copts = copts_defaults;
        cf = fieldnames(copts_defaults);
        for k = 1:numel(cf)
            if isfield(cfg.opts, cf{k}) && ~isempty(cfg.opts.(cf{k}))
                copts.(cf{k}) = cfg.opts.(cf{k});
            end
        end

        if isfield(cfg, 'warm_state')
            warm_state_in = cfg.warm_state;
        else
            warm_state_in = [];
        end

        [res, opt_log] = giano_run_continuation(other, lb, ub, cfg.opts.tol_con, ...
            i_payload, x0, engine, copts, warm_state_in);

        out.x_best = struct();
        if isempty(res.x)
            for k = 1:numel(order)
                out.x_best.(order{k}) = NaN;
            end
        else
            for k = 1:numel(order)
                out.x_best.(order{k}) = res.x(k);
            end
        end
        out.f_best    = res.f_best;
        out.Mpayload  = res.Mpayload;
        out.feasible  = res.feasible;
        out.n_eval    = res.n_eval;
        out.n_iter    = res.n_stage_run;
        % n_restarts non ha un analogo diretto in continuazione (ogni
        % stadio lancia il motore scelto con i propri restart interni,
        % rif. giano_continuation_stage.m): lasciato vuoto invece di un
        % numero fuorviante, il dettaglio per-stadio e' in out.stage_log.
        out.n_restarts = [];
        out.stop_reason = res.stop_reason;
        out.opt_log   = opt_log;
        out.stage_log = res.stage_log;
        out.warm_state = res.warm_state;

        % === Gate 6: RES completo sul solo punto migliore =================
        % [] se nessun punto feasible e' mai stato certificato (res.x
        % vuoto): non c'e' nulla da ri-simulare.
        if isempty(res.x)
            out.RES = [];
        else
            out.RES = giano_full_res(res.x, other);
        end
    end

end
