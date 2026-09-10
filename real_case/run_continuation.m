function out = run_continuation(user_opt)
% RUN_CONTINUATION  Ottimizzazione del payload per CONTINUAZIONE a stadi con
%   predittore in massa (procedura, decisione utente 2026-09-09).
%
% Uso:
%   out = run_continuation();                        % default
%   out = run_continuation(struct('n_stage', 6));    % override parziale
%   out = run_continuation(struct('stage_eval', [1500 2000 3000 5000], ...
%                                 'max_restarts', 1));
%
% Default letti da real_case/optimizer_settings.csv (nessun magic number
% nel codice: stesso principio gia' in uso per x0/lb/ub in
% design_variables.csv, rif. local_defaults() sotto). 'user_opt' resta il
% modo per override AD-HOC di una singola run; il CSV e' la sorgente di
% verita' persistente.
%
% ---------------------------------------------------------------------------
% IDEA (proposta utente, validata sperimentalmente prima di essere scritta)
% ---------------------------------------------------------------------------
% 1. Un punto feasible con risorse residue CERTIFICA che tutto il segmento di
%    payload sotto di se' e' DOMINATO (payload minore = vincolo piu' lasco):
%    non va ri-cercato. Si alza quindi lb(Mpayload) a quel livello e si
%    riparte a caldo. Lecito perche' f = -Mpayload dipende da UNA variabile e
%    il limite e' monotono in essa (misurato, sweep 1-D).
% 2. Gli stadi NON devono essere ottimizzazioni a convergenza: basta una
%    soluzione "molto buona", perche' continuazione e predittore recuperano il
%    resto. Da qui il budget PER STADIO configurabile e crescente
%    (opt.stage_eval): stadi iniziali corti, stadi finali piu' ricchi quando
%    il margine si assottiglia.
% 3. Il predittore lavora IN MASSA, non sul margine di delta-v: dato il
%    propellente residuo prop_res di un punto feasible e il rapporto di
%    scambio r = dMpayload/dMprop (proprieta' del veicolo, appresa dai run
%    precedenti e persistita nel seed), il payload raggiungibile si stima
%    come m + r*prop_res.
%
% ---------------------------------------------------------------------------
% PERCHE' IL PREDITTORE E' UN GENERATORE DI BRACKET, NON UNA FORMULA CHIUSA
% (misurato in sessione -- NON assumere altro, rif. CLAUDE.md S7)
% ---------------------------------------------------------------------------
% Il tetto del payload NON e' un esaurimento graduale di risorse: e' una
% BIFORCAZIONE DI TANGENZA. In fase 6 l'apogeo osculante sale e sfiora il
% target; con poco payload in piu' non lo raggiunge, l'evento non scatta e il
% motore brucia fino a esaurimento (END_PROP2, simulator.m case 6).
% Misurato sulla guida del primo seed:
%
%   Mpayload    prop_res    deficit apogeo        g       esito
%      14525     1912.50 kg       0.4 mm      -0.098   feasible
%      14550        0.00 kg     164.5 km      +10      muro
%
% Quindi NESSUNA quantita' attraversa lo zero in modo continuo sul muro:
% prop_res salta da 1912 kg a 0 e il deficit da 0.4 mm a 164 km. Ne segue:
%   - il predittore m + r*prop_res SOVRASTIMA (da 14525 predice ~14992, muro
%     vero 14550): il punto predetto e' quindi un BRACKET SUPERIORE ottenuto
%     con 1 sola valutazione;
%   - la bisezione dentro quel bracket costa ~3 valutazioni invece delle ~9
%     necessarie partendo dal bracket largo [m, ub];
%   - r NON e' costante (0.80 lontano dal muro, 0.24 vicino: la curva e'
%     convessa), per questo viene RI-MISURATO ad ogni coppia di punti e
%     persistito come guess per il run successivo.
%
% TSIOLKOVSKY -- testato, usato SOLO come primo guess (misurato, non assunto).
% Con Delta-v invariante, R = exp(Delta-v/ue) e' costante e il propellente
% bruciato scala con la massa iniziale: il muro sarebbe
%   m_wall = MProp2*(Minert2 + prop_res + m)/(MProp2 - prop_res) - Minert2
% e il rateo di scambio locale r = R/(R-1). Misurato sulla guida del primo
% seed (muro vero 14537 kg):
%   da 14525 kg -> Tsiolkovsky 16802, pendenza misurata 14992
%   da 14000 kg -> Tsiolkovsky 18175, pendenza misurata 15861
% e r = 1.19 (Tsiolkovsky) contro 0.24 (misurato vicino al muro): un fattore
% 5. Il modello sbaglia dal lato OTTIMISTICO perche' ignora due cose reali:
% il Delta-v RICHIESTO cresce col payload (traiettoria piu' lenta, perdite
% gravitazionali maggiori) e il muro e' la tangenza dell'apogeo, non
% l'esaurimento del propellente.
% CONCLUSIONE: come predittore e' peggiore della pendenza misurata, ma e' il
% guess giusto quando NON esistono run precedenti (nessuna pendenza da
% misurare): si calcola dalle masse del veicolo invece di essere scelto a
% mano, e sovrastimando genera subito il bracket superiore. Da qui in avanti
% subentra la pendenza misurata.
%
% Nota fisica utile (non un difetto del metodo): sul muro restano ~1900 kg di
% propellente INUTILIZZABILE, bloccati dalla tangenza. Una guida che faccia
% salire l'apogeo in modo meno tangente li converte in payload -- e'
% esattamente cio' che gli stadi CMA-ES cercano.
%
% ---------------------------------------------------------------------------
% LIMITI DICHIARATI
% ---------------------------------------------------------------------------
% - Il ratchet e' MONOTONO sull'obiettivo: esclude per costruzione un ottimo
%   raggiungibile solo passando per payload piu' bassi di quello certificato.
% - out.Mpayload e' un LOWER BOUND del tetto reale: uno stadio che non trova
%   punti feasible e' un fallimento di RICERCA, non una prova di tetto.
% - sigma0_warm DEVE essere commisurata alla fetta lasciata dal ratchet
%   (~back_off), non al box: con fetta 250 kg e sigma0=0.15 (passo ~2400 kg)
%   uno stadio ha fatto 5000 valutazioni con ZERO punti feasible pur partendo
%   da un x0 feasible (CMA-ES campiona ATTORNO a xmean, non valuta xmean).
%
% Output: struct con Mpayload, x (spazio fisico), g, h, feasible, n_eval,
%         ratio (r appreso), stage_log.

    here = fileparts(mfilename('fullpath'));
    addpath(fullfile(here, '..'));
    addpath(fullfile(here, '..', 'core'));
    addpath(fullfile(here, '..', 'constraints'));
    addpath(fullfile(here, '..', 'io'));
    addpath(fullfile(here, '..', 'de'));
    addpath(here);
    addpath(fullfile(here, '..', 'TSTO', 'source'), '-end');
    addpath(fullfile(here, '..', 'TSTO', 'source', 'native'), '-end');

    if nargin < 1 || isempty(user_opt)
        user_opt = struct();
    end
    opt = local_merge_opts(local_defaults(), user_opt);

    % === portfolio di solver (scelta utente, rif. optimizer_settings.csv) ===
    % Risolto una sola volta qui (non ad ogni stadio): un valore non riconosciuto deve
    % fermare la run PRIMA di qualunque calcolo, non a meta' della continuazione.
    solver_handle = local_solver_from_choice(opt.solver_choice);

    % === dataset e spazio di ricerca ====================================
    other = interface(fullfile(here, '..', 'TSTO', 'input', opt.dataset));
    [x_nom, lb, ub] = local_read_csv(fullfile(here, 'design_variables.csv'), opt.n_design);
    i_pl = opt.i_payload;

    % log_level da optimizer_settings.csv (nessun default: errore se assente)
    other.log_level = opt.log_level;

    tol_con = 0.03 * [other.MIS.perigee_altitude_target; ...
                      other.MIS.apogee_altitude_target; ...
                      other.MIS.target_orbital_inclination];

    % === seed: punto certificato + r appresi da un run precedente ========
    seed_file = fullfile(here, 'warm_start.mat');
    x_warm  = x_nom;
    lb_pl   = lb(i_pl);
    best_x  = [];
    best_pl = -Inf;
    ratio   = opt.ratio_guess;
    n_eval_tot = 0;

    other.opt_bounds.lb = lb;
    other.opt_bounds.ub = ub;

    if exist(seed_file, 'file') == 2
        S = load(seed_file);
        x_seed = S.result.x_best_phys;
        [feas_s, ~, ~, pr_s] = local_eval(x_seed, other, tol_con);
        n_eval_tot = n_eval_tot + 1;
        if feas_s
            if isfield(S, 'ratio') && ~isempty(S.ratio) && isfinite(S.ratio)
                ratio = S.ratio;   % pendenza appresa da un run precedente
            end
            if isempty(ratio)
                fprintf(['\nSeed: %.1f kg feasible, prop_res = %.0f kg, ' ...
                         'r iniziale da Tsiolkovsky\n'], x_seed(i_pl), pr_s);
            else
                fprintf(['\nSeed: %.1f kg feasible, prop_res = %.0f kg, ' ...
                         'r di partenza = %.3f\n'], x_seed(i_pl), pr_s, ratio);
            end
            % Il seed viene spinto subito al proprio muro: guadagno a costo
            % di poche valutazioni, prima di spendere un solo stadio CMA-ES.
            [best_x, best_pl, ratio, n_push] = local_push_to_wall( ...
                x_seed, other, tol_con, ub(i_pl), ratio, opt);
            n_eval_tot = n_eval_tot + n_push;
            fprintf('  push del seed (%d eval, r = %.3f): %.1f -> %.1f kg\n', ...
                    n_push, ratio, x_seed(i_pl), best_pl);
            lb_pl  = max(lb(i_pl), best_pl - opt.back_off);
            x_warm = best_x;
            x_warm(i_pl) = max(lb_pl + opt.bisect_tol, best_pl - opt.x0_retreat);
        else
            fprintf('\nSeed presente ma NON feasible su %s: ignorato.\n', opt.dataset);
        end
    end

    ev = local_stage_vec(opt.stage_eval, opt.n_stage);
    it = local_stage_vec(opt.stage_iter, opt.n_stage);

    fprintf('\n=== CONTINUAZIONE: %d stadi, budget %s eval, %d restart/stadio ===\n', ...
            opt.n_stage, mat2str(ev), opt.max_restarts);

    stage_log = zeros(0, 6);   % [stadio lb_pl x0_pl pl_stadio pl_dopo_push feas]
    n_stall = 0;               % stadi consecutivi senza guadagno

    for s = 1:opt.n_stage
        bounds.lb = lb;
        bounds.ub = ub;
        bounds.lb(i_pl) = lb_pl;
        other.opt_bounds.lb = bounds.lb;
        other.opt_bounds.ub = bounds.ub;

        x0 = x_warm;
        x0(i_pl) = min(max(x0(i_pl), bounds.lb(i_pl)), bounds.ub(i_pl));

        opts = struct();
        opts.other        = other;
        opts.x0           = x0;
        opts.max_time     = Inf;
        if opt.vary_seed
            opts.seed = opt.seed + s - 1;
        else
            opts.seed = opt.seed;
        end
        opts.verbose      = opt.verbose;
        opts.tol_con      = tol_con;
        opts.max_eval     = ev(s);
        opts.max_restarts = opt.max_restarts;
        if isfinite(it(s))
            opts.max_iter = it(s);
        end
        explore = isempty(best_x) || ...
                  (opt.explore_every > 0 && mod(s, opt.explore_every) == 0);
        % Stadio ESPLORATIVO vs CALDO: la differenza sta SOLO nel modo di
        % restart, non nel passo iniziale. Misurato: uno stadio esplorativo
        % avviato con sigma0_cold=0.3 dentro una fetta ammissibile di ~1000 kg
        % rende quasi ogni campione infeasible e non trova nulla (torna x0).
        % La configurazione che ha prodotto il miglior risultato mai misurato
        % (23707 kg) partiva CALDA e lasciava l'esplorazione al re-seeding
        % Sobol dei restart, dopo la convergenza del primo segmento.
        % sigma0_cold resta per il caso "nessun punto noto" (nessun seed).
        if isempty(best_x)
            opts.sigma0       = opt.sigma0_cold;
            opts.restart_mode = 'sobol';
        elseif explore
            opts.sigma0       = opt.sigma0_warm;
            opts.restart_mode = 'sobol';
        else
            opts.sigma0       = opt.sigma0_warm;
            opts.restart_mode = 'auto';
        end

        if isempty(best_x)
            kind = 'cold start';
        elseif explore
            kind = 'ESPLORATIVO (restart Sobol)';
        else
            kind = 'caldo (restart caldo)';
        end
        fprintf(['\n--- stadio %d/%d [%s]: lb = %.0f kg, x0 = %.0f kg, ' ...
                 'sigma0 = %g, budget = %d eval\n'], ...
                s, opt.n_stage, kind, bounds.lb(i_pl), x0(i_pl), opts.sigma0, ev(s));

        % opt.solver_choice (rif. optimizer_settings.csv, portfolio di solver): risolto in
        % solver_handle PRIMA del loop stadi (vedi sopra). Tutto il resto della
        % continuazione (ratchet, predittore in massa, push-to-wall, warm start su x0) e'
        % gia' agnostico rispetto al motore usato per ogni stadio, perche' opera solo su
        % result.x_best_phys/result.feasible/result.n_eval (contratto comune a
        % solver.m/solver_de.m). I campi opts.sigma0/opts.restart_mode/opts.max_restarts
        % impostati sopra sono CMA-ES-specifici: solver_de li ignora senza errori (stesso
        % meccanismo gia' validato in real_case/compare_real_case.m: ogni parser legge solo
        % i propri campi noti) -- per solver_de la distinzione stadio caldo/esplorativo/cold
        % ha quindi effetto SOLO tramite bounds.lb(i_pl) (il ratchet) e opts.x0 (sempre
        % passato, invariato rispetto a prima), non tramite un passo iniziale dedicato: DE
        % non ha un analogo di sigma0_warm, non ne viene aggiunto uno qui apposta per non
        % alterare il confronto "plug and play" in un aiuto su misura (rif. piano di
        % sessione "confronto DE vs CMA-ES+ARCH", risultati in
        % results/de_vs_cmaes_continuation_multiseed.md).
        result = solver_handle(@traj_cost, bounds, opts);
        n_eval_tot = n_eval_tot + result.n_eval;

        xb = result.x_best_phys;
        [feas, ci, ~, pr] = local_eval(xb, other, tol_con);
        n_eval_tot = n_eval_tot + 1;
        pl_stage = xb(i_pl);

        fprintf('    stadio: %.1f kg  g = %.4g  prop_res = %.0f  feasible = %d  (%d eval)\n', ...
                pl_stage, ci(1), pr, feas, result.n_eval);

        if ~feas
            fprintf(['    nessun punto feasible in %d valutazioni ' ...
                     '(fetta ~%.0f kg): si tiene %.1f kg e si esce.\n'], ...
                    result.n_eval, opt.back_off, best_pl);
            stage_log = [stage_log; s, bounds.lb(i_pl), x0(i_pl), pl_stage, best_pl, 0];   %#ok<AGROW>
            break;
        end

        % Il punto dello stadio viene spinto al proprio muro col predittore
        % in massa: e' qui che si incassa il guadagno, non nella ricerca.
        [x_cand, pl_cand, ratio, n_push] = local_push_to_wall( ...
            xb, other, tol_con, ub(i_pl), ratio, opt);
        n_eval_tot = n_eval_tot + n_push;
        fprintf('    push al muro (%d eval, r = %.3f): %.1f -> %.1f kg\n', ...
                n_push, ratio, pl_stage, pl_cand);

        stage_log = [stage_log; s, bounds.lb(i_pl), x0(i_pl), pl_stage, pl_cand, 1];   %#ok<AGROW>

        gain = pl_cand - best_pl;

        % Un miglioramento VERO si accetta sempre, anche se piccolo: min_gain
        % governa QUANDO FERMARSI, non COSA ACCETTARE. (Bug corretto: un push
        % che guadagnava 83 kg veniva contato come stadio a vuoto E il punto
        % scartato, buttando via un miglioramento reale.)
        if pl_cand > best_pl
            best_x  = x_cand;
            best_pl = pl_cand;
        end

        if isfinite(gain) && gain < opt.min_gain
            n_stall = n_stall + 1;
            fprintf(['    guadagno %.1f kg < min_gain (%.0f): stadio a vuoto ' ...
                     '%d/%d (best = %.1f kg).\n'], ...
                    gain, opt.min_gain, n_stall, opt.patience, best_pl);
            if n_stall >= opt.patience
                fprintf('    patience esaurita: stop.\n');
                break;
            end
        else
            n_stall = 0;
        end

        if best_pl >= ub(i_pl) - opt.min_gain
            fprintf('    payload a ub: stop (il box torna vincolante).\n');
            break;
        end

        % Ratchet + warm start, validi sia dopo un guadagno sia dopo uno
        % stadio a vuoto (in entrambi i casi si riparte dal BEST, non dal
        % punto dello stadio).
        lb_pl  = max(lb(i_pl), best_pl - opt.back_off);
        x_warm = best_x;
        x_warm(i_pl) = max(lb_pl + opt.bisect_tol, best_pl - opt.x0_retreat);
    end

    % === esito ==========================================================
    out = struct();
    out.n_eval    = n_eval_tot;
    out.ratio     = ratio;
    out.stage_log = stage_log;

    fprintf('\n=== ESITO (%d valutazioni totali) ===\n', n_eval_tot);
    fprintf('%7s %10s %10s %12s %12s %6s\n', ...
            'stadio', 'lb', 'x0', 'stadio', 'dopo push', 'feas');
    for k = 1:size(stage_log, 1)
        fprintf('%7d %10.0f %10.0f %12.1f %12.1f %6d\n', stage_log(k, :));
    end

    if isempty(best_x)
        fprintf('\nNessun punto feasible certificato.\n');
        out.feasible = 0;
        return;
    end

    names = {'zkick', 'pitch_over_start', 'pitch_c1', 'pitch_c2', ...
             'trans_start', 'pitch_rate_trans', 'insert_start', 'AoA_rate', ...
             'kp', 'Mpayload'};
    fprintf('\n%-18s %10s %12s %12s   %s\n', 'variabile', 'lb', 'x_best', 'ub', 'posizione');
    for k = 1:opt.n_design
        span = ub(k) - lb(k);
        if abs(best_x(k) - lb(k)) <= 1e-9 * max(1, span)
            tag = 'AL LB';
        elseif abs(best_x(k) - ub(k)) <= 1e-9 * max(1, span)
            tag = 'AL UB';
        else
            tag = sprintf('interno (%.1f%%)', 100 * (best_x(k) - lb(k)) / span);
        end
        fprintf('%-18s %10g %12g %12g   %s\n', names{k}, lb(k), best_x(k), ub(k), tag);
    end

    [feas_end, ci_end, ce_end, pr_end] = local_eval(best_x, other, tol_con);
    out.n_eval   = out.n_eval + 1;
    out.x        = best_x;
    out.Mpayload = best_pl;
    out.g        = ci_end;
    out.h        = ce_end;
    out.prop_res = pr_end;
    out.feasible = feas_end;

    fprintf('\nMpayload = %.1f kg   g = %.6g   prop_res = %.0f kg\n', ...
            best_pl, ci_end(1), pr_end);
    fprintf('|h| = [%.6g  %.6g  %.6g]  (perigeo, apogeo, inclinazione)\n', abs(ce_end));
    fprintf('tol = [%.6g  %.6g  %.6g]\n', tol_con);
    fprintf('|h| <= tol = [%d %d %d]  ->  feasible = %d\n', ...
            abs(ce_end) <= tol_con, feas_end);
    fprintf('r appreso = %.4f kg payload / kg propellente\n', ratio);

    % Seed per il prossimo run: punto certificato + r appreso.
    if feas_end
        result = struct('x_best_phys', best_x, 'f_best', -best_pl, 'feasible', 1);
        save('-mat', seed_file, 'result', 'ratio');
        fprintf('Seed aggiornato in %s: il prossimo run riparte da %.1f kg.\n', ...
                seed_file, best_pl);
    end
end


% =====================================================================
% Helper locali
% =====================================================================

function d = local_defaults()
    % Default PROVVISORI: derivano da un solo run misurato (seed 1) su
    % validation_test_2, non da una calibrazione multi-seed (rif. S6.1).
    % Letti da real_case/optimizer_settings.csv (no magic number nel
    % codice, rif. CLAUDE.md S1 principio di genericita': lo stesso
    % principio gia' applicato a x0/lb/ub in design_variables.csv esteso
    % qui ai settings dell'ottimizzatore). Il razionale/le misure dietro
    % ogni valore restano nella colonna 'note' del CSV (versione
    % compatta) e nella cronologia di CLAUDE.md S11 Fase 5 (versione
    % estesa, sessioni "continuazione sul payload"/"procedura di
    % continuazione"/"RELEASE 2.0.0").
    here = fileparts(mfilename('fullpath'));
    d = local_read_settings_csv(fullfile(here, 'optimizer_settings.csv'));
end


function d = local_read_settings_csv(csv_path)
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_continuation:noSettingsCsv', 'Impossibile aprire %s.', csv_path);
    end
    fgetl(fid);   % scarta la riga di intestazione
    d = struct();
    while true
        line = fgetl(fid);
        if ~ischar(line)
            break;
        end
        line = strtrim(line);
        if isempty(line)
            continue;
        end
        tok = strsplit(line);
        if numel(tok) < 3
            fclose(fid);
            error('run_continuation:badSettingsCsv', ...
                  '%s: riga malformata (attesi almeno 3 campi name/value/unit): %s', ...
                  csv_path, line);
        end
        name = tok{1};
        d.(name) = local_parse_setting(name, tok{2});
    end
    fclose(fid);
end


function v = local_parse_setting(name, raw)
    % Conversione esplicita per campo (niente inferenza generica di tipo:
    % un typo nel CSV deve dare un errore leggibile, non un NaN silenzioso).
    switch name
        case 'dataset'
            v = raw;
        case 'vary_seed'
            v = ~(strcmp(raw, '0') || strcmpi(raw, 'false'));
        case 'ratio_guess'
            if strcmpi(raw, 'auto')
                v = [];
            else
                v = str2double(raw);
            end
        case 'log_level'
            v = str2double(raw);
            if isnan(v) || v < 0 || v > 3 || v ~= round(v)
                error('run_continuation:badLogLevel', ...
                      'log_level deve essere 0/1/2/3, letto: %s', raw);
            end
        otherwise
            v = str2double(raw);
            if isnan(v)
                error('run_continuation:badSetting', ...
                      'optimizer_settings.csv: valore non numerico per %s: %s', name, raw);
            end
    end
end


function o = local_merge_opts(d, u)
    % Merge shallow. Campo non riconosciuto -> errore esplicito (meglio di un
    % typo che passa silenzioso).
    o = d;
    f = fieldnames(u);
    for k = 1:numel(f)
        if ~isfield(d, f{k})
            error('run_continuation:badOpt', 'Opzione non riconosciuta: %s', f{k});
        end
        o.(f{k}) = u.(f{k});
    end
end


function h = local_solver_from_choice(choice)
    % Portfolio di solver (rif. optimizer_settings.csv, campo solver_choice): mappa il
    % codice numerico scelto dall'utente all'entry point da usare per OGNI stadio. Errore
    % esplicito su un valore non riconosciuto (nessun default silenzioso, rif. CLAUDE.md S7).
    switch choice
        case 1
            h = @solver;      % CMA-ES+ARCH
        case 2
            h = @solver_de;   % DE+Deb
        otherwise
            error('run_continuation:badSolverChoice', ...
                ['optimizer_settings.csv: solver_choice deve essere 1 (CMA-ES+ARCH) o ' ...
                 '2 (DE+Deb), ricevuto %g.'], choice);
    end
end


function v = local_stage_vec(val, n)
    % Scalare (costante) o vettore per-stadio (esteso con l'ultimo valore).
    if isscalar(val)
        v = val * ones(1, n);
    else
        v = val(:)';
        if numel(v) < n
            v = [v, v(end) * ones(1, n - numel(v))];
        end
        v = v(1:n);
    end
end


function [x0, lb, ub] = local_read_csv(csv_path, n)
    fid = fopen(csv_path, 'r');
    if fid < 0
        error('run_continuation:noCsv', 'Impossibile aprire %s.', csv_path);
    end
    fgetl(fid);
    x0 = zeros(n, 1);
    lb = zeros(n, 1);
    ub = zeros(n, 1);
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
        x0(row) = str2double(tok{4});
        lb(row) = str2double(tok{5});
        ub(row) = str2double(tok{6});
    end
    fclose(fid);
    if row ~= n
        error('run_continuation:badCsv', '%s: attese %d righe, trovate %d.', ...
              csv_path, n, row);
    end
end


function [feas, ci, ce, pr] = local_eval(x, other, tol_con)
    [~, ci, ce, pr] = traj_cost(x, other);
    feas = all(ci <= 0) && all(abs(ce) <= tol_con);
end


function r = local_ratio_tsiolkovsky(m_pl, pr, other)
    % Rateo di scambio payload/propellente sotto l'ipotesi di Delta-v
    % invariante (equazione del razzo): R = m_i/m_f con
    %   m_i = Minert2 + MProp2 + m_pl   (accensione stadio 2)
    %   m_f = Minert2 + prop_res + m_pl (fine missione)
    % e r = dm_pl / (-d prop_res) = R/(R-1).
    % Ottimistico per costruzione (vedi header): serve a generare il bracket
    % superiore, non a centrare il muro.
    D = other.MASS.Minert2;
    P = other.MASS.MProp2;
    R = (D + P + m_pl) / (D + pr + m_pl);
    if R <= 1
        r = 1;
    else
        r = R / (R - 1);
    end
end


function [x_out, m_out, ratio, n_eval] = local_push_to_wall(x_in, other, ...
                                                    tol_con, ub_pl, ratio, opt)
    % PREDICTOR-CORRECTOR in massa: spinge il payload di un punto feasible
    % fino al proprio muro.
    %
    % Predittore : m_try = m + ratio_safety * r * prop_res  (sovrastima ->
    %              genera il bracket superiore con 1 valutazione, vedi header)
    % Correttore : bisezione dentro il bracket ottenuto, fino a bisect_tol.
    % Apprendimento: r ri-misurato come dm/d(prop_res) fra i due punti
    %              feasible piu' vicini al muro (curva convessa: un r unico
    %              non basta).
    i_pl = opt.i_payload;
    n_eval = 0;

    [feas, ~, ~, pr] = local_eval(x_in, other, tol_con);
    n_eval = n_eval + 1;
    if ~feas || ~isfinite(pr) || pr <= 0
        x_out = x_in;
        m_out = x_in(i_pl);
        return;
    end

    x_lo  = x_in;
    m_lo  = x_in(i_pl);
    pr_lo = pr;
    m_hi  = NaN;   % primo payload infeasible noto

    if isempty(ratio) || ~isfinite(ratio) || ratio <= 0
        % Nessuna pendenza misurata disponibile: primo guess da Tsiolkovsky
        % sulle masse del veicolo (rif. header). Sovrastima -> bracket.
        ratio = local_ratio_tsiolkovsky(m_lo, pr_lo, other);
        fprintf('      (r iniziale da Tsiolkovsky: %.3f)\n', ratio);
    end

    % --- fase predittiva -------------------------------------------------
    for k = 1:opt.push_max
        m_try = min(m_lo + opt.ratio_safety * ratio * pr_lo, ub_pl);
        if m_try - m_lo < opt.bisect_tol
            break;
        end
        x_try = x_lo;
        x_try(i_pl) = m_try;
        [feas_t, ~, ~, pr_t] = local_eval(x_try, other, tol_con);
        n_eval = n_eval + 1;
        if feas_t
            d_pr = pr_lo - pr_t;
            if d_pr > 0
                ratio = (m_try - m_lo) / d_pr;
            end
            x_lo  = x_try;
            m_lo  = m_try;
            pr_lo = pr_t;
            if m_lo >= ub_pl - opt.bisect_tol
                break;
            end
        else
            m_hi = m_try;
            break;
        end
    end

    % --- fase correttiva: bisezione nel bracket [m_lo, m_hi] -------------
    if isfinite(m_hi)
        n_bis = 0;
        while (m_hi - m_lo) > opt.bisect_tol && n_bis < opt.bisect_max
            m_mid = 0.5 * (m_lo + m_hi);
            x_try = x_lo;
            x_try(i_pl) = m_mid;
            [feas_t, ~, ~, pr_t] = local_eval(x_try, other, tol_con);
            n_eval = n_eval + 1;
            n_bis  = n_bis + 1;
            if feas_t
                d_pr = pr_lo - pr_t;
                if d_pr > 0
                    ratio = (m_mid - m_lo) / d_pr;
                end
                x_lo  = x_try;
                m_lo  = m_mid;
                pr_lo = pr_t;
            else
                m_hi = m_mid;
            end
        end
    end

    x_out = x_lo;
    m_out = m_lo;
end
