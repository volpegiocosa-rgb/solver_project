function [f, cineq, ceq, prop_residual] = traj_cost(x, other)
% TRAJ_COST  Adapter tra il contratto di solver_project (CLAUDE.md S4:
%   [f, cineq, ceq] = traj_cost(x, other)) e TSTO/source/traj_problem.m
%   (repository ESTERNO, ../TSTO, simulatore del lanciatore a due stadi
%   a liquido). Thin wrapper: le firme sono gia' allineate (x, other) ->
%   (f, g/cineq, h/ceq) fin da traj_problem.m -- nessuna logica di dominio
%   qui (rif. CLAUDE.md S1/S3: /core e /constraints restano generici,
%   questo file vive FUORI da quelle cartelle proprio perche' e'
%   dominio-specifico, in /real_case).
%
%   Richiede che TSTO/source sia gia' sul path (fatto dallo script
%   chiamante, real_case/run_real_case.m -- non qui: questo file resta una
%   pura funzione [f,cineq,ceq]=traj_cost(x,other), senza side-effect di
%   path/IO, per restare compatibile con l'interfaccia generica di solver.m
%   S4, che non deve sapere nulla di TSTO).
%
%   LOGGING PER-EVAL (decisione utente, sessione di debug ODE-hang, Fase
%   5): unico side-effect deliberato di questo file, per diagnosticare
%   QUALE x manda in stallo ode45/ode15s su TSTO (un run esplorativo
%   precedente si e' bloccato 3h senza completare, senza nessuna traccia
%   di quale valutazione l'avesse causato). Scrive due righe per
%   valutazione in real_case/eval_log.csv (append, apri/chiudi il file ad
%   ogni scrittura cosi' il flush e' garantito anche se il processo viene
%   ucciso a meta' valutazione): una riga START prima di traj_problem.m,
%   una END dopo. Se il log si ferma su uno START senza END corrispondente,
%   quello e' l'x che ha causato lo stallo.
%
%   CLIP AI BOUNDS FISICI (trovato durante l'integrazione, non un
%   workaround): CMA-ES campiona in spazio normalizzato SENZA clip a [0,1]
%   (invarianza affine, gap gia' noto in CLAUDE.md Fase 2); denormalizzato,
%   questo produce x fisicamente fuori da [lb,ub] -- su TSTO questo non e'
%   solo "un valore brutto ma veloce" come sui benchmark sintetici: significa
%   variabili PRIVE DI SENSO FISICO (quota di trigger negativa, massa
%   payload negativa, timeline di fase invertita, assetto capovolto),
%   verificato causare dinamica quasi-singolare in eom.m/phase_event.m e
%   valutazioni ODE45 che restano bloccate per minuti. I bounds (lb/ub,
%   other.opt_bounds, impostati da run_real_case.m) SONO la definizione di
%   "fisicamente sensato" per questo problema: clippare qui e' quindi
%   sufficiente, non un ripiego -- ogni componente anomala osservata era
%   gia' fuori dal proprio lb/ub.
%
%   INPUT  x     : 10x1, variabili di design (ordine: rif. header
%                  TSTO/source/traj_problem.m). UNITA' MISTE (decisione
%                  utente): tutte le componenti sono in spazio FISICO
%                  nativo TSTO, TRANNE le 4 componenti angolari (indici
%                  3,4,6,8 = pitch_c1, pitch_c2, pitch_rate_transition,
%                  AoA_rate), che qui sono in GRADI, non radianti --
%                  l'utente lavora in gradi (rif. real_case/
%                  design_variables.csv), TSTO internamente resta in
%                  radianti (guidance.m/eom.m invariati). La conversione
%                  deg -> rad su questi 4 indici avviene qui sotto, subito
%                  dopo il clip ai bounds fisici (simmetrica alla
%                  conversione rad -> deg fatta su x_nom in
%                  real_case/run_real_case.m).
%                  DECISIONE DI PROGETTO (conferma utente, sessione di
%                  integrazione): rispetto alle 12 GUIDANCE_VARS.csv
%                  originarie, plane_controller_kd/ki sono state tolte da x
%                  (non variabili di design) e sostituite dalla massa
%                  payload (Mpayload), che diventa la 10a componente.
%                  pitch_at_transition RIMOSSA in una sessione successiva
%                  (conferma utente): coincide per costruzione con
%                  l'assetto di fine fase 2, derivata automaticamente in
%                  TSTO/source/simulator.m, non e' piu' in x.
%          other : struct "pristine" prodotta da TSTO/source/interface.m
%                  (passata come opts.other a solver(), invariata per
%                  tutta l'ottimizzazione -- rif. traj_problem.m, evita
%                  di rileggere i CSV a ogni valutazione), con in aggiunta
%                  other.opt_bounds.lb / .ub (10x1, impostati da
%                  run_real_case.m) usati SOLO per il clip qui sotto.
%   OUTPUT f      : -Mpayload [kg] (da massimizzare, sign convention min(f)
%                    di solver_project -- rif. TSTO/source/eval_fgh.m)
%          cineq  : [] (placeholder, nessuna disuguaglianza definita in TSTO,
%                    coerente col placeholder di solver_project CLAUDE.md S4)
%          ceq    : 3x1, residui perigeo/apogeo/inclinazione rispetto al
%                    target di missione (rif. TSTO/source/eval_fgh.m)
    x = x(:);
    if isfield(other, 'opt_bounds')
        x = min(max(x, other.opt_bounds.lb(:)), other.opt_bounds.ub(:));
    end

    % conversione deg -> rad sulle 4 componenti angolari (vedi header):
    % clip sopra e' fatto in gradi (stessa unita' di other.opt_bounds,
    % costruiti in gradi su questi indici da run_real_case.m), la
    % conversione va fatta DOPO il clip, appena prima di traj_problem.m
    % (che si aspetta radianti nativi TSTO su tutte le componenti).
    ang_idx = [3, 4, 6, 8];   % pitch_c1, pitch_c2, pitch_rate_transition, AoA_rate
    x(ang_idx) = deg2rad(x(ang_idx));

    % --- log START (vedi header per il perche') ---------------------------
    log_path = fullfile(fileparts(mfilename('fullpath')), 'eval_log.csv');
    t_eval = tic;
    fid = fopen(log_path, 'a');
    if fid >= 0
        fprintf(fid, 'START,%s,%s\n', datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
                sprintf('%.10g,', x));
        fclose(fid);
    end

    % 4a uscita: propellente residuo stadio 2 (diagnostica per il metodo di
    % continuazione, rif. run_continuation.m). Il solver ne chiede 3 e non la
    % vede mai: il contratto di CLAUDE.md S4 resta invariato.
    [f, cineq, ceq, prop_residual] = traj_problem(x, other);

    % --- log END ------------------------------------------------------
    fid = fopen(log_path, 'a');
    if fid >= 0
        fprintf(fid, 'END,%s,%.6g,%.3f\n', datestr(now, 'yyyy-mm-dd HH:MM:SS.FFF'), ...
                f, toc(t_eval));
        fclose(fid);
    end
end
