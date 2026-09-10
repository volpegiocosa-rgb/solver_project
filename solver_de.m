function result = solver_de(fun, bounds, opts)
% SOLVER_DE  Entry point per il solver alternativo DE + Deb's rule (rif. piano di sessione
%   "confronto DE vs CMA-ES+ARCH" -- baseline di confronto onesto contro solver.m).
%
% SCOPO: mirror strutturale di solver.m con lo STESSO contratto di chiamata
%   (result = solver_de(fun, bounds, opts), [f,cineq,ceq] = fun(x,other)) -- drop-in
%   rispetto a solver.m per la firma. Motore interno completamente diverso: DE vanilla
%   (de/de_core.m) con Deb's rule (constraints/deb_select.m) al posto di CMA-ES+ARCH,
%   nessun restart (decisione utente).
%
% DIFFERENZE STRUTTURALI rispetto a solver.m (dichiarate esplicitamente, non un'omissione):
%   - Nessun bound_transform/bound_transform_inv: DE non campiona in uno spazio non
%     vincolato (non ha bisogno dell'invarianza affine di CMA-ES che lo richiede). Resta
%     sempre dentro [0,1]^n via de_reflect_bounds (rif. de/de_ask.m). fun_box e' quindi
%     passato DIRETTAMENTE al motore, senza comporre fun_norm=fun_box(bound_transform(.)).
%     Di conseguenza i risultati di de_core sono gia' in spazio box: NESSUNA chiamata a
%     bound_transform su x_best/x_best_ranked dopo de_core (a differenza di solver.m).
%   - Nessuna epsilon-schedule: Deb's rule confronta sempre contro opts.tol_con fisso fin
%     dalla prima generazione (rif. constraints/deb_select.m).
%   - Nessun restart IPOP: DE vanilla (decisione utente, confronto piu' semplice/onesto).
%
% STATO: baseline di confronto. Validata solo su smoke-test interno (de/de_smoke_test.m,
%   NON un deliverable di validazione) + caso reale TSTO (real_case/run_real_case_de.m,
%   real_case/compare_real_case.m).

    if nargin < 3 || isempty(opts); opts = struct(); end
    if nargin < 2 || ~isfield(bounds, 'lb') || ~isfield(bounds, 'ub')
        error('solver_de:bounds', 'bounds deve contenere .lb e .ub (vettori colonna).');
    end
    n = numel(bounds.lb);
    assert(numel(bounds.ub) == n, 'lb e ub devono avere la stessa lunghezza.');

    opts = parse_opts_de(opts, n);

    if ~isempty(opts.x0)
        opts.x0 = normalize(opts.x0, bounds);
    end

    % fun_box valuta un punto GIA' dentro il box [0,1]^n -- passato direttamente al motore
    % (rif. header per il perche' manca la composizione fun_norm/bound_transform di solver.m).
    fun_box = @(xb) fun(denormalize(xb, bounds), opts.other);

    select_fun = @(f_t, ct, et, f_x, cx, ex) deb_select(f_t, ct, et, f_x, cx, ex, opts.tol_con);

    result = de_core(fun_box, n, opts, select_fun);
    result.opts = opts;

    % === feasibility-polish finale (riuso as-is, rif. CLAUDE.md S5.3a) ===
    % x_best e' gia' in spazio box [0,1]^n (nessun bound_transform da invertire, rif. header).
    % No-op per costruzione se non vincolato o gia' feasible (rif. constraints/arch_repair.m).
    con_fun = @(xb) local_con_only(fun_box, xb);
    result.x_best = feasibility_polish(result.x_best, con_fun, opts.tol_con);

    result.x_best_phys = denormalize(result.x_best, bounds);

    % === ri-valutazione di f_best/feasible sul punto POST-polish ===
    % Stesso motivo/stesso fix gia' presente in solver.m: il polish sposta x_best (proiezione
    % sul vincolo), i valori pre-polish calcolati da de_core sarebbero disallineati dal punto
    % restituito. Stessa definizione di feasible per-vincolo usata in de_core.m/solver.m
    % (cineq<=0 e |ceq|<=tol_con, nessuna aggregazione scalare) -- duplicata qui per
    % coerenza, non centralizzata per due soli usi (S7, no premature abstraction).
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
% Estrae solo [cineq, ceq] da fun_box, scartando f (stesso ruolo di solver.m::local_con_only).
    [~, cineq, ceq] = fun_box(xb);
end
