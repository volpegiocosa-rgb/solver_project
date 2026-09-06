function v = viol_total(cineq, ceq_as_ineq)
% VIOL_TOTAL  Violazione aggregata per-vincolo per il ranking (rif. CLAUDE.md S5.2, S6).
%   Somma delle parti positive (violazione) dei vincoli gia' in convenzione g<=0.
%   NON deve nascondere la violazione di un singolo vincolo nel controllo di
%   feasibility finale (quello resta per-vincolo contro tol_con altrove, S6) --
%   qui serve solo un punteggio scalare per confrontare candidati nel ranking.
%
%   IMPORTANTE (correzione post gate-M3, rif. CLAUDE.md S7): la normalizzazione
%   per-vincolo (scale fisiche eterogenee, S4: km vs gradi) NON va fatta qui
%   contro il massimo della popolazione CORRENTE -- una normalizzazione
%   relativa-per-generazione rende il ranking cieco alla scala ASSOLUTA della
%   violazione: quando sigma cresce, tutti i candidati diventano piu' violati
%   in modo proporzionale e la normalizzazione relativa si autocompensa,
%   eliminando la forza di richiamo che dovrebbe contenere sigma (osservato
%   in test: sigma diverge a ~1e18 su g13). La normalizzazione per-vincolo va
%   fatta dal CHIAMANTE (arch_rank) usando una scala ASSOLUTA (eps_eq corrente,
%   costante nella generazione) PRIMA di chiamare questa funzione -- qui si
%   assume che cineq/ceq_as_ineq siano gia' in unita' comparabili.
%
%   INPUT  cineq       : n_ineq x lambda (population), convenzione g<=0, o [] (n_ineq=0)
%          ceq_as_ineq : n_eq x lambda (population), gia' trasformato/normalizzato
%                        dal chiamante, o [] (n_eq=0)
%   OUTPUT v            : 1 x lambda, violazione aggregata (0 se feasible su tutti)
    G = [cineq; ceq_as_ineq];
    if isempty(G)
        v = zeros(1, 0);
        if ~isempty(cineq)
            v = zeros(1, size(cineq, 2));
        elseif ~isempty(ceq_as_ineq)
            v = zeros(1, size(ceq_as_ineq, 2));
        end
        return
    end

    Vpos = max(G, 0);       % parte positiva per-vincolo, per-individuo (scala assoluta)
    v = sum(Vpos, 1);       % aggregazione per individuo (1 x lambda)
end
