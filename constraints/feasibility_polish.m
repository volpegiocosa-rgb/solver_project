function x_best = feasibility_polish(x_best, con_fun, tol_con)
% FEASIBILITY_POLISH  Polish di feasibility ATTIVO (rif. CLAUDE.md S5.3a).
%   A fine run proietta/ripara il best (riuso arch_repair, S5.2 punto 2) fino a
%   portare ogni residuo ceq entro la rispettiva tol_con_k. Economico (vincoli non
%   costosi, S4), basso rischio: singola chiamata di repair sul solo punto finale,
%   non sull'intera popolazione (nessun costo di simulazione aggiuntivo rilevante).
%
% DESIGN: eps_eq passato ad arch_repair E' tol_con direttamente, non uno schedule
%   intermedio. tol_con e' gia' il target finale di precisione a cui lo schedule
%   di eps_eq converge nel loop principale (rif. CLAUDE.md S5.2 punto 1: "il valore
%   finale di eps_eq_k deve coincidere con tol_con_k"); qui non c'e' un "iter"
%   nel senso del loop -- e' una singola chiamata post-hoc -- quindi si usa
%   direttamente il target. Se x_best e' gia' feasible entro tol_con (o non
%   vincolato: tol_con/ceq vuoti), arch_repair e' un no-op per costruzione
%   (ritorna x invariato, nessuna chiamata SQP -- rif. arch_repair.m).
%
% STATO: Fase 4 (CLAUDE.md S11), attivo.
%
%   INPUT  x_best  : punto migliore, n x 1, spazio NORMALIZZATO [0,1] (arch_repair
%                    assume dominio [0,1]^n, coerente con cmaes_ask/cmaes_tell)
%          con_fun : handle [cineq, ceq] = con_fun(x) in spazio normalizzato
%          tol_con : vettore n_eq x 1 (tolleranza per-vincolo, S6) o [] se n_eq=0
%   OUTPUT x_best  : punto riparato (o invariato se gia' feasible/non vincolato)
    x_best = arch_repair(x_best, con_fun, tol_con);
end
