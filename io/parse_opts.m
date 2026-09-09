function opts = parse_opts(opts, n)
% PARSE_OPTS  Validazione e default degli opts (rif. CLAUDE.md S6, S6.1).
%   Dimensiona i vettori per-vincolo sul numero EFFETTIVO di vincoli a runtime
%   (n_eq non e' noto qui: tol_con resta [] finche' /constraints, Fase 2, non
%   lo dimensiona sulla prima valutazione di ceq).
%
% STATO (rif. CLAUDE.md S11, Gate M4 -- PASS): i default numerici sono
%   CALIBRATI sull'esecuzione reale della suite Fase A (benchmark/
%   run_benchmarks.m), non piu' provvisori. Derivazione e limiti di validita'
%   documentati inline sui singoli campi (max_iter/eps_horizon/max_eval in
%   particolare). Restano input APPLICATIVI (mai calibrabili sui benchmark,
%   rif. CLAUDE.md S6.1 punto 4): tol_con, max_time.
%
%   INPUT  : opts  struct utente (campi mancanti -> default), n dimensione
%   OUTPUT : opts  struct completata

    if nargin < 1 || isempty(opts)
        opts = struct();
    end

    % lambda di riferimento (Hansen, S6.1 punto 1): SOLO per calibrare i
    % default euristici di max_iter/max_eval qui sotto, non e' un opts.*
    % (lambda vero e proprio e' calcolato in core/init_state.m da n).
    lambda_ref = 4 + floor(3 * log(n));

    % === CALIBRATO, Fase 3 (rif. CLAUDE.md S6.1, S11 Gate M4) ===============
    % Sostituisce i default provvisori con valori derivati dall'esecuzione
    % REALE della suite Fase A (benchmark/run_benchmarks.m: sphere n=25,
    % bench_rosenbrock_con n=2, g13 n=5, 10 seed ciascuno) DOPO la correzione
    % di un bug trovato proprio durante questa calibrazione (rif.
    % core/cmaes_core.m, f_hist_seg/iter_seg): il criterio tol_fun usava il
    % best-feasible GLOBALE (mai decrescente da un restart all'altro) come
    % segnale di plateau, facendo scattare "convergenza" alla primissima
    % generazione di OGNI restart successivo al primo -- i restart IPOP non
    % avevano mai la possibilita' di cercare. Prima del fix, g13 (8 seed):
    % 3/8 ottimo globale; dopo il fix, g13 (10 seed, stesso identico budget
    % del default precedente, max_iter=1232): 4/10 ottimo globale MA 10/10
    % feasible (il gate M3 originale, basato sulla sola feasibility, resta
    % valido). Isolando l'effetto del solo budget (eps_horizon lasciato
    % INVARIATO a 1232, max_iter portato a 2500, max_eval sciolto):
    % 10/10 ottimo globale su g13. La eps_horizon di partenza (1232) risulta
    % gia' adeguata: il fattore mancante era dare al motore, DOPO che lo
    % schedule di eps_eq ha raggiunto tol_con, margine sufficiente perche' i
    % restart IPOP (ora funzionanti) possano effettivamente rifinire la
    % ricerca sotto la banda stretta. Da cui la relazione calibrata:
    %   eps_horizon = formula originale (INVARIATA, gia' adeguata)
    %   max_iter    = 2 * eps_horizon   (margine di ricerca post-schedule,
    %                                    verificato: 10/10 ottimo globale g13
    %                                    a n=5, margine ~2x sopra la soglia
    %                                    minima osservata di 1232, non e' un
    %                                    valore esatto di transizione)
    % NOTA (onesta, non nascosta): la stessa dinamica NON e' stata replicata
    % su bench_rosenbrock_con (n=2, sole disuguaglianze, nessuna eps_horizon
    % in gioco): anche a budget molto piu' ampio (max_iter=5000,
    % max_eval=2e5) il success-rate sul target f<=1e-3 resta 0/10 (miglior
    % risultato f=0.002, un'ordine di grandezza dal target; 4/10 seed restano
    % intrappolati su un attrattore locale f=0.9989 -- verificato NON essere
    % un punto KKT, quindi non un minimo vincolato genuino, solo un plateau
    % difficile da attraversare per il ranking/repair attuale sulle sole
    % disuguaglianze). Gap noto, coerente con quello gia' documentato in
    % constraints/arch_rank.m (manca un eps_ineq/scala per-vincolo per le
    % disuguaglianze, analogo a eps_eq): NON risolto qui, lasciato aperto per
    % Fase 5 (rif. CLAUDE.md S11). I default sotto sono quindi calibrati
    % principalmente sul caso con UGUAGLIANZE (g13), strutturalmente piu'
    % vicino al caso reale (n_eq=3 in entrambi) rispetto a sphere/rosenbrock.
    defaults.eps_horizon = ceil(100 + 50 * (n + 3)^2 / sqrt(lambda_ref));
    % Orizzonte in iterazioni entro cui lo schedule di eps_eq deve raggiungere
    % tol_con (rif. eps_schedule.m, CLAUDE.md S5.2). NON e' opts.max_iter:
    % l'orizzonte dello schedule e' una proprieta' del PROBLEMA (quante
    % generazioni serve a CMA-ES per stringere la distribuzione in dimensione
    % n), non del budget che l'utente concede (vedi nota sopra sul bug
    % trovato quando i due erano legati: un run piu' lungo poteva lasciare la
    % banda troppo larga per sempre, NESSUN punto entro tol_con su 8/8 seed).
    defaults.max_iter = 2 * defaults.eps_horizon;
    defaults.max_eval = defaults.max_iter * lambda_ref * 50;
    % Margine di sicurezza (non un budget "stretto"): con IPOP il lambda
    % raddoppia a ogni restart (fino a opts.max_restarts=9, cioe' fino a
    % lambda_ref*2^9), quindi il costo in valutazioni di un run che usa tutti
    % i restart NON scala come n^2 (formula precedente) ma e' dominato dal
    % lambda dell'ULTIMO restart raggiunto. Misurato su g13 (n=5,
    % lambda_ref=8) a max_iter=2500: costo peggiore osservato 431088
    % valutazioni (seed che raggiungono n_restarts=9). La formula qui
    % (max_iter*lambda_ref*50 = 985600 per n=5) resta sopra questo
    % osservato con margine (~2.3x), senza pero' pretendere di derivare
    % analiticamente la costante 50 (fudge factor empirico, non un valore di
    % letteratura). Per n grandi (caso reale, n~20-25) il valore cresce
    % molto (dominato da lambda_ref*2^9 nello scenario peggiore) e
    % diventera' verosimilmente NON vincolante rispetto a max_iter/max_time
    % -- coerente con S6.1 punto 4: sul caso reale il budget di valutazioni
    % resta comunque una decisione applicativa (Fase 5), qui solo un tetto
    % di sicurezza generico.
    defaults.max_time = Inf;
    % input applicativo (S6): nessun limite finche' l'utente non lo fornisce
    defaults.tol_con = [];
    % per-vincolo, input applicativo (S6): dimensionato a runtime su n_eq (Fase 2)
    defaults.tol_fun = 1e-12;
    % CALIBRATO (Fase 3): invariato rispetto al valore provvisorio. Nessuna
    % run della suite (sphere/g13, post-fix) ha mostrato convergenza precoce
    % o mancata spuria legata a questa soglia (verificato: il bug del
    % criterio di plateau, ora corretto, era la causa reale dei falsi
    % positivi osservati in precedenza, non il valore numerico di tol_fun).
    defaults.tol_x = 1e-11;
    % CALIBRATO (Fase 3): invariato, stessa verifica di tol_fun sopra.
    defaults.x0 = [];
    defaults.sigma0 = 0.3;
    % CALIBRATO (Fase 3): regola 1/3 di Hansen su [0,1] (rif. CLAUDE.md S5.1),
    % non ridimostrata da zero ma validata indirettamente: nessuna run della
    % suite Fase A ha mostrato un fallimento riconducibile a sigma0 (ne'
    % copertura iniziale insufficiente ne' divergenza immediata).
    defaults.init_mode = 'sobol';
    defaults.multistart = 1;
    defaults.seed = 1;
    defaults.restart_ipop = true;
    defaults.max_restarts = 9;
    % restart_mode (decisione utente 2026-09-09): come si sceglie il nuovo
    % centro a ogni restart IPOP.
    %   'auto'   -> caldo (attorno al miglior punto AMMISSIBILE noto) se ne
    %               esiste uno, Sobol+jitter altrimenti. Default: ripartire da
    %               Sobol ha senso solo quando non si sa ancora nulla.
    %   'sobol'  -> sempre Sobol+jitter (comportamento pre-2.0.0).
    %   'warm'   -> sempre caldo se possibile (Sobol solo come fallback).
    % Rif. core/ipop_restart.m per la misura che ha motivato il cambio.
    defaults.restart_mode = 'auto';
    % Ampiezza del jitter del restart caldo, in spazio normalizzato.
    % TODO: PROVVISORIO -- non calibrato (scelto ~3x il sigma0 tipico dei run
    % di continuazione, 0.03, per dare margine di fuga da uno stallo senza
    % perdere il bacino).
    defaults.restart_jitter = 0.1;
    % CALIBRATO (Fase 3): validato, non solo ereditato. Su g13 (n=5, 10 seed,
    % max_iter=2500) il numero di restart usati dai run che raggiungono
    % l'ottimo globale varia da 5 a 9 -- il tetto a 9 non e' mai risultato
    % troppo stretto negli scenari testati.
    defaults.polish_opt = false;
    % NON un default calibrabile sui benchmark (rif. CLAUDE.md S5.3b): scelta
    % di progetto esplicita, stub disattivato finche' l'utente non dichiara
    % la guida localmente liscia vicino all'ottimo.
    defaults.verbose = 0;
    defaults.other = [];

    fnames = fieldnames(defaults);
    for k = 1:numel(fnames)
        key = fnames{k};
        if ~isfield(opts, key) || isempty(opts.(key))
            opts.(key) = defaults.(key);
        end
    end

    if ~(strcmp(opts.init_mode, 'sobol') || strcmp(opts.init_mode, 'center'))
        error('parse_opts:badInitMode', 'opts.init_mode deve essere ''sobol'' o ''center''.');
    end
    if strcmp(opts.init_mode, 'sobol') && isempty(opts.x0) && n > 40
        error('parse_opts:sobolDimCap', ...
            ['init_mode=''sobol'' richiede n<=40 (tabella Joe-Kuo imbarcata, ' ...
             'rif. CLAUDE.md S5.1/S10, core/sobol_point.m). n=%d non supportato: ' ...
             'usare opts.init_mode=''center'' oppure fornire opts.x0, o fermarsi ' ...
             'e chiedere come estendere la tabella.'], n);
    end

    assert(isnumeric(opts.max_iter) && opts.max_iter > 0, 'parse_opts:badMaxIter', 'opts.max_iter deve essere > 0.');
    assert(isnumeric(opts.max_eval) && opts.max_eval > 0, 'parse_opts:badMaxEval', 'opts.max_eval deve essere > 0.');
    assert(isnumeric(opts.sigma0) && opts.sigma0 > 0, 'parse_opts:badSigma0', 'opts.sigma0 deve essere > 0.');
end
