function winner_is_trial = deb_select(f_trial, cineq_trial, ceq_trial, f_target, cineq_target, ceq_target, tol_con)
% DEB_SELECT  Comparatore pairwise Deb's rule (rif. piano di sessione "confronto DE vs
%   CMA-ES+ARCH": baseline di gestione vincoli per il solver DE, deliberatamente SEPARATA da
%   ARCH -- CLAUDE.md S5.2 vieta la feasibility-rule di Deb "rigida" nel design del RANKING di
%   ARCH (rif. constraints/arch_rank.m, che se ne discosta esplicitamente), non nel progetto
%   in generale: qui e' il punto stesso del confronto (decisione utente, non un'aggiramento).
%
% FONTE (algoritmo, non porting di codice): Deb, K. (2000). "An efficient constraint
%   handling method for genetic algorithms." Comput. Methods Appl. Mech. Engrg. 186,
%   311-338. Regola classica a tre casi:
%     1) feasible batte infeasible;
%     2) fra due feasible, vince f minore;
%     3) fra due infeasible, vince la violazione totale minore.
%   Pareggio (caso 2, f_trial==f_target): vince lo SFIDANTE (trial) -- convenzione standard
%   DE per non stagnare su un plateau piatto (rif. Storn & Price), scelta dichiarata qui, non
%   parte della formulazione originale di Deb.
%
% RIUSO: nessuna reimplementazione dell'aggregazione di violazione -- riusa
%   constraints/eq_to_ineq.m (trasformazione uguaglianze, tolleranza FISSA opts.tol_con, MAI
%   uno schedule: differenza dichiarata rispetto ad ARCH, rif. constraints/eps_schedule.m) e
%   constraints/viol_total.m (somma delle parti positive). Stesso gap ereditato e NON
%   risolto qui, gia' documentato in arch_rank.m: cineq non ha una scala per-vincolo propria
%   (rilevante solo se piu' disuguaglianze eterogenee sono attive contemporaneamente; il caso
%   reale corrente ha cineq=[] o un solo vincolo gia' adimensionale, quindi non esercitato).
%
% GENERICITA' (rif. CLAUDE.md S1/S3): nessuna conoscenza di popolazione/generazioni/DE --
%   puro confronto colonna-per-colonna, iniettabile in de/de_core.m esattamente come
%   fun_ranked e' iniettato in core/cmaes_core.m. /de resta ignaro della regola specifica.
%
%   INPUT  f_trial/f_target         : 1 x m (obiettivo, m = pop_size o 1 per un confronto singolo)
%          cineq_trial/cineq_target : n_ineq x m, o [] se n_ineq=0
%          ceq_trial/ceq_target     : n_eq x m, o [] se n_eq=0
%          tol_con                  : n_eq x 1 (tolleranza per-vincolo, S6) o [] se n_eq=0
%   OUTPUT winner_is_trial          : 1 x m logical, true dove il trial vince

    f_trial = f_trial(:)';
    f_target = f_target(:)';
    assert(numel(f_trial) == numel(f_target), 'deb_select:sizeMismatch', ...
        'f_trial e f_target devono avere lo stesso numero di colonne.');

    % Caso n_ineq=0 e n_eq=0 (nessun vincolo dichiarato, es. bench_sphere): Deb's rule
    % degenera nel confronto diretto su f -- stesso caso speciale gia' gestito da
    % constraints/arch_rank.m per lo stesso motivo (viol_total non puo' dedurre la
    % dimensione della popolazione da input tutti vuoti, rif. CLAUDE.md S7).
    if isempty(cineq_trial) && isempty(ceq_trial) && isempty(cineq_target) && isempty(ceq_target)
        winner_is_trial = (f_trial <= f_target);
        return
    end

    g_trial  = eq_to_ineq(ceq_trial, tol_con);
    g_target = eq_to_ineq(ceq_target, tol_con);
    v_trial  = viol_total(cineq_trial, g_trial);
    v_target = viol_total(cineq_target, g_target);

    feas_trial = (v_trial == 0);
    feas_target = (v_target == 0);

    winner_is_trial = false(size(f_trial));

    % caso 1: trial feasible, target infeasible -> trial vince
    winner_is_trial(feas_trial & ~feas_target) = true;

    % caso 2: entrambi feasible -> vince f minore (pareggio -> vince lo sfidante, rif. header)
    both_feas = feas_trial & feas_target;
    winner_is_trial(both_feas) = f_trial(both_feas) <= f_target(both_feas);

    % caso 3: entrambi infeasible -> vince violazione totale minore
    both_infeas = ~feas_trial & ~feas_target;
    winner_is_trial(both_infeas) = v_trial(both_infeas) <= v_target(both_infeas);

    % caso implicito (target feasible, trial infeasible): resta false, il target vince
end
