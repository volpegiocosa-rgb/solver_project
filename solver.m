function result = solver(fun, bounds, opts)
% SOLVER  Entry point per l'ottimizzatore CMA-ES + ARCH (constraint handling).
%
% SCOPO (rif. CLAUDE.md S1, S3, S3.1):
%   Orchestrazione dell'ottimizzazione black-box vincolata. Non contiene logica di
%   algoritmo (vive in /core) ne' di vincoli (vive in /constraints).
%
% GENERICITA' (rif. CLAUDE.md S1 "Principio di genericita'"):
%   Dimension-agnostic. n, n_eq, n_ineq sono ricavati a runtime, MAI cablati.
%   Il solver deve poter essere riusato in domini diversi dalle traiettorie.
%
% INPUT:
%   fun    : handle alla funzione utente, firma  [f, cineq, ceq] = fun(x, other)
%            (rif. CLAUDE.md S4). cineq puo' essere [] (placeholder attuale).
%   bounds : struct con campi .lb e .ub (vettori colonna, lunghezza n). Definiscono
%            lo spazio fisico e, implicitamente, n = numel(lb).
%   opts   : struct opzioni (rif. CLAUDE.md S6). Campi mancanti -> default PROVVISORI.
%
% OUTPUT:
%   result : struct con best-feasible (normalizzato e fisico), storia, n_eval,
%            opts usati. Violazioni per-vincolo e feasibility-polish: Fase 2/4.
%
% STATO: Fase 4 (motore CMA-ES + ranking ARCH + feasibility-polish finale,
%   CLAUDE.md S11). optimality-polish resta STUB OFF (S5.3b, opts.polish_opt).
%   opts.tol_con e' un input applicativo (S6): se n_eq>0 deve essere fornito
%   dal chiamante (vettore per-vincolo, > 0), altrimenti eps_schedule fallisce
%   esplicitamente (nessun default indovinato su un valore di missione, S7).
% REGOLA DI INGAGGIO (rif. CLAUDE.md S7): in caso di dubbio/contraddizione, FERMARSI e CHIEDERE.

    % === guard di base (dimension-agnostic) ===
    if nargin < 3 || isempty(opts); opts = struct(); end
    if nargin < 2 || ~isfield(bounds, 'lb') || ~isfield(bounds, 'ub')
        error('solver:bounds', 'bounds deve contenere .lb e .ub (vettori colonna).');
    end
    n = numel(bounds.lb);                                   % n ricavato a runtime
    assert(numel(bounds.ub) == n, 'lb e ub devono avere la stessa lunghezza.');

    % === parsing/validazione opts + default provvisori (delegato a /io) ===
    opts = parse_opts(opts, n);

    % === guess utente in spazio fisico -> normalizzato -> spazio NON vincolato ===
    % (S4: init_mean lavora in [0,1]; il motore lavora invece nello spazio non
    % vincolato del bound handling, vedi sotto -- quindi x0 va portato la',
    % altrimenti xmean non corrisponderebbe al punto chiesto dall'utente vicino
    % ai bordi, dove la trasformazione non e' l'identita'.)
    if ~isempty(opts.x0)
        opts.x0 = bound_transform_inv(normalize(opts.x0, bounds));
    end

    % === normalizzazione problema in [0,1] + bound handling (delegato a /io) ===
    % fun_box : valuta un punto GIA' dentro il box [0,1]^n (usato dal polish e
    %           dalla ri-valutazione finale, che lavorano in spazio box).
    % fun_norm: quella che vede il MOTORE. Il motore campiona in uno spazio non
    %           vincolato (cmaes_ask.m non clippa, per l'invarianza affine di
    %           S5.2) e bound_transform lo riporta nel box con mirroring +
    %           patch quadratiche (rif. io/bound_transform.m per il perche':
    %           il clip precedente collassava tutti i punti fuori dominio sullo
    %           stesso bordo, azzerando il segnale di selezione -- misurato sul
    %           caso reale, real_case/diagnostic_plan.md T2).
    fun_box  = @(xb) fun(denormalize(xb, bounds), opts.other);
    fun_norm = @(xn) fun_box(bound_transform(xn));

    % === ranking per il motore: ARCH (delegato a /constraints) ===
    % con_fun estrae solo [cineq, ceq] da fun_norm, per arch_repair (Fase 4) e
    % per un'eventuale rivalutazione: qui NON viene usato nel loop principale
    % (fun_norm e' gia' valutato una volta per candidato in cmaes_core, S4 cache
    % implicita per costruzione -- nessuna doppia simulazione nel loop).
    % L'orizzonte dello schedule di eps_eq e' opts.eps_horizon, NON opts.max_iter
    % (rif. io/parse_opts.m per la motivazione misurata): il budget dell'utente
    % non deve entrare nella definizione del ranking, altrimenti due run con
    % budget diversi seguono traiettorie diverse fin dalla prima generazione.
    fun_ranked = @(f, cineq, ceq, st) arch_rank(f, cineq, ceq, ...
        eps_schedule(st.iter, opts.eps_horizon, opts.tol_con), st);

    % === run motore CMA-ES (delegato a /core) ===
    result = cmaes_core(fun_norm, n, opts, fun_ranked);
    result.opts = opts;

    % === feasibility-polish finale (delegato a /constraints, ATTIVO, S5.3a) ===
    % Chiude i residui ceq di result.x_best entro tol_con per-vincolo, riusando
    % arch_repair (S5.2 punto 2) con eps_eq = opts.tol_con (target finale, non uno
    % schedule -- singola chiamata post-hoc sul solo best, non sulla popolazione,
    % S4: vincoli economici). Opera in spazio NORMALIZZATO (arch_repair assume
    % dominio [0,1]^n): result.x_best_phys va quindi ricavato DOPO il polish, non
    % prima (a differenza del TODO originale che operava su x_best_phys).
    % No-op per costruzione se non vincolato (tol_con/ceq vuoti, es. sphere) o gia'
    % feasible entro tol_con: nessuna chiamata SQP in quei casi (rif. arch_repair.m).
    % I punti restituiti dal motore vivono nello spazio NON vincolato: vanno
    % riportati nel box PRIMA del polish (arch_repair assume dominio [0,1]^n) e
    % prima di denormalize. Dopo questa riga x_best/x_best_ranked sono in spazio
    % box, quindi il polish e la ri-valutazione usano fun_box, non fun_norm (che
    % ri-applicherebbe la trasformazione a un punto gia' trasformato: identita'
    % solo nella parte interna del dominio, NON vicino ai bordi).
    result.x_best = bound_transform(result.x_best);
    result.x_best_ranked = bound_transform(result.x_best_ranked);

    con_fun = @(xb) local_con_only(fun_box, xb);
    result.x_best = feasibility_polish(result.x_best, con_fun, opts.tol_con);

    % === risultato anche in spazio fisico (post-polish) ===
    result.x_best_phys = denormalize(result.x_best, bounds);

    % === ri-valutazione di f_best/feasible sul punto POST-polish ===
    % Il polish sposta x_best (proiezione sul vincolo, S5.2 punto 2): f_best e
    % feasible calcolati da cmaes_core si riferiscono al punto PRIMA del polish e
    % vanno quindi ricalcolati, altrimenti risultano disallineati dal x_best/
    % x_best_phys restituiti (bug: individuato verificando il risultato, non solo
    % per ispezione -- rif. CLAUDE.md S7). Stessa definizione di feasible usata in
    % cmaes_core.m (cineq<=0 e |ceq|<=tol_con, per-vincolo, nessuna aggregazione
    % scalare, S6): duplicata qui per coerenza, non centralizzata in una funzione
    % condivisa per non introdurre un'astrazione per due soli usi (S7, no premature
    % abstraction).
    [f_polished, cineq_polished, ceq_polished] = fun_box(result.x_best);
    feasible_polished = true;
    if ~isempty(cineq_polished)
        feasible_polished = feasible_polished && all(cineq_polished <= 0);
    end
    if ~isempty(ceq_polished)
        feasible_polished = feasible_polished && all(abs(ceq_polished) <= opts.tol_con(:));
    end
    result.f_best = f_polished;
    result.feasible = feasible_polished;
end

function [cineq, ceq] = local_con_only(fun_box, xb)
% Estrae solo [cineq, ceq] da fun_norm, scartando f: separazione dei ruoli per
% arch_repair (S4), che non deve conoscere l'obiettivo -- ripara solo sui vincoli.
    [~, cineq, ceq] = fun_box(xb);
end
