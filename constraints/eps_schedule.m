function eps_eq = eps_schedule(iter, iter_max, tol_con)
% EPS_SCHEDULE  Schedule decrescente per-vincolo di eps_eq_k (rif. CLAUDE.md S5.2, S6).
%   eps_eq_k parte ampio (K0 * tol_con_k) e decade geometricamente fino a
%   COINCIDERE con tol_con_k a iter>=iter_max (target di feasibility a fine run,
%   rif. CLAUDE.md S5.2 punto 1). Vettore di lunghezza n_eq (runtime), MAI scalare.
%
%   INPUT  iter     : iterazione corrente (1-based, come da cmaes_core.m)
%          iter_max : iterazione a cui lo schedule deve aver raggiunto tol_con
%          tol_con  : vettore n_eq x 1, tolleranza finale per-vincolo (input
%                     applicativo, S6). Deve essere > 0 per ogni componente:
%                     lo schedule usa tol_con come bersaglio moltiplicativo,
%                     non ha senso un target esattamente 0.
%   OUTPUT eps_eq   : vettore n_eq x 1, eps_eq_k(iter_max) == tol_con_k esatto.
%
%   K0 (fattore di ampiezza iniziale) e' un valore PROVVISORIO (rif. CLAUDE.md S6):
%   nessun dato ancora disponibile su cui calibrarlo prima della Fase 3 (benchmark).
%   Scelta di design (guess dichiarato, rif. CLAUDE.md S7): scala MOLTIPLICATIVA
%   rispetto a tol_con_k, non un valore assoluto, cosi' resta coerente anche con
%   grandezze fisiche eterogenee (km vs gradi, rif. CLAUDE.md S4) senza bisogno di
%   un ulteriore parametro per-vincolo non specificato altrove.
    tol_con = tol_con(:);
    if isempty(tol_con)
        eps_eq = [];
        return
    end
    assert(all(tol_con > 0), 'eps_schedule:badTolCon', ...
        'tol_con deve essere > 0 per ogni componente (target moltiplicativo dello schedule).');

    K0 = 1e3;
    % TODO: PROVVISORIO - calibrare su benchmark Fase A (rif. CLAUDE.md S6.1)

    frac = min(max(iter, 0), iter_max) / iter_max;   % clip in [0,1]
    eps_eq = tol_con .* (K0 .^ (1 - frac));
end
