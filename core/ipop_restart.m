function state = ipop_restart(state, opts, x_warm)
% IPOP_RESTART  Restart con popolazione crescente (rif. CLAUDE.md S5.1).
%   A ogni restart raddoppia lambda e riparte da un NUOVO xmean. La scelta di
%   quel centro dipende da COSA SI SA GIA' (decisione utente, 2026-09-09):
%
%     - nessun punto ammissibile noto  -> Sobol + jitter (copertura
%       quasi-uniforme del dominio): e' la risposta giusta a "non ho niente",
%       cioe' il caso per cui IPOP e' nato;
%     - punto ammissibile GIA' NOTO    -> restart CALDO attorno a quel punto
%       (x_warm + jitter): in stallo non serve ricominciare da zero, serve
%       ri-tentare da dove si sa che si sta bene, con popolazione maggiore.
%
%   MOTIVO (misurato, rif. CLAUDE.md S11 Fase 5, sessione "procedura di
%   continuazione"): il re-seeding Sobol GLOBALE, applicato quando un punto
%   ammissibile era gia' noto, buttava via il warm start e rimetteva
%   sigma0 attorno a un punto quasi-uniforme del box -- ne' sfruttamento (posto
%   sbagliato) ne' esplorazione (passo piccolo). Effetto misurato: tutta la
%   varianza del risultato veniva da DOVE cadeva il punto Sobol (oscillazioni
%   di ~1.8 t di payload sul caso reale a fronte di differenze di 1.8 kg nel
%   punto iniziale, perche' il jitter pesca dallo stream RNG e quindi dipende
%   da quante iterazioni e' durato il segmento precedente). Con un punto
%   ammissibile noto il restart caldo elimina quella lotteria.
%
%   Reinizializza covarianza/evolution-path (nuovo init_state.m) ma preserva
%   il budget di valutazioni gia' consumato (state.counteval) e il contatore
%   dei restart, cosi' che cmaes_core.m possa applicare i criteri di stop
%   sull'intero run (non per-restart).
%
%   Input : state, opts
%           x_warm  (opzionale) miglior punto ammissibile noto, nello stesso
%                   spazio in cui lavora il motore. Vuoto/assente -> Sobol.
%                   Il motore NON sa cosa significhi fisicamente: e' solo "il
%                   punto migliore noto" (S3, /core resta dominio-agnostico).
    if nargin < 3
        x_warm = [];
    end
    n = state.n;
    lambda_new = 2 * state.lambda;
    n_restarts_new = state.n_restarts + 1;

    if isempty(x_warm) && isfield(opts, 'x0') && ~isempty(opts.x0) ...
            && n_restarts_new == 1
        % Nessun punto ammissibile trovato dalla ricerca, ma l'utente ha dato
        % un guess: al PRIMO restart e' la conoscenza migliore disponibile,
        % meglio di un punto quasi-uniforme. Dal secondo restart in poi si
        % torna a Sobol (se x0 non ha prodotto nulla, insistere non serve e
        % l'esplorazione globale torna a essere la risposta giusta).
        x_warm = opts.x0(:);
    end
    use_warm = ~isempty(x_warm) && ~strcmp(opts.restart_mode, 'sobol');
    if strcmp(opts.restart_mode, 'warm') && isempty(x_warm)
        use_warm = false;   % richiesto caldo ma non c'e' nulla da riscaldare
    end

    if use_warm
        xmean_new = x_warm(:) + opts.restart_jitter * randn(n, 1);
    else
        idx = mod(opts.seed + n_restarts_new, 65536) + 2;
        xmean_base = sobol_point(n, idx);
        jitter = 0.01 * randn(n, 1);
        xmean_new = min(max(xmean_base + jitter, 0), 1);
    end

    counteval_carry = state.counteval;
    state = init_state(xmean_new, opts.sigma0, n, lambda_new);
    state.counteval = counteval_carry;
    state.n_restarts = n_restarts_new;
end
