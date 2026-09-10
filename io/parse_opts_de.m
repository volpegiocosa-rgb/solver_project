function opts = parse_opts_de(opts, n)
% PARSE_OPTS_DE  Validazione e default per il solver DE (rif. piano di sessione "confronto
%   DE vs CMA-ES+ARCH"). Layer sottile sopra io/parse_opts.m esistente: riusa la validazione
%   dei campi GENERICI (max_time, tol_con, tol_fun, tol_x, x0, seed, verbose, polish_opt,
%   other) senza duplicarla, poi aggiunge/sovrascrive i campi specifici di DE.
%
%   INPUT  opts  struct utente (campi mancanti -> default), n dimensione
%   OUTPUT opts  struct completata
%
% NOTA (campi CMA-ES-only ereditati da parse_opts): sigma0, init_mode, multistart,
%   restart_ipop, max_restarts, restart_mode, restart_jitter vengono comunque riempiti da
%   parse_opts.m ma NON sono letti da nessun file /de -- passano attraverso inutilizzati,
%   nessuna azione necessaria (parse_opts.m non si lamenta di campi extra, verificato: il
%   suo loop di default itera solo su fieldnames(defaults), non su fieldnames(opts)).
%
% NOTA (max_iter/max_eval): parse_opts.m riempirebbe questi due campi con default CALIBRATI
%   per CMA-ES (2*eps_horizon, lambda_ref*50 -- formule legate a IPOP/eps-schedule, S6.1).
%   Non hanno senso per DE (nessun restart, popolazione a dimensione COSTANTE). Se l'utente
%   NON li ha forniti esplicitamente, vengono qui SOVRASCRITTI con default DE-appropriati
%   (sotto). Se l'utente li ha forniti, restano quelli (parse_opts.m li valida comunque,
%   >0).
%
% STATO: default DE MAI calibrati su una Fase A (nessuna suite benchmark eseguita per DE,
%   decisione utente: validazione solo sul caso reale, rif. piano di sessione) -- euristiche
%   di letteratura (Storn & Price), marcate PROVVISORIO, non derivate da misure come i
%   default CMA-ES di parse_opts.m S6.1.

    if nargin < 1 || isempty(opts)
        opts = struct();
    end

    had_max_iter = isfield(opts, 'max_iter') && ~isempty(opts.max_iter);
    had_max_eval = isfield(opts, 'max_eval') && ~isempty(opts.max_eval);

    opts = parse_opts(opts, n);

    % === default DE-specifici, MAI calibrati (rif. header) ==================
    defaults_de.pop_size = max(5 * n, 20);
    % TODO: PROVVISORIO -- Storn & Price: NP tipicamente 5*n-10*n per DE/rand/1/bin. Scelto
    % 5*n (non 10*n) perche' il caso reale non e' gratuito (~10-45 ms/eval, non un
    % benchmark sintetico): a parita' di max_eval, una popolazione piu' piccola permette
    % piu' generazioni. Floor a 20 per garantire diversita' anche a n piccolo (smoke test).
    defaults_de.F = 0.5;
    % TODO: PROVVISORIO -- fattore di scala classico (Storn & Price 1997), nessuna
    % auto-adattazione (jDE/SaDE fuori scope: "DE vanilla", decisione utente).
    defaults_de.CR = 0.9;
    % TODO: PROVVISORIO -- crossover binomiale alto, indicato per problemi non separabili
    % (le variabili di guida del caso reale interagiscono via la dinamica di traiettoria).

    fnames = fieldnames(defaults_de);
    for k = 1:numel(fnames)
        key = fnames{k};
        if ~isfield(opts, key) || isempty(opts.(key))
            opts.(key) = defaults_de.(key);
        end
    end

    if ~had_max_iter
        opts.max_iter = 200 * n;
        % TODO: PROVVISORIO -- generazioni, scala con n (piu' dimensioni, piu' generazioni
        % perche' il crossover binomiale cambia in media una frazione CR di componenti per
        % generazione, non tutte). NON derivata dalla formula CMA (2*eps_horizon, specifica
        % di IPOP/eps-schedule, rif. header).
    end
    if ~had_max_eval
        opts.max_eval = opts.pop_size * (opts.max_iter + 1);
        % Esatto (popolazione iniziale + max_iter generazioni a pop_size COSTANTE), non un
        % margine di sicurezza moltiplicativo come in parse_opts.m: a differenza di IPOP
        % (lambda raddoppia, costo peggiore imprevedibile), la DE vanilla ha pop_size
        % costante per costruzione (nessun restart, decisione utente) -- la relazione fra
        % max_iter e max_eval e' deterministica, non serve un fattore di margine.
    end

    assert(isnumeric(opts.pop_size) && opts.pop_size >= 4, 'parse_opts_de:badPopSize', ...
        'opts.pop_size deve essere >= 4 (servono 3 individui distinti dal target per la mutazione DE/rand/1).');
    assert(isnumeric(opts.F) && opts.F > 0, 'parse_opts_de:badF', 'opts.F deve essere > 0.');
    assert(isnumeric(opts.CR) && opts.CR >= 0 && opts.CR <= 1, 'parse_opts_de:badCR', ...
        'opts.CR deve essere in [0,1].');
end
