function [order, state] = arch_rank(F, Cineq, Ceq, eps_eq, state)
% ARCH_RANK  Cuore di ARCH (rif. CLAUDE.md S5.2, S10 codice autori, S3.1).
%   Calcola l'ordine finale della popolazione combinando in modo ADATTIVO il
%   ranking sull'obiettivo e quello sulla violazione. Nessuna penalita' additiva,
%   nessuna feasibility-rule rigida (Deb), nessun Augmented Lagrangian (S5.2).
%
%   Struttura dell'aggregazione (invariata rispetto al riferimento,
%   ARCHBase.total_ranking):
%       score_i = rank_f(i) + alpha * rank_v(i)
%   con rank a punteggio medio sui pareggi e alpha adattato online. Preserva le
%   due invarianze richieste da S5.2: lo score dipende solo dall'ORDINE di f e
%   di v (invarianza a trasformazioni monotone di obiettivo e vincoli) e non
%   dalla parametrizzazione dello spazio di ricerca (nessuna metrica sulle x
%   entra nello score).
%
%   ===========================================================================
%   DEVIAZIONE 1 (guess dichiarato, rif. CLAUDE.md S7) -- secondo asse di ranking
%   ===========================================================================
%   Il paper (Sakamoto & Akimoto) assume che f sia valutabile SOLO sul punto
%   riparato (repair-then-evaluate) e usa come secondo asse la DISTANZA DI
%   REPAIR (compute_penalty: Mahalanobis fra punto originale e riparato). Nel
%   nostro caso f=traj_cost e' valutabile ovunque e cmaes_core.m (Fase 1, gate
%   M2 gia' passato) valuta fun_norm sul candidato ORIGINALE. Qui il secondo
%   asse e' quindi la violazione DIRETTA (viol_total su cineq e su ceq
%   trasformato da eq_to_ineq), non una distanza di repair. arch_repair resta
%   un meccanismo SEPARATO (feasibility-polish, Fase 4).
%
%   CONSEGUENZA IMPORTANTE di questa deviazione (misurata, non teorica): nel
%   paper il motore non puo' MAI allontanarsi dalla regione ammissibile, perche'
%   f viene valutata solo su punti riparati. Da noi puo': se il ranking da'
%   troppo peso all'obiettivo, la popolazione se ne va dove f e' bassa e i
%   vincoli sono violati di ordini di grandezza. Questo vincola il range
%   ammesso per alpha -- vedi DEVIAZIONE 3.
%
%   ===========================================================================
%   DEVIAZIONE 2 (guess dichiarato) -- stima del segnale di controllo di alpha
%   ===========================================================================
%   Il paper adatta alpha (S4.3) su
%       dm = (distanza di repair della MEDIA xmean / step-size ottimale)^2
%   con soglia dm_threshold = 1, cioe': "tieni il centro della distribuzione a
%   non piu' di un passo dalla regione ammissibile". Il segnale NON e' quante
%   soluzioni sono ammissibili: e' DOVE STA IL CENTRO rispetto al vincolo,
%   misurato in unita' di passo.
%
%   Qui dm non e' calcolabile a costo nullo (richiederebbe un repair SQP di
%   xmean a ogni generazione, rif. arch_repair.m). Si usa un estimatore
%   equivalente al primo ordine, ricavato dalla sola popolazione GIA' valutata
%   (zero valutazioni aggiuntive). Modello lineare locale del vincolo sulla
%   popolazione, x_j = xmean + sigma*B*D*z_j:
%       h_k(x_j) ~ h_k(xmean) + grad_h_k' * (x_j - xmean)
%   da cui, sulla popolazione,
%       mean_j( h_k ) ~ h_k(xmean)                 (valore al centro)
%       std_j ( h_k ) ~ sigma * ||grad_h_k||_C     (variazione su un passo)
%   e quindi
%       ( |mean_j h_k| - eps_eq_k ) / std_j( h_k )
%   e' la DISTANZA DEL CENTRO DALLA BANDA AMMISSIBILE MISURATA IN PASSI --
%   esattamente la grandezza che dm misura, ottenuta per regressione implicita
%   invece che per repair. Definendo
%       t_k = (|mean_j h_k| - eps_eq_k) / std_j(h_k)        (uguaglianze)
%       t_k = ( mean_j c_k )            / std_j(c_k)        (disuguaglianze)
%       s   = mean_k( max(0, t_k)^2 )
%   si ha  s <-> dm  e  s_target = 1 <-> dm_threshold = 1: la soglia NON e' un
%   parametro nuovo da tarare, e' quella del paper con lo stesso significato.
%   t_k < 0 (centro dentro la banda) azzera il contributo, come dm = 0.
%
%   Perche' la MEDIA e non la mediana del valore assoluto: solo la media del
%   residuo CON SEGNO stima h_k(xmean). Usare |h_k| ripiega la distribuzione e
%   fa perdere l'informazione sulla posizione del centro: una popolazione a
%   cavallo della varieta' e una spostata di molti passi danno rapporti simili.
%   Verificato sperimentalmente: con la versione ripiegata il controllo resta
%   attorno al bersaglio mentre la violazione reale cresce di 6 ordini di
%   grandezza (fuga della popolazione, vedi DEVIAZIONE 3).
%
%   Nessuna dipendenza da n, n_eq, lambda o dalla scala fisica dei vincoli:
%   t_k e' adimensionale per costruzione (S1, dimension-agnostic). Per le
%   disuguaglianze la stessa formula ha gia' la semantica giusta (vincolo
%   inattivo -> t_k < 0 -> contributo nullo). NOTA (gap noto, rif. S4/S9):
%   cineq e' oggi un placeholder vuoto, quel ramo NON e' validato su un
%   benchmark con disuguaglianze attive.
%
%   MOTIVO DELLA SOSTITUZIONE (rif. CLAUDE.md S7, diagnosi misurata su g13).
%   La versione precedente controllava alpha sulla FRAZIONE FEASIBLE della
%   popolazione rispetto alla banda eps, con bersaglio 0.5 e passo bang-bang
%   sign(0.5 - feas_frac). Tre difetti misurati:
%   (a) bersaglio sbagliato: 0.5 impone al centro di stare SUL bordo della
%       banda (meta' popolazione fuori), non dentro;
%   (b) segnale binario e degenere: quando eps si stringe verso tol_con la
%       banda diventa molto piu' stretta della dispersione dei residui, la
%       frazione feasible collassa a 0 in modo permanente e alpha satura al cap
%       superiore. Al cap il termine alpha*rank_v domina rank_f su tutto il
%       range dei rank: il motore ottimizza SOLO la violazione e ignora
%       l'obiettivo, convergendo a un punto arbitrario della varieta'
%       ammissibile (su g13 la varieta' e' 2-dimensionale: nessuna forza
%       residua muove la soluzione lungo di essa -- infatti sigma non
%       convergeva e i restart IPOP non si innescavano mai);
%   (c) nel regime intermedio genera un ciclo limite (feas_frac che oscilla
%       0<->1, alpha che rimbalza fra i due cap): il criterio di selezione
%       cambia natura a ogni generazione e la covarianza non riceve un segnale
%       coerente.
%
%   ===========================================================================
%   DEVIAZIONE 3 (guess dichiarato) -- limite inferiore di alpha
%   ===========================================================================
%   Il riferimento clippa alpha in [1/lam, lam] (con un TODO degli autori:
%   "lower and upper should be independent of lam"). Qui:
%     * lam_def = 4 + floor(3*log(n)) al posto di lam. E' la popolazione di
%       riferimento gia' usata dal codice degli autori (ARCHBase.lam_def) ed e'
%       indipendente dai restart IPOP: senza questo, con 9 restart lambda passa
%       da 8 a ~4e3 e l'autorita' del controllore cambierebbe di tre ordini di
%       grandezza a meta' run (S5.1).
%     * limite inferiore 1.0 invece di 1/lam_def. Motivo: DEVIAZIONE 1. Con
%       alpha < 1 il ranking sull'obiettivo pesa piu' di quello sulla
%       violazione e -- non avendo il repair a garantire l'ammissibilita' dei
%       punti valutati -- nulla trattiene la popolazione dentro il dominio.
%       Misurato su g13, 8 seed: con limite inferiore 1/lam_def 3 run su 8
%       finiscono senza NESSUN punto ammissibile (fuga verso f->0 con residui
%       ~1e6 volte la tolleranza); con limite inferiore 1.0, 0 run su 8.
%       alpha = 1 significa "i due ranking pesano uguale", non "il vincolo
%       vince sempre": NON e' la feasibility-rule di Deb (che corrisponderebbe
%       ad alpha >= lambda, ordine lessicografico) e resta esclusa da S5.2.
%
%   Gating dell'aggiornamento: portato invariato dal riferimento
%   (ARCHBase._update_alpha) con s al posto di dm -- alpha si muove solo se s
%   si sta allontanando dal bersaglio, non se il sistema si sta gia'
%   correggendo da solo. E' l'anti-overshoot del paper, omesso nella versione
%   precedente. Passo esponenziale d_alpha = 1/n come nel riferimento.
%
%   INPUT  F      : 1 x lambda, obiettivo della popolazione
%          Cineq  : cell 1 x lambda di vettori n_ineq x 1 (o [] per individuo), o []
%          Ceq    : cell 1 x lambda di vettori n_eq x 1 (o [] per individuo), o []
%          eps_eq : n_eq x 1, soglie correnti (da eps_schedule, calcolato dal
%                   chiamante -- rif. solver.m) o [] se n_eq=0
%          state  : stato CMA-ES corrente (rif. core/init_state.m); usato in
%                   lettura per n; state.arch.* porta lo stato del controllore
%                   di alpha (campo opaco per /core, rif. S3)
%   OUTPUT order  : indici 1 x lambda dal migliore al peggiore (stessa
%                   convenzione di [~,order]=sort(f) usata dal fallback in
%                   cmaes_core.m)
%          state  : invariato salvo state.arch (alpha, s, s_old)

    F = F(:)';
    lambda = numel(F);

    Cineq_mat = local_cell2mat(Cineq, lambda);
    Ceq_mat = local_cell2mat(Ceq, lambda);

    % Caso n_ineq=0 e n_eq=0 (nessun vincolo dichiarato, es. bench_sphere):
    % niente da ripartire tra obiettivo/violazione, ranking = ordina per f
    % (stesso comportamento del fallback in cmaes_core.m quando fun_ranked=[]).
    % Evita anche l'ambiguita' di viol_total nel dedurre lambda da input tutti
    % vuoti (rif. CLAUDE.md S7).
    if isempty(Cineq_mat) && isempty(Ceq_mat)
        [~, order] = sort(F);
        return
    end

    G_eq = eq_to_ineq(Ceq_mat, eps_eq);

    % Normalizzazione per-vincolo in scala ASSOLUTA (rif. viol_total.m per il
    % motivo: una normalizzazione relativa-per-generazione fa divergere sigma).
    % eps_eq e' la scala naturale per ceq (stessa unita' fisica di ceq, S4) ed
    % e' costante entro la generazione. Nota: il ranking e' invariante a un
    % fattore di scala comune, quindi cio' che conta davvero sono i RAPPORTI
    % fra le eps_eq_k, cioe' i rapporti fra le tol_con_k -- la precisione
    % relativa richiesta dall'utente (S6).
    G_eq_norm = [];
    if ~isempty(G_eq)
        G_eq_norm = G_eq ./ eps_eq(:);
    end
    % NOTA (guess dichiarato, gap noto): cineq non ha ancora un parametro di
    % scala equivalente (e' un placeholder vuoto, S4/S9) -- quando uscira' dal
    % placeholder servira' un eps_ineq/scala per-vincolo analogo a eps_eq,
    % altrimenti si rischia la stessa instabilita' qui risolta per le uguaglianze.

    V = viol_total(Cineq_mat, G_eq_norm);

    % --- controllore di alpha (rif. DEVIAZIONE 2 e 3 nell'header) ---
    s = local_centering_error(Cineq_mat, Ceq_mat, eps_eq);
    s_target = 1.0;                 % = dm_threshold del riferimento

    if isfield(state, 'arch') && isfield(state.arch, 'alpha')
        alpha = state.arch.alpha;
        s_old = state.arch.s_old;
    else
        % Init a ogni (ri)partenza: ipop_restart.m ricostruisce lo state da
        % init_state.m, quindi il controllore riparte neutro a ogni restart --
        % voluto: il segmento nuovo ha una distribuzione nuova (S5.1).
        alpha = 1.0;
        s_old = 0.0;
    end

    d_alpha = 1.0 / state.n;
    if sign(s - s_old) == sign(s - s_target) || s == 0
        alpha = alpha * exp(sign(s - s_target) * d_alpha);
    end
    lam_def = 4 + floor(3 * log(state.n));
    alpha = min(max(alpha, 1.0), lam_def);

    state.arch.alpha = alpha;
    state.arch.s_old = s;
    state.arch.s = s;

    rff = local_rank_stat(F);
    rvv = local_rank_stat(V);
    score = rff + alpha * rvv;

    [~, order] = sort(score);
end

function s = local_centering_error(Cineq_mat, Ceq_mat, eps_eq)
% Distanza del centro della distribuzione dalla banda ammissibile, misurata in
% PASSI e mediata sui vincoli (rif. header, DEVIAZIONE 2).
%   uguaglianze  : t_k = (|mean h_k| - eps_eq_k) / std(h_k)
%   disuguaglianze: t_k = mean(c_k) / std(c_k)
% Solo i contributi positivi (centro FUORI) alimentano s: dentro la banda il
% paper pone dm = 0 e alpha cala.
    t = zeros(0, 1);
    t_cap = 1e3;    % solo per tenere s finito in casi degeneri (dispersione
                    % nulla): s entra unicamente in confronti di segno, il
                    % valore esatto del cap non e' un parametro di taratura.
    if ~isempty(Ceq_mat)
        m = abs(mean(Ceq_mat, 2)) - eps_eq(:);
        d = std(Ceq_mat, 0, 2);
        t = [t; local_ratio(m, d, t_cap)];
    end
    if ~isempty(Cineq_mat)
        m = mean(Cineq_mat, 2);
        d = std(Cineq_mat, 0, 2);
        t = [t; local_ratio(m, d, t_cap)];
    end
    s = mean(max(t, 0) .^ 2);
end

function t = local_ratio(m, d, t_cap)
% Rapporto m/d con gestione esplicita della dispersione nulla (popolazione
% degenere su quel vincolo: il segno di m dice se e' tutta dentro o tutta fuori).
    t = zeros(numel(m), 1);
    for k = 1:numel(m)
        if d(k) > 0
            t(k) = m(k) / d(k);
        elseif m(k) > 0
            t(k) = t_cap;
        else
            t(k) = -t_cap;
        end
    end
    t = min(max(t, -t_cap), t_cap);
end

function M = local_cell2mat(C, lambda)
% Converte una cell 1 x lambda di vettori colonna (tutti stessa lunghezza n, o
% tutti vuoti) in una matrice n x lambda, oppure [] se n=0.
    if isempty(C) || all(cellfun(@isempty, C))
        M = [];
        return
    end
    n = numel(C{1});
    M = zeros(n, lambda);
    for k = 1:lambda
        M(:, k) = C{k}(:);
    end
end

function r = local_rank_stat(v)
% Rank a punteggio medio sui pareggi (rif. ARCHBase.total_ranking, S10):
% r_i = n_better_i + (n_equal_i - 1)/2. 0-based: il migliore ha r=0.
% Implementazione via ordinamento: numericamente IDENTICA alla definizione
% doppio-ciclo del riferimento (verificata su 200 casi random con pareggi), ma
% O(lambda log lambda) invece di O(lambda^2). Non e' un dettaglio cosmetico:
% con i restart IPOP lambda raddoppia a ogni restart (S5.1) e con 9 restart
% arriva a ~4e3, dove il doppio ciclo domina il costo di una generazione.
    v = v(:)';
    lambda = numel(v);
    [vs, idx] = sort(v);
    pos = 0:(lambda - 1);          % rank 0-based nell'ordine ordinato
    rs = pos;
    i = 1;
    while i <= lambda
        j = i;
        while j < lambda && vs(j + 1) == vs(i)
            j = j + 1;
        end
        if j > i
            rs(i:j) = mean(pos(i:j));   % punteggio medio sul gruppo di pari
        end
        i = j + 1;
    end
    r = zeros(1, lambda);
    r(idx) = rs;
end
